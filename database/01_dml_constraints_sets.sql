-- ============================================================================
-- Financial Fraud Detection System
-- TASK 1: DML, CONSTRAINTS, and SET OPERATIONS
-- ============================================================================
-- Concepts Covered:
--   DML       : INSERT, UPDATE, DELETE, MERGE (INSERT ... ON DUPLICATE KEY UPDATE)
--   Constraints: PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, DEFAULT
--   Set Ops   : UNION, UNION ALL, INTERSECT (simulated), EXCEPT (simulated)
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- SECTION A: CONSTRAINTS DEMONSTRATION
-- Shows every constraint type on a dedicated demo table
-- ============================================================================

-- Drop demo table if it already exists (for re-run safety)
DROP TABLE IF EXISTS fraud_alert_log;

CREATE TABLE fraud_alert_log (
    alert_id       INT           AUTO_INCREMENT,
    transaction_id INT           NOT NULL,                         -- NOT NULL constraint
    alert_type     VARCHAR(50)   NOT NULL,
    severity       TINYINT       NOT NULL DEFAULT 2,               -- DEFAULT constraint
    alert_message  VARCHAR(500),
    resolved       BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    resolved_at    TIMESTAMP     NULL,

    -- PRIMARY KEY constraint
    PRIMARY KEY (alert_id),

    -- UNIQUE constraint: one open alert per transaction per type
    UNIQUE KEY uk_txn_alert_type (transaction_id, alert_type),

    -- FOREIGN KEY constraint with ON DELETE CASCADE
    CONSTRAINT fk_alert_transaction
        FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- CHECK constraint: severity must be between 1 (low) and 5 (critical)
    CONSTRAINT chk_severity CHECK (severity BETWEEN 1 AND 5),

    -- CHECK constraint: resolved_at only set when resolved is TRUE
    CONSTRAINT chk_resolved_at CHECK (
        resolved_at IS NULL OR resolved = TRUE
    ),

    INDEX idx_alert_severity   (severity),
    INDEX idx_alert_resolved   (resolved),
    INDEX idx_alert_created_at (created_at)
) ENGINE=InnoDB COMMENT='Fraud alerts generated per transaction';


-- ============================================================================
-- SECTION B: DML — INSERT
-- ============================================================================

-- B1. Simple INSERT for a new customer
INSERT INTO CUSTOMER (total_transactions, total_fraud_count, risk_score, last_transaction_time)
VALUES (0, 0, 0.0000, NULL);

-- Capture newly inserted customer_id for use in subsequent statements
SET @new_customer_id = LAST_INSERT_ID();

-- B2. INSERT a transaction for the new customer
INSERT INTO TRANSACTION (customer_id, time, amount)
VALUES (@new_customer_id, 3600, 250.00);

SET @new_txn_id = LAST_INSERT_ID();

-- B3. INSERT a fraud label for that transaction
INSERT INTO FRAUD_LABEL (transaction_id, is_fraud)
VALUES (@new_txn_id, TRUE);

-- B4. Multi-row INSERT into fraud_alert_log
INSERT INTO fraud_alert_log (transaction_id, alert_type, severity, alert_message)
VALUES
    (@new_txn_id, 'HIGH_AMOUNT',  3, 'Transaction amount exceeds customer average by 3x.'),
    (@new_txn_id, 'FRAUD_LABEL',  5, 'Transaction has been labeled as FRAUD by the model.');

-- B5. INSERT ... SELECT — copy high-risk transactions into alert log
--     (skips duplicates via INSERT IGNORE to respect the UNIQUE constraint)
INSERT IGNORE INTO fraud_alert_log (transaction_id, alert_type, severity, alert_message)
SELECT 
    t.transaction_id,
    'HIGH_PROBABILITY'                          AS alert_type,
    CASE
        WHEN mp.probability_score >= 0.9 THEN 5
        WHEN mp.probability_score >= 0.7 THEN 4
        ELSE 3
    END                                         AS severity,
    CONCAT('ML model probability: ', ROUND(mp.probability_score * 100, 2), '%') AS alert_message
FROM 
    ML_PREDICTION mp
    JOIN TRANSACTION t ON mp.transaction_id = t.transaction_id
WHERE 
    mp.probability_score > 0.7
    AND mp.predicted_class = TRUE;

-- B6. UPSERT pattern — INSERT ... ON DUPLICATE KEY UPDATE
--     Update severity if the same alert already exists
INSERT INTO fraud_alert_log (transaction_id, alert_type, severity, alert_message)
VALUES (@new_txn_id, 'HIGH_AMOUNT', 4, 'Updated: Amount now exceeds 4x customer average.')
ON DUPLICATE KEY UPDATE
    severity      = VALUES(severity),
    alert_message = VALUES(alert_message);


-- ============================================================================
-- SECTION C: DML — UPDATE
-- ============================================================================

-- C1. Simple UPDATE: mark the new alert as resolved
UPDATE fraud_alert_log
SET 
    resolved    = TRUE,
    resolved_at = CURRENT_TIMESTAMP
WHERE 
    transaction_id = @new_txn_id
    AND alert_type = 'HIGH_AMOUNT';

-- C2. Bulk UPDATE: recalculate risk_score for all customers using fraud ratio
UPDATE CUSTOMER c
JOIN (
    SELECT 
        customer_id,
        ROUND(total_fraud_count / NULLIF(total_transactions, 0), 4) AS new_risk
    FROM CUSTOMER
    WHERE total_transactions > 0
) subq ON c.customer_id = subq.customer_id
SET c.risk_score = subq.new_risk;

-- C3. UPDATE with CASE expression: set severity based on probability bracket
UPDATE fraud_alert_log fal
JOIN ML_PREDICTION mp ON fal.transaction_id = mp.transaction_id
SET fal.severity = CASE
    WHEN mp.probability_score >= 0.95 THEN 5
    WHEN mp.probability_score >= 0.80 THEN 4
    WHEN mp.probability_score >= 0.60 THEN 3
    ELSE 2
END
WHERE fal.alert_type = 'HIGH_PROBABILITY';


-- ============================================================================
-- SECTION D: DML — DELETE
-- ============================================================================

-- D1. Delete resolved alerts older than 30 days
DELETE FROM fraud_alert_log
WHERE 
    resolved    = TRUE
    AND resolved_at < NOW() - INTERVAL 30 DAY;

-- D2. Delete transactions with $0 amount (data quality cleanup)
--     Cascade will remove related FRAUD_LABEL and TRANSACTION_FEATURES rows
DELETE FROM TRANSACTION
WHERE amount = 0.00;

-- D3. Soft-delete pattern: mark alerts as resolved instead of hard-deleting
--     (alternative non-destructive approach for audit trails)
UPDATE fraud_alert_log
SET 
    resolved    = TRUE,
    resolved_at = CURRENT_TIMESTAMP,
    alert_message = CONCAT('[SOFT-DELETED] ', alert_message)
WHERE severity = 1;         -- remove only "low" severity alerts


-- ============================================================================
-- SECTION E: SET OPERATIONS
-- ============================================================================

-- E1. UNION ALL — All customer IDs from two separate risk categories
--     (retains duplicates intentionally to show raw row counts per segment)
SELECT customer_id, 'High Risk'    AS segment FROM CUSTOMER WHERE risk_score >= 0.3
UNION ALL
SELECT customer_id, 'Medium Risk'  AS segment FROM CUSTOMER WHERE risk_score >= 0.1 AND risk_score < 0.3;

-- E2. UNION (distinct) — Customers who have EITHER a fraud label OR a high ML score
SELECT DISTINCT t.customer_id
FROM TRANSACTION t
JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
WHERE fl.is_fraud = TRUE

UNION

SELECT DISTINCT t.customer_id
FROM TRANSACTION t
JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id
WHERE mp.probability_score > 0.8;

-- E3. INTERSECT simulation — Customers confirmed fraudulent AND predicted fraudulent
--     MySQL does not have a native INTERSECT; we simulate it with INNER JOIN
SELECT DISTINCT t1.customer_id
FROM (
    SELECT DISTINCT t.customer_id
    FROM TRANSACTION t
    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
    WHERE fl.is_fraud = TRUE
) t1
INNER JOIN (
    SELECT DISTINCT t.customer_id
    FROM TRANSACTION t
    JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id
    WHERE mp.probability_score > 0.8 AND mp.predicted_class = TRUE
) t2 ON t1.customer_id = t2.customer_id;

-- E4. EXCEPT simulation — Customers with verified fraud label but NOT flagged by the model
--     (i.e., false negatives at the customer level)
SELECT DISTINCT t.customer_id
FROM TRANSACTION t
JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
WHERE fl.is_fraud = TRUE

AND t.customer_id NOT IN (
    SELECT DISTINCT tx.customer_id
    FROM TRANSACTION tx
    JOIN ML_PREDICTION mp ON tx.transaction_id = mp.transaction_id
    WHERE mp.predicted_class = TRUE
);

-- E5. Multi-source UNION for a unified fraud dashboard summary
SELECT 
    'Confirmed Fraud'          AS source,
    COUNT(*)                   AS record_count,
    AVG(t.amount)              AS avg_amount
FROM FRAUD_LABEL fl
JOIN TRANSACTION t ON fl.transaction_id = t.transaction_id
WHERE fl.is_fraud = TRUE

UNION ALL

SELECT 
    'ML Predicted Fraud'       AS source,
    COUNT(*)                   AS record_count,
    AVG(t.amount)              AS avg_amount
FROM ML_PREDICTION mp
JOIN TRANSACTION t ON mp.transaction_id = t.transaction_id
WHERE mp.predicted_class = TRUE AND mp.probability_score > 0.7

UNION ALL

SELECT 
    'Open Fraud Alerts'        AS source,
    COUNT(*)                   AS record_count,
    NULL                       AS avg_amount
FROM fraud_alert_log
WHERE resolved = FALSE
ORDER BY record_count DESC;

-- ============================================================================
-- SECTION F: AGGREGATE FUNCTIONS
-- Demonstrates: COUNT, SUM, AVG, MIN, MAX with GROUP BY and HAVING
-- ============================================================================

-- F1. Basic statistics for transactions
SELECT 
    COUNT(*)            AS total_transactions,
    SUM(amount)         AS total_volume,
    AVG(amount)         AS average_amount,
    MIN(amount)         AS smallest_txn,
    MAX(amount)         AS largest_txn
FROM TRANSACTION;

-- F2. Transaction volume and average by customer
--     Calculates behavior metrics per user
SELECT 
    customer_id,
    COUNT(transaction_id) AS txn_count,
    ROUND(SUM(amount), 2) AS total_spent,
    ROUND(AVG(amount), 2) AS avg_txn_value
FROM TRANSACTION
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 20;

-- F3. Usage of HAVING to find potential high-activity accounts
--     Filter customers who have more than 5 transactions AND total volume > 500
SELECT 
    customer_id,
    COUNT(*)             AS transaction_count,
    ROUND(SUM(amount), 2) AS total_amount
FROM TRANSACTION
GROUP BY customer_id
HAVING transaction_count > 5 AND total_amount > 500
ORDER BY transaction_count DESC;

-- F4. Aggregate functions on Fraud vs Legitimate transactions
--     Reveals statistical differences between classes
SELECT 
    fl.is_fraud,
    COUNT(*)             AS record_count,
    ROUND(AVG(t.amount), 2) AS avg_amount,
    ROUND(MAX(t.amount), 2) AS max_amount
FROM TRANSACTION t
JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
GROUP BY fl.is_fraud;

-- F5. Grouping by time intervals (simulated hourly buckets)
--     Finding peak transaction hours
SELECT 
    FLOOR(time / 3600)   AS hour_bucket,
    COUNT(*)             AS hourly_count,
    ROUND(SUM(amount), 2) AS hourly_volume
FROM TRANSACTION
GROUP BY hour_bucket
ORDER BY hour_bucket
LIMIT 24;

-- ============================================================================
-- END OF TASK 1
-- ============================================================================

