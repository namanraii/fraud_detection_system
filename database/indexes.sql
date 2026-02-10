-- ============================================================================
-- Performance Optimization Indexes
-- Additional indexes for query optimization
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- COMPOSITE INDEXES for common query patterns
-- ============================================================================

-- Customer analytics queries
CREATE INDEX idx_customer_stats ON TRANSACTION(customer_id, amount, time);

-- Fraud analysis queries
CREATE INDEX idx_fraud_analysis ON FRAUD_LABEL(is_fraud, labeled_at);

-- Prediction analytics
CREATE INDEX idx_prediction_analytics ON ML_PREDICTION(model_id, predicted_class, probability_score);

-- Time-based analysis
CREATE INDEX idx_time_fraud ON TRANSACTION(time) 
    COMMENT 'For temporal fraud pattern analysis';

-- Amount range queries
CREATE INDEX idx_amount_range ON TRANSACTION(amount) 
    COMMENT 'For high-value transaction detection';

-- ============================================================================
-- COVERING INDEXES for frequently accessed columns
-- ============================================================================

-- Dashboard queries (avoid table lookups)
CREATE INDEX idx_transaction_summary ON TRANSACTION(customer_id, time, amount);

-- Model performance queries
CREATE INDEX idx_model_performance ON ML_PREDICTION(model_id, predicted_class, probability_score, predicted_at);

-- ============================================================================
-- FULL-TEXT INDEXES (if needed for notes/comments)
-- ============================================================================

-- For searching model notes
ALTER TABLE MODEL_METADATA ADD FULLTEXT INDEX ft_notes (notes);

-- ============================================================================
-- Show all indexes
-- ============================================================================

SELECT 
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS COLUMNS,
    INDEX_TYPE
FROM 
    information_schema.STATISTICS
WHERE 
    TABLE_SCHEMA = 'fraud_db'
GROUP BY 
    TABLE_NAME, INDEX_NAME, INDEX_TYPE
ORDER BY 
    TABLE_NAME, INDEX_NAME;
