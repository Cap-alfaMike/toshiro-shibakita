/**
 * =============================================================================
 * Health Check Routes
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Provides health check endpoints for:
 * - ALB target group health checks
 * - ECS container health monitoring
 * - Kubernetes-style readiness/liveness probes
 * =============================================================================
 */

import { Router, Request, Response } from 'express';
import { checkDatabaseHealth } from '../database/postgres.js';
import { checkRedisHealth } from '../database/redis.js';
import { config } from '../config/index.js';

export const healthRouter = Router();

interface HealthStatus {
    status: 'healthy' | 'unhealthy' | 'degraded';
    timestamp: string;
    version: string;
    environment: string;
    uptime: number;
    checks: {
        database: boolean;
        redis: boolean;
    };
}

/**
 * GET /health
 * Basic health check for ALB (fast response required)
 */
healthRouter.get('/', (_req: Request, res: Response) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
    });
});

/**
 * GET /ready
 * Readiness probe - checks all dependencies
 */
healthRouter.get('/ready', async (_req: Request, res: Response) => {
    const checks = {
        database: await checkDatabaseHealth(),
        redis: await checkRedisHealth(),
    };

    const allHealthy = Object.values(checks).every(Boolean);
    const someHealthy = Object.values(checks).some(Boolean);

    let status: HealthStatus['status'];
    if (allHealthy) {
        status = 'healthy';
    } else if (someHealthy) {
        status = 'degraded';
    } else {
        status = 'unhealthy';
    }

    const healthStatus: HealthStatus = {
        status,
        timestamp: new Date().toISOString(),
        version: process.env['npm_package_version'] || '2.0.0',
        environment: config.env,
        uptime: process.uptime(),
        checks,
    };

    const httpStatus = status === 'unhealthy' ? 503 : 200;
    res.status(httpStatus).json(healthStatus);
});

/**
 * GET /live
 * Liveness probe - just checks the process is running
 */
healthRouter.get('/live', (_req: Request, res: Response) => {
    res.status(200).json({
        status: 'alive',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
    });
});
