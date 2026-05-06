-- ============================================================================
-- Financial Fraud Detection System
-- TASK 2: COMPLEX SUBQUERIES, JOINS, AND VIEWS
-- ============================================================================
-- Concepts Covered:
--   Subqueries : Scalar, Row, Table, Correlated, EXISTS / NOT EXISTS, IN / NOT IN
--   JOINs      : INNER JOIN, LEFT JOIN, RIGHT JOIN, CROSS JOIN, SELF JOIN,
--                Multi-table JOIN, JOIN with aggregation
--   Views      : Simple view, Complex view, Updatable view, Nested view
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- SECTION A: SUBQUERIES
-- ============================================================================

-- -----------------------------------------------------------------------
-- A1. Scalar Subquery
-- Find transactions with an amount ABOVE the overall average amount
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id,
    t.customer_id,
    t.amount,
    (SELECT AVG(amount) FROM TRANSACTION) AS overall_avg,
    ROUND(t.amount - (SELECT AVG(amount) FROM TRANSACTION), 2) AS deviation_from_avg
FROM TRANSACTION t
WHERE t.amount > (SELECT AVG(amount) FROM TRANSACTION)
ORDER BY t.amount DESC
LIMIT 20;

-- -----------------------------------------------------------------------
-- A2. Row Subquery — Fetch the transaction with the single highest amount
-- -----------------------------------------------------------------------
SELECT transaction_id, customer_id, amount, time
FROM TRANSACTION
WHERE (amount, customer_id) = (
    SELECT MAX(amount), customer_id
    FROM TRANSACTION
    WHERE amount = (SELECT MAX(amount) FROM TRANSACTION)
    LIMIT 1
);

-- -----------------------------------------------------------------------
-- A3. Table Subquery (derived table / inline view)
-- Calculate per-customer fraud density and rank customers
-- -----------------------------------------------------------------------
SELECT 
    base.customer_id,
    base.total_transactions,
    base.fraud_count,
    base.fraud_density,
    CASE
        WHEN base.fraud_density = 0        THEN 'Safe'
        WHEN base.fraud_density < 0.05     THEN 'Low Risk'
        WHEN base.fraud_density < 0.20     THEN 'Medium Risk'
        ELSE                                    'High Risk'
    END AS risk_category
FROM (
    SELECT 
        c.customer_id,
        COUNT(t.transaction_id)                                        AS total_transactions,
        COUNT(CASE WHEN fl.is_fraud = TRUE THEN 1 END)                 AS fraud_count,
        COALESCE(COUNT(CASE WHEN fl.is_fraud = TRUE THEN 1 END) /
                 NULLIF(COUNT(t.transaction_id), 0), 0)                AS fraud_density
    FROM CUSTOMER c
    LEFT JOIN TRANSACTION  t  ON c.customer_id     = t.customer_id
    LEFT JOIN FRAUD_LABEL  fl ON t.transaction_id  = fl.transaction_id
    GROUP BY c.customer_id
    HAVING total_transactions > 0
) AS base
ORDER BY base.fraud_density DESC
LIMIT 25;

-- -----------------------------------------------------------------------
-- A4. Correlated Subquery
-- For each transaction, find how many OTHER transactions by the same
-- customer have a higher amount (peer ranking within customer portfolio)
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id,
    t.customer_id,
    t.amount,
    (
        SELECT COUNT(*)
        FROM TRANSACTION t2
        WHERE t2.customer_id = t.customer_id
          AND t2.amount      > t.amount
    ) AS tx_with_higher_amount_same_customer
FROM TRANSACTION t
ORDER BY t.customer_id, t.amount DESC
LIMIT 30;

-- -----------------------------------------------------------------------
-- A5. EXISTS / NOT EXISTS
-- A5a. Customers who have AT LEAST ONE fraud transaction (EXISTS)
-- -----------------------------------------------------------------------
SELECT c.customer_id, c.risk_score, c.total_transactions
FROM CUSTOMER c
WHERE EXISTS (
    SELECT 1
    FROM TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
    WHERE t.customer_id = c.customer_id
      AND fl.is_fraud = TRUE
)
ORDER BY c.risk_score DESC;

-- A5b. Customers who have NEVER had a fraud transaction (NOT EXISTS)
SELECT c.customer_id, c.total_transactions, c.risk_score
FROM CUSTOMER c
WHERE NOT EXISTS (
    SELECT 1
    FROM TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
    WHERE t.customer_id = c.customer_id
      AND fl.is_fraud = TRUE
);

-- -----------------------------------------------------------------------
-- A6. IN / NOT IN with Subquery
-- A6a. Transactions that were predicted as fraud by ANY active model (IN)
-- -----------------------------------------------------------------------
SELECT t.transaction_id, t.customer_id, t.amount
FROM TRANSACTION t
WHERE t.transaction_id IN (
    SELECT mp.transaction_id
    FROM ML_PREDICTION mp
    JOIN MODEL_METADATA mm ON mp.model_id = mm.model_id
    WHERE mm.is_active = TRUE
      AND mp.predicted_class = TRUE
);

-- A6b. Transactions with a fraud label NOT captured by the active model (NOT IN)
--      This reveals false negatives at the transaction level
SELECT fl.transaction_id, t.amount, fl.is_fraud
FROM FRAUD_LABEL fl
JOIN TRANSACTION t ON fl.transaction_id = t.transaction_id
WHERE fl.is_fraud = TRUE
  AND fl.transaction_id NOT IN (
      SELECT mp.transaction_id
      FROM ML_PREDICTION mp
      JOIN MODEL_METADATA mm ON mp.model_id = mm.model_id
      WHERE mm.is_active = TRUE
        AND mp.predicted_class = TRUE
  );

-- -----------------------------------------------------------------------
-- A7. Nested Subquery (subquery within a subquery)
-- Customers whose average transaction amount exceeds the average
-- of all "high-risk" customers
-- -----------------------------------------------------------------------
SELECT 
    t.customer_id,
    AVG(t.amount) AS customer_avg_amount
FROM TRANSACTION t
GROUP BY t.customer_id
HAVING AVG(t.amount) > (
    SELECT AVG(inner_avg)
    FROM (
        SELECT AVG(t2.amount) AS inner_avg
        FROM TRANSACTION t2
        JOIN CUSTOMER c2 ON t2.customer_id = c2.customer_id
        WHERE c2.risk_score >= 0.3
        GROUP BY t2.customer_id
    ) AS high_risk_averages
)
ORDER BY customer_avg_amount DESC;


-- ============================================================================
-- SECTION B: JOINS
-- ============================================================================

-- -----------------------------------------------------------------------
-- B1. INNER JOIN — Transactions that have both a fraud label AND a prediction
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id,
    t.customer_id,
    t.amount,
    fl.is_fraud        AS actual_fraud,
    mp.predicted_class AS predicted_fraud,
    mp.probability_score,
    mm.model_name
FROM TRANSACTION t
INNER JOIN FRAUD_LABEL  fl ON t.transaction_id = fl.transaction_id
INNER JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id
INNER JOIN MODEL_METADATA mm ON mp.model_id     = mm.model_id
WHERE mm.is_active = TRUE
ORDER BY mp.probability_score DESC
LIMIT 25;

-- -----------------------------------------------------------------------
-- B2. LEFT JOIN — All transactions, showing fraud label even if missing
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id,
    t.customer_id,
    t.amount,
    COALESCE(fl.is_fraud, 'Not Labeled') AS fraud_status
FROM TRANSACTION t
LEFT JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
ORDER BY t.transaction_id
LIMIT 30;

-- -----------------------------------------------------------------------
-- B3. RIGHT JOIN — All fraud labels, even those without matching transactions
--     (data integrity check: orphaned labels)
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id   AS txn_id,
    t.amount,
    fl.label_id,
    fl.is_fraud
FROM TRANSACTION t
RIGHT JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
ORDER BY fl.label_id
LIMIT 30;

-- -----------------------------------------------------------------------
-- B4. CROSS JOIN — Cartesian product of models × risk categories
--     Useful for generating a report template for all combinations
-- -----------------------------------------------------------------------
SELECT 
    mm.model_name,
    mm.version,
    risk_tbl.risk_category
FROM MODEL_METADATA mm
CROSS JOIN (
    SELECT 'Low Risk'    AS risk_category UNION ALL
    SELECT 'Medium Risk'                   UNION ALL
    SELECT 'High Risk'
) AS risk_tbl
ORDER BY mm.model_name, risk_tbl.risk_category;

-- -----------------------------------------------------------------------
-- B5. SELF JOIN — Compare each customer against every other customer
--     to find pairs with similar risk scores (within 0.05 of each other)
-- -----------------------------------------------------------------------
SELECT 
    c1.customer_id          AS customer_a,
    c2.customer_id          AS customer_b,
    c1.risk_score           AS risk_a,
    c2.risk_score           AS risk_b,
    ABS(c1.risk_score - c2.risk_score) AS risk_difference
FROM CUSTOMER c1
JOIN CUSTOMER c2 
  ON c1.customer_id < c2.customer_id    -- avoids mirrored and self pairs
 AND ABS(c1.risk_score - c2.risk_score) <= 0.05
ORDER BY risk_difference
LIMIT 20;

-- -----------------------------------------------------------------------
-- B6. Multi-Table JOIN — Full transaction audit trail in one query
-- -----------------------------------------------------------------------
SELECT 
    t.transaction_id,
    t.customer_id,
    t.time                                AS elapsed_seconds,
    t.amount,
    fl.is_fraud                           AS actual_label,
    mp.predicted_class                    AS model_prediction,
    ROUND(mp.probability_score * 100, 2) AS fraud_probability_pct,
    mm.model_name,
    mm.version,
    CASE 
        WHEN fl.is_fraud = mp.predicted_class THEN 'Correct'
        ELSE 'Incorrect'
    END AS prediction_outcome
FROM TRANSACTION t
LEFT JOIN FRAUD_LABEL   fl ON t.transaction_id = fl.transaction_id
LEFT JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id
LEFT JOIN MODEL_METADATA mm ON mp.model_id     = mm.model_id
ORDER BY mp.probability_score DESC
LIMIT 50;

-- -----------------------------------------------------------------------
-- B7. JOIN with Aggregation + HAVING
-- Models that have made > 100 predictions AND precision > 80%
-- -----------------------------------------------------------------------
SELECT 
    mm.model_name,
    mm.version,
    COUNT(mp.prediction_id)   AS total_predictions,
    ROUND(
        SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 1 THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN mp.predicted_class = 1 THEN 1 ELSE 0 END), 0) * 100, 2
    ) AS precision_pct
FROM MODEL_METADATA mm
JOIN ML_PREDICTION mp ON mm.model_id     = mp.model_id
JOIN FRAUD_LABEL   fl ON mp.transaction_id = fl.transaction_id
GROUP BY mm.model_name, mm.version
HAVING total_predictions > 100
   AND precision_pct     > 80
ORDER BY precision_pct DESC;


-- ============================================================================
-- SECTION C: VIEWS
-- ============================================================================

-- -----------------------------------------------------------------------
-- V1. Simple View: Active Model Summary
-- Shows only the currently active model's key metadata
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_active_model AS
SELECT 
    model_id,
    model_name,
    version,
    trained_at,
    training_samples,
    notes
FROM MODEL_METADATA
WHERE is_active = TRUE;

-- -----------------------------------------------------------------------
-- V2. Complex View: Transaction Risk Profile
-- Joins TRANSACTION, FRAUD_LABEL, ML_PREDICTION, and CUSTOMER
-- to build a comprehensive per-transaction risk profile
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_transaction_risk_profile AS
SELECT 
    t.transaction_id,
    t.customer_id,
    c.risk_score                              AS customer_risk_score,
    t.amount,
    t.time                                    AS elapsed_seconds,
    fl.is_fraud                               AS confirmed_fraud,
    mp.predicted_class                        AS predicted_fraud,
    ROUND(mp.probability_score, 4)            AS fraud_probability,
    CASE 
        WHEN fl.is_fraud = TRUE AND mp.predicted_class = TRUE  THEN 'True Positive'
        WHEN fl.is_fraud = FALSE AND mp.predicted_class = TRUE THEN 'False Positive'
        WHEN fl.is_fraud = TRUE AND mp.predicted_class = FALSE THEN 'False Negative'
        ELSE                                                        'True Negative'
    END AS prediction_category,
    CASE 
        WHEN mp.probability_score >= 0.9 THEN 'Critical'
        WHEN mp.probability_score >= 0.7 THEN 'High'
        WHEN mp.probability_score >= 0.4 THEN 'Medium'
        ELSE                                  'Low'
    END AS risk_tier
FROM TRANSACTION t
JOIN CUSTOMER      c  ON t.transaction_id  = c.customer_id
LEFT JOIN FRAUD_LABEL   fl ON t.transaction_id = fl.transaction_id
LEFT JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id;

-- -----------------------------------------------------------------------
-- V3. Updatable View: Unresolved Alerts
-- Exposes only unresolved alerts — writes through to fraud_alert_log
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_unresolved_alerts AS
SELECT 
    alert_id,
    transaction_id,
    alert_type,
    severity,
    alert_message,
    created_at
FROM fraud_alert_log
WHERE resolved = FALSE
WITH CHECK OPTION;  -- prevents updates that would move rows out of this view

-- -----------------------------------------------------------------------
-- V4. Nested View: High-Risk Unresolved Alerts
-- Builds on top of vw_unresolved_alerts (view referencing a view)
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_critical_alerts AS
SELECT 
    ua.alert_id,
    ua.transaction_id,
    ua.alert_type,
    ua.severity,
    ua.alert_message,
    ua.created_at,
    t.amount,
    t.customer_id
FROM vw_unresolved_alerts ua
JOIN TRANSACTION t ON ua.transaction_id = t.transaction_id
WHERE ua.severity >= 4           -- severity 4 = High, 5 = Critical
ORDER BY ua.severity DESC, ua.created_at ASC;

-- -----------------------------------------------------------------------
-- V5. Statistical Benchmark View
-- Used as a reference benchmark for anomaly detection thresholds
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_transaction_benchmarks AS
SELECT 
    'Amount (All)'          AS metric,
    ROUND(AVG(amount), 2)   AS mean_val,
    ROUND(STDDEV(amount), 2) AS std_dev,
    ROUND(MIN(amount), 2)   AS min_val,
    ROUND(MAX(amount), 2)   AS max_val
FROM TRANSACTION

UNION ALL

SELECT 
    'Amount (Fraud)'        AS metric,
    ROUND(AVG(t.amount), 2),
    ROUND(STDDEV(t.amount), 2),
    ROUND(MIN(t.amount), 2),
    ROUND(MAX(t.amount), 2)
FROM TRANSACTION t
JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
WHERE fl.is_fraud = TRUE

UNION ALL

SELECT 
    'Amount (Legitimate)'   AS metric,
    ROUND(AVG(t.amount), 2),
    ROUND(STDDEV(t.amount), 2),
    ROUND(MIN(t.amount), 2),
    ROUND(MAX(t.amount), 2)
FROM TRANSACTION t
JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
WHERE fl.is_fraud = FALSE;

-- ============================================================================
-- SAMPLE QUERIES USING THE VIEWS ABOVE
-- ============================================================================

-- Query the active model
SELECT * FROM vw_active_model;

-- Retrieve all Critical / High alerts with transaction details
SELECT * FROM vw_critical_alerts LIMIT 20;

-- Benchmark thresholds for anomaly detection
SELECT * FROM vw_transaction_benchmarks;

-- Use vw_transaction_risk_profile to count prediction categories
SELECT prediction_category, COUNT(*) AS count
FROM vw_transaction_risk_profile
GROUP BY prediction_category;

-- ============================================================================
-- END OF TASK 2
-- ============================================================================
