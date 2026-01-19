/**
 * Server entry point with graceful shutdown support for ECS.
 * Based on: https://github.com/denilsonbonatti/toshiro-shibakita
 */

import { createApp } from './app.js';
import { config } from './config/index.js';
import { logger } from './utils/logger.js';
import { initializeDatabase, closeDatabase } from './database/postgres.js';
import { initializeRedis, closeRedis } from './database/redis.js';

let isShuttingDown = false;
let server: ReturnType<typeof createApp> extends { listen: (...args: unknown[]) => infer R } ? R : never;

async function shutdown(signal: string) {
    if (isShuttingDown) {
        logger.warn('Shutdown already in progress');
        return;
    }

    isShuttingDown = true;
    logger.info({ signal }, 'Graceful shutdown initiated');

    if (server) {
        await new Promise<void>((resolve) => {
            server.close(() => {
                logger.info('HTTP server closed');
                resolve();
            });
        });
    }

    await closeDatabase();
    await closeRedis();

    logger.info('Graceful shutdown complete');
    process.exit(0);
}

async function main() {
    try {
        logger.info({
            environment: config.env,
            port: config.port,
            nodeVersion: process.version,
        }, 'Starting API...');

        await initializeDatabase();
        await initializeRedis();

        const app = createApp();

        server = app.listen(config.port, () => {
            logger.info({ port: config.port, environment: config.env }, 'API is running');
        });

        // Keep-alive timeout higher than ALB's 60s
        server.keepAliveTimeout = 65000;
        server.headersTimeout = 66000;

        server.on('error', (error: NodeJS.ErrnoException) => {
            if (error.code === 'EADDRINUSE') {
                logger.fatal({ port: config.port }, 'Port is already in use');
                process.exit(1);
            }
            throw error;
        });

    } catch (error) {
        logger.fatal({ error }, 'Failed to start server');
        process.exit(1);
    }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
    logger.error({ reason, promise }, 'Unhandled promise rejection');
});

process.on('uncaughtException', (error) => {
    logger.fatal({ error }, 'Uncaught exception');
    process.exit(1);
});

main();
