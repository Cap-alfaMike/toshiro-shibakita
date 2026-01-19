/**
 * =============================================================================
 * Data Routes - Migrated from Original PHP Application
 * Toshiro-Shibakita API - Cloud-Native Evolution
 * =============================================================================
 * Original: index.php with INSERT INTO dados
 * Evolution: RESTful API with validation, caching, and observability
 * =============================================================================
 */

import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { query, transaction } from '../database/postgres.js';
import { cacheGet, cacheSet, cacheDelete } from '../database/redis.js';
import { logger } from '../utils/logger.js';

export const dataRouter = Router();

// Request validation schemas
const createDataSchema = z.object({
    nome: z.string().min(1).max(50),
    sobrenome: z.string().min(1).max(50),
    endereco: z.string().min(1).max(150),
    cidade: z.string().min(1).max(50),
});

const updateDataSchema = createDataSchema.partial();

const querySchema = z.object({
    page: z.string().transform(Number).default('1'),
    limit: z.string().transform(Number).default('20'),
    cidade: z.string().optional(),
});

// Data model interface
interface DadosRecord {
    id: string;
    aluno_id: number;
    nome: string;
    sobrenome: string;
    endereco: string;
    cidade: string;
    host: string;
    created_at: Date;
    updated_at: Date;
}

/**
 * GET /api/v1/dados
 * List all records with pagination
 */
dataRouter.get('/', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { page, limit, cidade } = querySchema.parse(req.query);
        const offset = (page - 1) * limit;

        // Try cache first
        const cacheKey = `dados:list:${page}:${limit}:${cidade || 'all'}`;
        const cached = await cacheGet<{ data: DadosRecord[]; total: number }>(cacheKey);

        if (cached) {
            logger.debug({ cacheKey }, 'Cache hit for data list');
            return res.json({
                success: true,
                data: cached.data,
                pagination: {
                    page,
                    limit,
                    total: cached.total,
                    totalPages: Math.ceil(cached.total / limit),
                },
            });
        }

        // Build query
        let queryText = 'SELECT * FROM dados';
        const queryParams: unknown[] = [];

        if (cidade) {
            queryText += ' WHERE cidade = $1';
            queryParams.push(cidade);
        }

        queryText += ` ORDER BY created_at DESC LIMIT $${queryParams.length + 1} OFFSET $${queryParams.length + 2}`;
        queryParams.push(limit, offset);

        const result = await query<DadosRecord>(queryText, queryParams);

        // Get total count
        const countQuery = cidade
            ? 'SELECT COUNT(*) FROM dados WHERE cidade = $1'
            : 'SELECT COUNT(*) FROM dados';
        const countParams = cidade ? [cidade] : [];
        const countResult = await query<{ count: string }>(countQuery, countParams);
        const total = parseInt(countResult.rows[0]?.count || '0', 10);

        // Cache result
        await cacheSet(cacheKey, { data: result.rows, total }, 60);

        res.json({
            success: true,
            data: result.rows,
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/v1/dados/:id
 * Get single record by ID
 */
dataRouter.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { id } = req.params;

        // Try cache
        const cacheKey = `dados:${id}`;
        const cached = await cacheGet<DadosRecord>(cacheKey);

        if (cached) {
            return res.json({ success: true, data: cached });
        }

        const result = await query<DadosRecord>(
            'SELECT * FROM dados WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Record not found',
            });
        }

        // Cache result
        await cacheSet(cacheKey, result.rows[0], 300);

        res.json({ success: true, data: result.rows[0] });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/v1/dados
 * Create new record (migrated from original PHP INSERT)
 */
dataRouter.post('/', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const data = createDataSchema.parse(req.body);

        const id = uuidv4();
        const alunoId = Math.floor(Math.random() * 999) + 1;
        const hostname = process.env['HOSTNAME'] || 'unknown';

        const result = await query<DadosRecord>(
            `INSERT INTO dados (id, aluno_id, nome, sobrenome, endereco, cidade, host, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
       RETURNING *`,
            [id, alunoId, data.nome, data.sobrenome, data.endereco, data.cidade, hostname]
        );

        // Invalidate list cache
        await cacheDelete('dados:list:*');

        logger.info({
            id,
            alunoId,
            cidade: data.cidade,
            host: hostname,
        }, 'New record created');

        res.status(201).json({
            success: true,
            data: result.rows[0],
            message: 'Record created successfully',
        });
    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                details: error.errors,
            });
        }
        next(error);
    }
});

/**
 * PUT /api/v1/dados/:id
 * Update record
 */
dataRouter.put('/:id', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { id } = req.params;
        const data = updateDataSchema.parse(req.body);

        // Build dynamic update query
        const updates: string[] = [];
        const values: unknown[] = [];
        let paramIndex = 1;

        if (data.nome) {
            updates.push(`nome = $${paramIndex++}`);
            values.push(data.nome);
        }
        if (data.sobrenome) {
            updates.push(`sobrenome = $${paramIndex++}`);
            values.push(data.sobrenome);
        }
        if (data.endereco) {
            updates.push(`endereco = $${paramIndex++}`);
            values.push(data.endereco);
        }
        if (data.cidade) {
            updates.push(`cidade = $${paramIndex++}`);
            values.push(data.cidade);
        }

        if (updates.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'No fields to update',
            });
        }

        updates.push(`updated_at = NOW()`);
        values.push(id);

        const result = await query<DadosRecord>(
            `UPDATE dados SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
            values
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Record not found',
            });
        }

        // Invalidate cache
        await cacheDelete(`dados:${id}`);

        res.json({
            success: true,
            data: result.rows[0],
            message: 'Record updated successfully',
        });
    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                details: error.errors,
            });
        }
        next(error);
    }
});

/**
 * DELETE /api/v1/dados/:id
 * Delete record
 */
dataRouter.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { id } = req.params;

        const result = await query(
            'DELETE FROM dados WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                success: false,
                error: 'Record not found',
            });
        }

        // Invalidate cache
        await cacheDelete(`dados:${id}`);

        logger.info({ id }, 'Record deleted');

        res.json({
            success: true,
            message: 'Record deleted successfully',
        });
    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/v1/dados/stats/summary
 * Business metrics endpoint
 */
dataRouter.get('/stats/summary', async (_req: Request, res: Response, next: NextFunction) => {
    try {
        const cacheKey = 'dados:stats';
        const cached = await cacheGet(cacheKey);

        if (cached) {
            return res.json({ success: true, data: cached });
        }

        const stats = await transaction(async (client) => {
            const totalResult = await client.query('SELECT COUNT(*) as total FROM dados');
            const byCity = await client.query(
                'SELECT cidade, COUNT(*) as count FROM dados GROUP BY cidade ORDER BY count DESC LIMIT 10'
            );
            const recent = await client.query(
                'SELECT COUNT(*) as count FROM dados WHERE created_at > NOW() - INTERVAL \'24 hours\''
            );

            return {
                total: parseInt(totalResult.rows[0]?.total || '0', 10),
                byCity: byCity.rows,
                last24Hours: parseInt(recent.rows[0]?.count || '0', 10),
                timestamp: new Date().toISOString(),
            };
        });

        await cacheSet(cacheKey, stats, 60);

        res.json({ success: true, data: stats });
    } catch (error) {
        next(error);
    }
});
