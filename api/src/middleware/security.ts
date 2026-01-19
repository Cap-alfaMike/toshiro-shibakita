/**
 * =============================================================================
 * Security Middleware
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Defense-in-depth security layers:
 * - Helmet for HTTP security headers
 * - Rate limiting
 * - Request validation
 * - Error sanitization
 * =============================================================================
 */

import { Request, Response, NextFunction, ErrorRequestHandler } from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cors from 'cors';
import compression from 'compression';
import { logger } from '../utils/logger.js';
import { config } from '../config/index.js';

/**
 * Helmet security headers configuration
 */
export const securityHeaders = helmet({
    // Content Security Policy
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", 'data:', 'https:'],
            connectSrc: ["'self'"],
            fontSrc: ["'self'"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'none'"],
        },
    },
    // Strict Transport Security
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true,
    },
    // Prevent clickjacking
    frameguard: { action: 'deny' },
    // Prevent MIME type sniffing
    noSniff: true,
    // Hide X-Powered-By header
    hidePoweredBy: true,
});

/**
 * Rate limiting configuration
 */
export const rateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: config.isProduction ? 100 : 1000, // Requests per window
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        success: false,
        error: 'Too many requests, please try again later',
    },
    skip: (req) => {
        // Skip rate limiting for health checks
        return req.path === '/health' || req.path === '/ready' || req.path === '/live';
    },
    keyGenerator: (req) => {
        // Use X-Forwarded-For from ALB
        return req.headers['x-forwarded-for']?.toString().split(',')[0] ||
            req.ip ||
            'unknown';
    },
});

/**
 * CORS configuration
 */
export const corsMiddleware = cors({
    origin: config.isProduction
        ? (origin, callback) => {
            // In production, validate against allowed origins
            const allowedOrigins = process.env['ALLOWED_ORIGINS']?.split(',') || [];
            if (!origin || allowedOrigins.includes(origin)) {
                callback(null, true);
            } else {
                callback(new Error('Not allowed by CORS'));
            }
        }
        : true, // Allow all in development
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
    maxAge: 86400, // 24 hours preflight cache
});

/**
 * Compression middleware
 */
export const compressionMiddleware = compression({
    filter: (req, res) => {
        if (req.headers['x-no-compression']) {
            return false;
        }
        return compression.filter(req, res);
    },
    level: 6, // Balanced compression
});

/**
 * Request ID middleware (for tracing)
 */
export function requestIdMiddleware(req: Request, res: Response, next: NextFunction) {
    const requestId = req.headers['x-request-id']?.toString() ||
        req.headers['x-amzn-trace-id']?.toString() ||
        crypto.randomUUID();

    req.headers['x-request-id'] = requestId;
    res.setHeader('X-Request-ID', requestId);

    next();
}

/**
 * Global error handler
 */
export const errorHandler: ErrorRequestHandler = (
    err: Error & { status?: number; statusCode?: number },
    req: Request,
    res: Response,
    _next: NextFunction
) => {
    const statusCode = err.status || err.statusCode || 500;

    logger.error({
        err,
        requestId: req.headers['x-request-id'],
        path: req.path,
        method: req.method,
    }, 'Request error');

    // Don't leak internal errors in production
    const message = config.isProduction && statusCode === 500
        ? 'Internal server error'
        : err.message;

    res.status(statusCode).json({
        success: false,
        error: message,
        ...(config.isDevelopment && { stack: err.stack }),
        requestId: req.headers['x-request-id'],
    });
};

/**
 * 404 handler
 */
export function notFoundHandler(req: Request, res: Response) {
    res.status(404).json({
        success: false,
        error: 'Resource not found',
        path: req.path,
        requestId: req.headers['x-request-id'],
    });
}
