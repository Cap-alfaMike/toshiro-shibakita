/**
 * =============================================================================
 * Structured Logger with AWS CloudWatch Integration
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Uses Pino for high-performance JSON logging, optimized for CloudWatch Logs.
 * 
 * Log format is designed for:
 * - CloudWatch Logs Insights queries
 * - AWS X-Ray correlation
 * - Structured search and analysis
 * =============================================================================
 */

import pino from 'pino';
import { config } from '../config/index.js';

// Create base logger configuration
const baseConfig: pino.LoggerOptions = {
    level: config.logLevel,

    // Add base context to all logs
    base: {
        service: 'toshiro-api',
        version: process.env['npm_package_version'] || '2.0.0',
        environment: config.env,
    },

    // Timestamp format for CloudWatch
    timestamp: pino.stdTimeFunctions.isoTime,

    // Format errors properly
    formatters: {
        level: (label) => ({ level: label }),
        bindings: (bindings) => ({
            pid: bindings.pid,
            hostname: bindings.hostname,
        }),
    },
};

// In development, use pretty printing
const developmentConfig: pino.LoggerOptions = {
    ...baseConfig,
    transport: {
        target: 'pino-pretty',
        options: {
            colorize: true,
            translateTime: 'SYS:standard',
            ignore: 'pid,hostname',
        },
    },
};

// In production, use JSON format for CloudWatch
const productionConfig: pino.LoggerOptions = {
    ...baseConfig,
    // No transport = JSON to stdout (optimal for CloudWatch)
};

// Create logger instance
export const logger = pino(
    config.isDevelopment ? developmentConfig : productionConfig
);

// Create child logger factory for adding context
export function createChildLogger(context: Record<string, unknown>) {
    return logger.child(context);
}

// HTTP request logger configuration for pino-http
export const httpLoggerConfig = {
    logger,

    // Custom log level based on status code
    customLogLevel: (req: unknown, res: { statusCode: number }, err?: Error) => {
        if (res.statusCode >= 500 || err) return 'error';
        if (res.statusCode >= 400) return 'warn';
        return 'info';
    },

    // Add request ID to all logs
    genReqId: (req: { headers: Record<string, string | string[] | undefined> }) => {
        return req.headers['x-request-id'] ||
            req.headers['x-amzn-trace-id'] ||
            crypto.randomUUID();
    },

    // Customize serializers to avoid sensitive data
    serializers: {
        req: (req: { method: string; url: string; headers: Record<string, unknown> }) => ({
            method: req.method,
            url: req.url,
            // Omit sensitive headers
            headers: {
                'user-agent': req.headers['user-agent'],
                'x-forwarded-for': req.headers['x-forwarded-for'],
                'x-request-id': req.headers['x-request-id'],
            },
        }),
        res: (res: { statusCode: number }) => ({
            statusCode: res.statusCode,
        }),
    },

    // Skip health check logging to reduce noise
    autoLogging: {
        ignore: (req: { url?: string }) => {
            return req.url === '/health' || req.url === '/ready';
        },
    },
};
