-- ============================================================================
-- Sample Analytical Queries
-- Purpose: Demonstrate SQL-based feature engineering and analysis
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- QUERY 1: Top 10 High-Risk Customers
-- ============================================================================

SELECT 
    customer_id,
    transaction_count,
    fraud_count,
    fraud_ratio,
    avg_transaction_amount,
    risk_score
FROM 
    customer_transaction_stats
WHERE 
    transaction_count >= 5
ORDER BY 
    fraud_ratio DESC, risk_score DESC
LIMIT 10;

-- ============================================================================
-- QUERY 2: Fraud Distribution by Time Bucket
-- ============================================================================

SELECT 
    hour_bucket,
    total_transactions,
    fraud_transactions,
    ROUND(fraud_rate * 100, 2) AS fraud_percentage,
    avg_amount
FROM 
    fraud_patterns
WHERE 
    fraud_rate > 0.01
ORDER BY 
    fraud_rate DESC
LIMIT 20;

-- ============================================================================
-- QUERY 3: Transaction Amount Distribution
-- ============================================================================

SELECT 
    CASE 
        WHEN amount < 50 THEN '0-50'
        WHEN amount < 100 THEN '50-100'
        WHEN amount < 200 THEN '100-200'
        WHEN amount < 500 THEN '200-500'
        ELSE '500+'
    END AS amount_range,
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(AVG(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) * 100, 2) AS fraud_percentage
FROM 
    TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
GROUP BY 
    amount_range
ORDER BY 
    FIELD(amount_range, '0-50', '50-100', '100-200', '200-500', '500+');

-- ============================================================================
-- QUERY 4: Model Comparison
-- ============================================================================

SELECT 
    model_name,
    version,
    total_predictions,
    ROUND(accuracy * 100, 2) AS accuracy_pct,
    ROUND(precision * 100, 2) AS precision_pct,
    ROUND(recall * 100, 2) AS recall_pct,
    ROUND((2 * precision * recall) / (precision + recall) * 100, 2) AS f1_score_pct
FROM 
    model_performance_summary
WHERE 
    total_predictions > 0
ORDER BY 
    recall DESC, f1_score_pct DESC;

-- ============================================================================
-- QUERY 5: Daily Fraud Trends
-- ============================================================================

SELECT 
    DATE(FROM_UNIXTIME(time)) AS transaction_date,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(AVG(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) * 100, 2) AS fraud_rate,
    AVG(amount) AS avg_amount
FROM 
    TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
GROUP BY 
    transaction_date
ORDER BY 
    transaction_date;

-- ============================================================================
-- QUERY 6: Feature Importance Analysis (V1-V28 correlation with fraud)
-- ============================================================================

SELECT 
    tf.feature_name,
    COUNT(*) AS total_count,
    AVG(tf.feature_value) AS avg_value,
    AVG(CASE WHEN fl.is_fraud = 1 THEN tf.feature_value END) AS avg_fraud_value,
    AVG(CASE WHEN fl.is_fraud = 0 THEN tf.feature_value END) AS avg_legit_value,
    ABS(AVG(CASE WHEN fl.is_fraud = 1 THEN tf.feature_value END) - 
        AVG(CASE WHEN fl.is_fraud = 0 THEN tf.feature_value END)) AS value_difference
FROM 
    TRANSACTION_FEATURES tf
    JOIN FRAUD_LABEL fl ON tf.transaction_id = fl.transaction_id
GROUP BY 
    tf.feature_name
ORDER BY 
    value_difference DESC;

-- ============================================================================
-- QUERY 7: Recent High-Probability Fraud Predictions
-- ============================================================================

SELECT 
    prediction_id,
    transaction_id,
    customer_id,
    amount,
    model_name,
    ROUND(probability_score * 100, 2) AS fraud_probability_pct,
    predicted_class,
    actual_class,
    prediction_result,
    predicted_at
FROM 
    recent_predictions
WHERE 
    probability_score > 0.7
ORDER BY 
    probability_score DESC
LIMIT 20;

-- ============================================================================
-- QUERY 8: Customer Segmentation by Risk
-- ============================================================================

SELECT 
    CASE 
        WHEN fraud_ratio = 0 THEN 'No Fraud'
        WHEN fraud_ratio < 0.1 THEN 'Low Risk'
        WHEN fraud_ratio < 0.3 THEN 'Medium Risk'
        ELSE 'High Risk'
    END AS risk_segment,
    COUNT(*) AS customer_count,
    AVG(transaction_count) AS avg_transactions,
    AVG(avg_transaction_amount) AS avg_amount,
    AVG(fraud_ratio) AS avg_fraud_ratio
FROM 
    customer_transaction_stats
WHERE 
    transaction_count >= 3
GROUP BY 
    risk_segment
ORDER BY 
    FIELD(risk_segment, 'No Fraud', 'Low Risk', 'Medium Risk', 'High Risk');

-- ============================================================================
-- QUERY 9: Confusion Matrix for Active Model
-- ============================================================================

SELECT 
    'Predicted Fraud' AS prediction,
    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS actual_fraud,
    SUM(CASE WHEN fl.is_fraud = 0 THEN 1 ELSE 0 END) AS actual_legitimate
FROM 
    ML_PREDICTION mp
    JOIN FRAUD_LABEL fl ON mp.transaction_id = fl.transaction_id
    JOIN MODEL_METADATA mm ON mp.model_id = mm.model_id
WHERE 
    mm.is_active = 1 AND mp.predicted_class = 1

UNION ALL

SELECT 
    'Predicted Legitimate' AS prediction,
    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS actual_fraud,
    SUM(CASE WHEN fl.is_fraud = 0 THEN 1 ELSE 0 END) AS actual_legitimate
FROM 
    ML_PREDICTION mp
    JOIN FRAUD_LABEL fl ON mp.transaction_id = fl.transaction_id
    JOIN MODEL_METADATA mm ON mp.model_id = mm.model_id
WHERE 
    mm.is_active = 1 AND mp.predicted_class = 0;

-- ============================================================================
-- QUERY 10: Database Statistics
-- ============================================================================

SELECT 
    'Total Customers' AS metric,
    COUNT(*) AS value
FROM CUSTOMER

UNION ALL

SELECT 
    'Total Transactions',
    COUNT(*)
FROM TRANSACTION

UNION ALL

SELECT 
    'Total Fraud Cases',
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END)
FROM FRAUD_LABEL

UNION ALL

SELECT 
    'Total Predictions',
    COUNT(*)
FROM ML_PREDICTION

UNION ALL

SELECT 
    'Active Models',
    COUNT(*)
FROM MODEL_METADATA
WHERE is_active = 1;
