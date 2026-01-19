-- =============================================================================
-- Database Initialization Script
-- Toshiro-Shibakita - Cloud-Native Evolution
-- =============================================================================
-- Original project: https://github.com/denilsonbonatti/toshiro-shibakita
-- 
-- Original schema (banco.sql):
--   CREATE TABLE dados (
--       AlunoID int,
--       Nome varchar(50),
--       Sobrenome varchar(50),
--       Endereco varchar(150),
--       Cidade varchar(50),
--       Host varchar(50)
--   );
--
-- Evolution: Added proper constraints, indexes, timestamps, and UUID primary key
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =============================================================================
-- Main Table: dados (evolved from original)
-- =============================================================================
CREATE TABLE IF NOT EXISTS dados (
    -- Primary key (UUID for distributed systems)
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Original fields (preserved for compatibility)
    aluno_id INTEGER NOT NULL,
    nome VARCHAR(50) NOT NULL,
    sobrenome VARCHAR(50) NOT NULL,
    endereco VARCHAR(150) NOT NULL,
    cidade VARCHAR(50) NOT NULL,
    host VARCHAR(50),
    
    -- Added fields for audit and tracking
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Indexes
-- =============================================================================

-- Index for city-based queries (common filter)
CREATE INDEX IF NOT EXISTS idx_dados_cidade ON dados(cidade);

-- Index for creation date (for sorting and range queries)
CREATE INDEX IF NOT EXISTS idx_dados_created_at ON dados(created_at DESC);

-- Composite index for pagination queries
CREATE INDEX IF NOT EXISTS idx_dados_cidade_created ON dados(cidade, created_at DESC);

-- =============================================================================
-- Trigger for updated_at auto-update
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_dados_updated_at ON dados;
CREATE TRIGGER update_dados_updated_at
    BEFORE UPDATE ON dados
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Sample Data (for development)
-- =============================================================================

INSERT INTO dados (aluno_id, nome, sobrenome, endereco, cidade, host)
VALUES 
    (1, 'Toshiro', 'Shibakita', 'Rua das Flores, 123', 'São Paulo', 'localhost'),
    (2, 'Denilson', 'Bonatti', 'Av. Paulista, 1000', 'São Paulo', 'localhost'),
    (3, 'Cloud', 'Architect', 'AWS Region us-east-1', 'Virginia', 'localhost')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- Health check function
-- =============================================================================

CREATE OR REPLACE FUNCTION health_check()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Business metrics view
-- =============================================================================

CREATE OR REPLACE VIEW dados_metrics AS
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT cidade) as unique_cities,
    COUNT(DISTINCT host) as unique_hosts,
    MIN(created_at) as first_record,
    MAX(created_at) as last_record,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as last_24h_records
FROM dados;

-- =============================================================================
-- Grant permissions (for application user)
-- =============================================================================

-- Note: In production, use a separate application user with limited permissions
-- GRANT SELECT, INSERT, UPDATE, DELETE ON dados TO toshiro_app;
-- GRANT SELECT ON dados_metrics TO toshiro_app;

COMMENT ON TABLE dados IS 'Main data table - evolved from original Toshiro-Shibakita project';
COMMENT ON COLUMN dados.aluno_id IS 'Student ID (preserved from original schema)';
COMMENT ON COLUMN dados.host IS 'Container hostname that created the record';
