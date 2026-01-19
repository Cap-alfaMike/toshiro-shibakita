/**
 * =============================================================================
 * Server Entry Point
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Original project: https://github.com/denilsonbonatti/toshiro-shibakita
 * 
 * Handles:
 * - Graceful startup with dependency initialization
 * - Graceful shutdown for ECS task termination
 * - Signal handling (SIGTERM, SIGINT)
 * =============================================================================
 */

import { createApp } from './app.js';
import { config } from './config/index.js';
import { logger } from './utils/logger.js';
import { initializeDatabase, closeDatabase } from './database/postgres.js';
import { initializeRedis, closeRedis } from './database/redis.js';

// Track server state
let isShuttingDown = false;
let server: ReturnType<typeof createApp> extends { listen: (...args: unknown[]) => infer R } ? R : never;

/**
 * Graceful shutdown handler
 */
async function shutdown(signal: string) {
    if (isShuttingDown) {
        logger.warn('Shutdown already in progress');
        return;
    }

    isShuttingDown = true;
    logger.info({ signal }, 'Graceful shutdown initiated');

    // Stop accepting new connections
    if (server) {
        await new Promise<void>((resolve) => {
            server.close(() => {
                logger.info('HTTP server closed');
                resolve();
            });
        });
    }

    // Close database connections
    await closeDatabase();
    await closeRedis();

    logger.info('Graceful shutdown complete');
    process.exit(0);
}

/**
 * Main startup function
 */
async function main() {
    try {
        logger.info({
            environment: config.env,
            port: config.port,
            nodeVersion: process.version,
        }, 'Starting Toshiro-Shibakita API...');

        // Initialize dependencies
        logger.info('Initializing database connection...');
        await initializeDatabase();

        logger.info('Initializing Redis connection...');
        await initializeRedis();

        // Create and start Express app
        const app = createApp();

        server = app.listen(config.port, () => {
            logger.info({
                port: config.port,
                environment: config.env,
                pid: process.pid,
            }, '🚀 Toshiro-Shibakita API is running');
        });

        // Configure keep-alive for ALB
        server.keepAliveTimeout = 65000; // Higher than ALB's 60s
        server.headersTimeout = 66000;

        // Handle connection errors
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

// Signal handlers for graceful shutdown
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Unhandled rejection handler
process.on('unhandledRejection', (reason, promise) => {
    logger.error({ reason, promise }, 'Unhandled promise rejection');
});

// Uncaught exception handler
process.on('uncaughtException', (error) => {
    logger.fatal({ error }, 'Uncaught exception');
    process.exit(1);
});

// Start the server
main();
