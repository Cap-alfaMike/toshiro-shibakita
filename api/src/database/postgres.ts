/**
 * =============================================================================
 * PostgreSQL Connection Pool
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Manages PostgreSQL connections with:
 * - Connection pooling for performance
 * - TLS/SSL for RDS connections
 * - Health check support
 * - Graceful shutdown handling
 * =============================================================================
 */

import { Pool, PoolConfig, PoolClient, QueryResult } from 'pg';
import { getSecrets } from '../services/secrets.service.js';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

let pool: Pool | null = null;

/**
 * Initialize database connection pool
 */
export async function initializeDatabase(): Promise<void> {
    if (pool) {
        logger.warn('Database pool already initialized');
        return;
    }

    const secrets = await getSecrets();
    const dbConfig = secrets.database;

    const poolConfig: PoolConfig = {
        host: dbConfig.host,
        port: dbConfig.port,
        database: dbConfig.database,
        user: dbConfig.username,
        password: dbConfig.password,

        // Connection pool settings
        min: config.database.pool.min,
        max: config.database.pool.max,

        // Connection timeout
        connectionTimeoutMillis: 10000,
        idleTimeoutMillis: 30000,

        // SSL configuration for RDS
        ssl: config.database.ssl ? {
            rejectUnauthorized: true,
            // RDS uses Amazon Root CA
        } : undefined,
    };

    pool = new Pool(poolConfig);

    // Pool event handlers
    pool.on('connect', (client) => {
        logger.debug('New database client connected');

        // Set statement timeout for queries
        client.query('SET statement_timeout = 30000');
    });

    pool.on('error', (err) => {
        logger.error({ err }, 'Unexpected database pool error');
    });

    pool.on('remove', () => {
        logger.debug('Database client removed from pool');
    });

    // Test connection
    try {
        const client = await pool.connect();
        await client.query('SELECT 1');
        client.release();
        logger.info({
            host: dbConfig.host,
            database: dbConfig.database,
            maxConnections: config.database.pool.max,
        }, 'Database connection pool initialized');
    } catch (error) {
        logger.error({ error }, 'Failed to connect to database');
        throw error;
    }
}

/**
 * Get the database pool
 */
export function getPool(): Pool {
    if (!pool) {
        throw new Error('Database pool not initialized. Call initializeDatabase() first.');
    }
    return pool;
}

/**
 * Execute a query with automatic connection handling
 */
export async function query<T = unknown>(
    text: string,
    params?: unknown[]
): Promise<QueryResult<T>> {
    const pool = getPool();
    const start = Date.now();

    try {
        const result = await pool.query<T>(text, params);
        const duration = Date.now() - start;

        logger.debug({
            query: text.substring(0, 100),
            duration,
            rowCount: result.rowCount,
        }, 'Database query executed');

        return result;
    } catch (error) {
        logger.error({ error, query: text.substring(0, 100) }, 'Database query failed');
        throw error;
    }
}

/**
 * Execute a transaction
 */
export async function transaction<T>(
    callback: (client: PoolClient) => Promise<T>
): Promise<T> {
    const pool = getPool();
    const client = await pool.connect();

    try {
        await client.query('BEGIN');
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

/**
 * Check database health
 */
export async function checkDatabaseHealth(): Promise<boolean> {
    try {
        const pool = getPool();
        const result = await pool.query('SELECT 1');
        return result.rowCount === 1;
    } catch {
        return false;
    }
}

/**
 * Close database pool gracefully
 */
export async function closeDatabase(): Promise<void> {
    if (pool) {
        logger.info('Closing database connection pool...');
        await pool.end();
        pool = null;
        logger.info('Database connection pool closed');
    }
}
