/**
 * =============================================================================
 * Application Configuration
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Original project: https://github.com/denilsonbonatti/toshiro-shibakita
 * 
 * Configuration follows 12-Factor App methodology:
 * - All config from environment variables
 * - No hardcoded secrets (retrieved from AWS Secrets Manager)
 * - Sensible defaults for development
 * =============================================================================
 */

import { z } from 'zod';

// Environment validation schema
const envSchema = z.object({
    NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
    PORT: z.string().transform(Number).default('3000'),
    LOG_LEVEL: z.enum(['trace', 'debug', 'info', 'warn', 'error', 'fatal']).default('info'),

    // AWS Configuration
    AWS_REGION: z.string().default('us-east-1'),
    AWS_SECRET_NAME: z.string().optional(),

    // Database (from Secrets Manager in production)
    DB_HOST: z.string().optional(),
    DB_PORT: z.string().transform(Number).default('5432'),
    DB_NAME: z.string().default('toshiro'),
    DB_USER: z.string().optional(),
    DB_PASSWORD: z.string().optional(),
    DB_SSL: z.string().transform(v => v === 'true').default('true'),
    DB_POOL_MIN: z.string().transform(Number).default('2'),
    DB_POOL_MAX: z.string().transform(Number).default('10'),

    // Redis (ElastiCache)
    REDIS_HOST: z.string().optional(),
    REDIS_PORT: z.string().transform(Number).default('6379'),
    REDIS_TLS: z.string().transform(v => v === 'true').default('true'),

    // Feature flags
    ENABLE_XRAY: z.string().transform(v => v === 'true').default('false'),
    ENABLE_CACHE: z.string().transform(v => v === 'true').default('true'),
});

// Parse and validate environment
const parseEnv = () => {
    try {
        return envSchema.parse(process.env);
    } catch (error) {
        if (error instanceof z.ZodError) {
            console.error('❌ Invalid environment configuration:');
            error.errors.forEach(err => {
                console.error(`   - ${err.path.join('.')}: ${err.message}`);
            });
            process.exit(1);
        }
        throw error;
    }
};

export const env = parseEnv();

// Structured configuration object
export const config = {
    env: env.NODE_ENV,
    port: env.PORT,
    logLevel: env.LOG_LEVEL,

    aws: {
        region: env.AWS_REGION,
        secretName: env.AWS_SECRET_NAME,
    },

    database: {
        host: env.DB_HOST,
        port: env.DB_PORT,
        name: env.DB_NAME,
        user: env.DB_USER,
        password: env.DB_PASSWORD,
        ssl: env.DB_SSL,
        pool: {
            min: env.DB_POOL_MIN,
            max: env.DB_POOL_MAX,
        },
    },

    redis: {
        host: env.REDIS_HOST,
        port: env.REDIS_PORT,
        tls: env.REDIS_TLS,
    },

    features: {
        xray: env.ENABLE_XRAY,
        cache: env.ENABLE_CACHE,
    },

    isProduction: env.NODE_ENV === 'production',
    isDevelopment: env.NODE_ENV === 'development',
} as const;

export type Config = typeof config;
