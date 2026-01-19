/**
 * =============================================================================
 * Redis Client (ElastiCache)
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Manages Redis connections for:
 * - Session caching
 * - Query result caching
 * - Rate limiting
 * 
 * Configured for AWS ElastiCache with TLS
 * =============================================================================
 */

import Redis from 'ioredis';
import { getSecrets } from '../services/secrets.service.js';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

let redisClient: Redis | null = null;

/**
 * Initialize Redis client
 */
export async function initializeRedis(): Promise<void> {
    if (!config.features.cache) {
        logger.info('Redis caching is disabled');
        return;
    }

    if (redisClient) {
        logger.warn('Redis client already initialized');
        return;
    }

    const secrets = await getSecrets();
    const redisConfig = secrets.redis;

    const options: Redis.RedisOptions = {
        host: redisConfig.host,
        port: redisConfig.port,
        password: redisConfig.authToken,

        // ElastiCache TLS configuration
        tls: config.redis.tls ? {} : undefined,

        // Connection settings
        connectTimeout: 10000,
        maxRetriesPerRequest: 3,
        retryDelayOnFailover: 100,

        // Enable offline queue
        enableOfflineQueue: true,

        // Key prefix for namespacing
        keyPrefix: 'toshiro:',
    };

    redisClient = new Redis(options);

    redisClient.on('connect', () => {
        logger.info({
            host: redisConfig.host,
            port: redisConfig.port,
        }, 'Redis client connected');
    });

    redisClient.on('error', (err) => {
        logger.error({ err }, 'Redis client error');
    });

    redisClient.on('close', () => {
        logger.info('Redis connection closed');
    });

    // Test connection
    try {
        await redisClient.ping();
        logger.info('Redis connection verified');
    } catch (error) {
        logger.error({ error }, 'Failed to connect to Redis');
        throw error;
    }
}

/**
 * Get Redis client
 */
export function getRedisClient(): Redis | null {
    return redisClient;
}

/**
 * Cache wrapper with automatic serialization
 */
export async function cacheGet<T>(key: string): Promise<T | null> {
    if (!redisClient) return null;

    try {
        const value = await redisClient.get(key);
        if (value) {
            return JSON.parse(value) as T;
        }
        return null;
    } catch (error) {
        logger.warn({ error, key }, 'Cache get failed');
        return null;
    }
}

/**
 * Cache set with TTL
 */
export async function cacheSet(
    key: string,
    value: unknown,
    ttlSeconds: number = 300
): Promise<void> {
    if (!redisClient) return;

    try {
        await redisClient.setex(key, ttlSeconds, JSON.stringify(value));
    } catch (error) {
        logger.warn({ error, key }, 'Cache set failed');
    }
}

/**
 * Delete cache key
 */
export async function cacheDelete(key: string): Promise<void> {
    if (!redisClient) return;

    try {
        await redisClient.del(key);
    } catch (error) {
        logger.warn({ error, key }, 'Cache delete failed');
    }
}

/**
 * Check Redis health
 */
export async function checkRedisHealth(): Promise<boolean> {
    if (!redisClient) return true; // Not enabled, consider healthy

    try {
        const result = await redisClient.ping();
        return result === 'PONG';
    } catch {
        return false;
    }
}

/**
 * Close Redis connection
 */
export async function closeRedis(): Promise<void> {
    if (redisClient) {
        logger.info('Closing Redis connection...');
        await redisClient.quit();
        redisClient = null;
        logger.info('Redis connection closed');
    }
}
