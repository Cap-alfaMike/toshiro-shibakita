/**
 * =============================================================================
 * Express Application Setup
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Application factory with all middleware and routes configured
 * =============================================================================
 */

import express, { Express } from 'express';
import pinoHttp from 'pino-http';
import {
    securityHeaders,
    rateLimiter,
    corsMiddleware,
    compressionMiddleware,
    requestIdMiddleware,
    errorHandler,
    notFoundHandler,
} from './middleware/security.js';
import { httpLoggerConfig } from './utils/logger.js';
import { healthRouter } from './routes/health.routes.js';
import { dataRouter } from './routes/data.routes.js';

export function createApp(): Express {
    const app = express();

    // Trust proxy (for ALB)
    app.set('trust proxy', true);

    // Request ID (first, before logging)
    app.use(requestIdMiddleware);

    // HTTP request logging
    app.use(pinoHttp(httpLoggerConfig));

    // Security middleware
    app.use(securityHeaders);
    app.use(corsMiddleware);
    app.use(rateLimiter);
    app.use(compressionMiddleware);

    // Body parsing
    app.use(express.json({ limit: '1mb' }));
    app.use(express.urlencoded({ extended: true, limit: '1mb' }));

    // Health routes (no prefix, for ALB)
    app.use(healthRouter);

    // API routes
    app.use('/api/v1/dados', dataRouter);

    // API info endpoint
    app.get('/api/v1', (_req, res) => {
        res.json({
            name: 'Toshiro-Shibakita API',
            version: '2.0.0',
            description: 'Cloud-Native Evolution',
            documentation: '/api/v1/docs',
            health: '/health',
            endpoints: {
                dados: '/api/v1/dados',
            },
        });
    });

    // Error handlers
    app.use(notFoundHandler);
    app.use(errorHandler);

    return app;
}
