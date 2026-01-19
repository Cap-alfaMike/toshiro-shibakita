/**
 * =============================================================================
 * AWS Secrets Manager Service
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Securely retrieves secrets from AWS Secrets Manager at runtime.
 * This replaces the hardcoded credentials from the original project.
 * 
 * Security improvements:
 * - No secrets in code or environment files
 * - Secrets retrieved at runtime via IAM Task Role
 * - Automatic secret rotation support
 * - In-memory caching with TTL
 * =============================================================================
 */

import {
    SecretsManagerClient,
    GetSecretValueCommand
} from '@aws-sdk/client-secrets-manager';
import { config } from '../config/index.js';
import { logger } from '../utils/logger.js';

interface DatabaseSecrets {
    host: string;
    port: number;
    username: string;
    password: string;
    database: string;
}

interface RedisSecrets {
    host: string;
    port: number;
    authToken?: string;
}

interface AppSecrets {
    database: DatabaseSecrets;
    redis: RedisSecrets;
}

// Secrets cache with TTL (5 minutes)
const CACHE_TTL_MS = 5 * 60 * 1000;
let cachedSecrets: AppSecrets | null = null;
let cacheTimestamp: number = 0;

// Create Secrets Manager client
const secretsClient = new SecretsManagerClient({
    region: config.aws.region,
});

/**
 * Retrieves secrets from AWS Secrets Manager
 * Uses IAM Task Role for authentication (no credentials needed)
 */
async function fetchSecretsFromAWS(): Promise<AppSecrets> {
    const secretName = config.aws.secretName;

    if (!secretName) {
        throw new Error('AWS_SECRET_NAME environment variable is required in production');
    }

    logger.info({ secretName }, 'Fetching secrets from AWS Secrets Manager');

    try {
        const command = new GetSecretValueCommand({
            SecretId: secretName,
        });

        const response = await secretsClient.send(command);

        if (!response.SecretString) {
            throw new Error('Secret value is empty');
        }

        const secrets = JSON.parse(response.SecretString) as AppSecrets;

        logger.info('Successfully retrieved secrets from AWS Secrets Manager');

        return secrets;
    } catch (error) {
        logger.error({ error, secretName }, 'Failed to retrieve secrets from AWS Secrets Manager');
        throw error;
    }
}

/**
 * Get development secrets (for local development only)
 */
function getDevelopmentSecrets(): AppSecrets {
    logger.warn('Using development secrets - NOT FOR PRODUCTION');

    return {
        database: {
            host: config.database.host || 'localhost',
            port: config.database.port,
            username: config.database.user || 'postgres',
            password: config.database.password || 'devpassword',
            database: config.database.name,
        },
        redis: {
            host: config.redis.host || 'localhost',
            port: config.redis.port,
        },
    };
}

/**
 * Get application secrets with caching
 * In production: retrieves from AWS Secrets Manager
 * In development: uses environment variables
 */
export async function getSecrets(): Promise<AppSecrets> {
    // Check cache
    const now = Date.now();
    if (cachedSecrets && (now - cacheTimestamp) < CACHE_TTL_MS) {
        logger.debug('Returning cached secrets');
        return cachedSecrets;
    }

    // In development, use local config
    if (config.isDevelopment) {
        cachedSecrets = getDevelopmentSecrets();
        cacheTimestamp = now;
        return cachedSecrets;
    }

    // In production, fetch from AWS Secrets Manager
    cachedSecrets = await fetchSecretsFromAWS();
    cacheTimestamp = now;

    return cachedSecrets;
}

/**
 * Clear secrets cache (useful for secret rotation)
 */
export function clearSecretsCache(): void {
    cachedSecrets = null;
    cacheTimestamp = 0;
    logger.info('Secrets cache cleared');
}
