-- ============================================================================
-- SQL-Based Feature Engineering Views
-- Purpose: Create analytical views for ML feature extraction
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- VIEW 1: Customer Transaction Statistics
-- Purpose: Aggregate customer behavior metrics
-- ============================================================================

CREATE OR REPLACE VIEW customer_transaction_stats AS
SELECT 
    c.customer_id,
    COUNT(t.transaction_id) AS transaction_count,
    AVG(t.amount) AS avg_transaction_amount,
    MIN(t.amount) AS min_transaction_amount,
    MAX(t.amount) AS max_transaction_amount,
    STDDEV(t.amount) AS stddev_transaction_amount,
    SUM(t.amount) AS total_transaction_amount,
    COUNT(CASE WHEN fl.is_fraud = 1 THEN 1 END) AS fraud_count,
    COUNT(CASE WHEN fl.is_fraud = 0 THEN 1 END) AS legitimate_count,
    CASE 
        WHEN COUNT(t.transaction_id) > 0 
        THEN COUNT(CASE WHEN fl.is_fraud = 1 THEN 1 END) / COUNT(t.transaction_id)
        ELSE 0 
    END AS fraud_ratio,
    c.risk_score,
    c.last_transaction_time
FROM 
    CUSTOMER c
    LEFT JOIN TRANSACTION t ON c.customer_id = t.customer_id
    LEFT JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
GROUP BY 
    c.customer_id, c.risk_score, c.last_transaction_time;

-- ============================================================================
-- VIEW 2: High-Risk Transactions
-- Purpose: Identify transactions exceeding statistical thresholds
-- ============================================================================

CREATE OR REPLACE VIEW high_risk_transactions AS
SELECT 
    t.transaction_id,
    t.customer_id,
    t.time,
    t.amount,
    fl.is_fraud,
    CASE 
        WHEN t.amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM TRANSACTION) 
        THEN 'High Amount'
        ELSE 'Normal Amount'
    END AS amount_risk_flag,
    cts.fraud_ratio AS customer_fraud_ratio,
    cts.avg_transaction_amount AS customer_avg_amount,
    CASE 
        WHEN t.amount > cts.avg_transaction_amount * 3 
        THEN 'Unusual for Customer'
        ELSE 'Normal for Customer'
    END AS customer_pattern_flag
FROM 
    TRANSACTION t
    JOIN customer_transaction_stats cts ON t.customer_id = cts.customer_id
    LEFT JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
WHERE 
    t.amount > (SELECT AVG(amount) + STDDEV(amount) FROM TRANSACTION)
    OR cts.fraud_ratio > 0.1;

-- ============================================================================
-- VIEW 3: Fraud Patterns Analysis
-- Purpose: Temporal and amount-based fraud patterns
-- ============================================================================

CREATE OR REPLACE VIEW fraud_patterns AS
SELECT 
    FLOOR(t.time / 3600) AS hour_bucket,
    FLOOR(t.amount / 100) * 100 AS amount_bucket,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_transactions,
    AVG(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_rate,
    AVG(t.amount) AS avg_amount,
    MAX(t.amount) AS max_amount
FROM 
    TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
GROUP BY 
    hour_bucket, amount_bucket
HAVING 
    COUNT(*) >= 10
ORDER BY 
    fraud_rate DESC;

-- ============================================================================
-- VIEW 4: Model Performance Summary
-- Purpose: Aggregate prediction accuracy metrics
-- ============================================================================

CREATE OR REPLACE VIEW model_performance_summary AS
SELECT 
    mm.model_id,
    mm.model_name,
    mm.version,
    mm.trained_at,
    COUNT(mp.prediction_id) AS total_predictions,
    SUM(CASE WHEN mp.predicted_class = fl.is_fraud THEN 1 ELSE 0 END) AS correct_predictions,
    SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 1 THEN 1 ELSE 0 END) AS true_positives,
    SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 0 THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN mp.predicted_class = 0 AND fl.is_fraud = 1 THEN 1 ELSE 0 END) AS false_negatives,
    SUM(CASE WHEN mp.predicted_class = 0 AND fl.is_fraud = 0 THEN 1 ELSE 0 END) AS true_negatives,
    CASE 
        WHEN COUNT(mp.prediction_id) > 0 
        THEN SUM(CASE WHEN mp.predicted_class = fl.is_fraud THEN 1 ELSE 0 END) / COUNT(mp.prediction_id)
        ELSE 0 
    END AS accuracy,
    CASE 
        WHEN SUM(CASE WHEN mp.predicted_class = 1 THEN 1 ELSE 0 END) > 0
        THEN SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 1 THEN 1 ELSE 0 END) / 
             SUM(CASE WHEN mp.predicted_class = 1 THEN 1 ELSE 0 END)
        ELSE 0
    END AS 'precision',
    CASE 
        WHEN SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) > 0
        THEN SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 1 THEN 1 ELSE 0 END) / 
             SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END)
        ELSE 0
    END AS recall,
    AVG(mp.probability_score) AS avg_fraud_probability
FROM 
    MODEL_METADATA mm
    LEFT JOIN ML_PREDICTION mp ON mm.model_id = mp.model_id
    LEFT JOIN FRAUD_LABEL fl ON mp.transaction_id = fl.transaction_id
GROUP BY 
    mm.model_id, mm.model_name, mm.version, mm.trained_at;

-- ============================================================================
-- VIEW 5: Recent Predictions Dashboard
-- Purpose: Latest predictions for dashboard display
-- ============================================================================

CREATE OR REPLACE VIEW recent_predictions AS
SELECT 
    mp.prediction_id,
    mp.transaction_id,
    t.customer_id,
    t.amount,
    t.time,
    mm.model_name,
    mp.predicted_class,
    mp.probability_score,
    fl.is_fraud AS actual_class,
    CASE 
        WHEN mp.predicted_class = fl.is_fraud THEN 'Correct'
        ELSE 'Incorrect'
    END AS prediction_result,
    mp.predicted_at
FROM 
    ML_PREDICTION mp
    JOIN TRANSACTION t ON mp.transaction_id = t.transaction_id
    JOIN MODEL_METADATA mm ON mp.model_id = mm.model_id
    LEFT JOIN FRAUD_LABEL fl ON mp.transaction_id = fl.transaction_id
ORDER BY 
    mp.predicted_at DESC
LIMIT 100;

-- ============================================================================
-- VIEW 6: Transaction Feature Summary
-- Purpose: Pivot features for ML extraction
-- ============================================================================

CREATE OR REPLACE VIEW transaction_feature_summary AS
SELECT 
    tf.transaction_id,
    MAX(CASE WHEN tf.feature_name = 'V1' THEN tf.feature_value END) AS V1,
    MAX(CASE WHEN tf.feature_name = 'V2' THEN tf.feature_value END) AS V2,
    MAX(CASE WHEN tf.feature_name = 'V3' THEN tf.feature_value END) AS V3,
    MAX(CASE WHEN tf.feature_name = 'V4' THEN tf.feature_value END) AS V4,
    MAX(CASE WHEN tf.feature_name = 'V5' THEN tf.feature_value END) AS V5,
    MAX(CASE WHEN tf.feature_name = 'V6' THEN tf.feature_value END) AS V6,
    MAX(CASE WHEN tf.feature_name = 'V7' THEN tf.feature_value END) AS V7,
    MAX(CASE WHEN tf.feature_name = 'V8' THEN tf.feature_value END) AS V8,
    MAX(CASE WHEN tf.feature_name = 'V9' THEN tf.feature_value END) AS V9,
    MAX(CASE WHEN tf.feature_name = 'V10' THEN tf.feature_value END) AS V10,
    MAX(CASE WHEN tf.feature_name = 'V11' THEN tf.feature_value END) AS V11,
    MAX(CASE WHEN tf.feature_name = 'V12' THEN tf.feature_value END) AS V12,
    MAX(CASE WHEN tf.feature_name = 'V13' THEN tf.feature_value END) AS V13,
    MAX(CASE WHEN tf.feature_name = 'V14' THEN tf.feature_value END) AS V14,
    MAX(CASE WHEN tf.feature_name = 'V15' THEN tf.feature_value END) AS V15,
    MAX(CASE WHEN tf.feature_name = 'V16' THEN tf.feature_value END) AS V16,
    MAX(CASE WHEN tf.feature_name = 'V17' THEN tf.feature_value END) AS V17,
    MAX(CASE WHEN tf.feature_name = 'V18' THEN tf.feature_value END) AS V18,
    MAX(CASE WHEN tf.feature_name = 'V19' THEN tf.feature_value END) AS V19,
    MAX(CASE WHEN tf.feature_name = 'V20' THEN tf.feature_value END) AS V20,
    MAX(CASE WHEN tf.feature_name = 'V21' THEN tf.feature_value END) AS V21,
    MAX(CASE WHEN tf.feature_name = 'V22' THEN tf.feature_value END) AS V22,
    MAX(CASE WHEN tf.feature_name = 'V23' THEN tf.feature_value END) AS V23,
    MAX(CASE WHEN tf.feature_name = 'V24' THEN tf.feature_value END) AS V24,
    MAX(CASE WHEN tf.feature_name = 'V25' THEN tf.feature_value END) AS V25,
    MAX(CASE WHEN tf.feature_name = 'V26' THEN tf.feature_value END) AS V26,
    MAX(CASE WHEN tf.feature_name = 'V27' THEN tf.feature_value END) AS V27,
    MAX(CASE WHEN tf.feature_name = 'V28' THEN tf.feature_value END) AS V28
FROM 
    TRANSACTION_FEATURES tf
GROUP BY 
    tf.transaction_id;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Views created: 6
-- 1. customer_transaction_stats - Customer behavior aggregates
-- 2. high_risk_transactions - Anomaly detection
-- 3. fraud_patterns - Temporal/amount patterns
-- 4. model_performance_summary - Model metrics
-- 5. recent_predictions - Dashboard data
-- 6. transaction_feature_summary - Feature pivot for ML
-- ============================================================================
