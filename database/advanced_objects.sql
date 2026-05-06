-- ============================================================================
-- Financial Fraud Detection System - Advanced Database Objects
-- Triggers, Functions, and Stored Procedures for 'fraud_db'
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- 1. FUNCTIONS
-- Encapsulate reusable business logic
-- ============================================================================

-- Function 1: Calculate Customer Risk Score
-- Calculates a simplified risk score (0.0 to 1.0) based on fraud history
DROP FUNCTION IF EXISTS calculate_customer_risk_score;
DELIMITER //
CREATE FUNCTION calculate_customer_risk_score(p_customer_id INT) 
RETURNS DECIMAL(5,4)
DETERMINISTIC
BEGIN
    DECLARE v_total_transactions INT;
    DECLARE v_total_fraud INT;
    DECLARE v_risk_score DECIMAL(5,4);

    -- Get current counts
    SELECT total_transactions, total_fraud_count 
    INTO v_total_transactions, v_total_fraud
    FROM CUSTOMER 
    WHERE customer_id = p_customer_id;

    -- Calculate risk: (Fraud Count / Total Transactions)
    -- Add a small base risk (0.001) for having any transaction history
    IF v_total_transactions > 0 THEN
        SET v_risk_score = (v_total_fraud / v_total_transactions) + 0.001;
    ELSE
        SET v_risk_score = 0.0000;
    END IF;

    -- Cap it at 1.0000
    IF v_risk_score > 1.0000 THEN
        SET v_risk_score = 1.0000;
    END IF;

    RETURN v_risk_score;
END //
DELIMITER ;


-- Function 2: Extract Model Metric
-- Extracts a specific performance metric from the JSON column in MODEL_METADATA
DROP FUNCTION IF EXISTS extract_model_metric;
DELIMITER //
CREATE FUNCTION extract_model_metric(p_model_id INT, p_metric_name VARCHAR(50)) 
RETURNS DECIMAL(5,4)
DETERMINISTIC
BEGIN
    DECLARE v_metric_value DECIMAL(5,4);
    
    SELECT JSON_EXTRACT(metrics, CONCAT('$.', p_metric_name))
    INTO v_metric_value
    FROM MODEL_METADATA
    WHERE model_id = p_model_id;
    
    RETURN COALESCE(v_metric_value, 0.0000);
END //
DELIMITER ;


-- ============================================================================
-- 2. TRIGGERS
-- Automate data integrity and maintain derived statistics
-- ============================================================================

-- Trigger 1: Update Customer Stats on New Transaction
-- When a new transaction is inserted, update the customer's total count and last active time
DROP TRIGGER IF EXISTS after_transaction_insert;
DELIMITER //
CREATE TRIGGER after_transaction_insert
AFTER INSERT ON TRANSACTION
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER 
    SET 
        total_transactions = total_transactions + 1,
        last_transaction_time = NEW.time
    WHERE customer_id = NEW.customer_id;
END //
DELIMITER ;


-- Trigger 2: Update Fraud Count and Risk Score on New Fraud Label
-- When a transaction is labeled as fraud, update the customer's fraud tally and risk score
DROP TRIGGER IF EXISTS after_fraud_label_insert;
DELIMITER //
CREATE TRIGGER after_fraud_label_insert
AFTER INSERT ON FRAUD_LABEL
FOR EACH ROW
BEGIN
    DECLARE v_customer_id INT;
    
    -- Find the customer associated with this transaction
    SELECT customer_id INTO v_customer_id
    FROM TRANSACTION 
    WHERE transaction_id = NEW.transaction_id;

    -- If this is a fraudulent transaction, update the count and recalculate risk
    IF NEW.is_fraud = TRUE AND v_customer_id IS NOT NULL THEN
        UPDATE CUSTOMER 
        SET 
            total_fraud_count = total_fraud_count + 1,
            risk_score = calculate_customer_risk_score(v_customer_id) -- using our custom function
        WHERE customer_id = v_customer_id;
    END IF;
END //
DELIMITER ;


-- Trigger 3: Prevent Deletion of Active Models
-- Ensures we don't accidentally delete the currently active ML model
DROP TRIGGER IF EXISTS before_model_delete;
DELIMITER //
CREATE TRIGGER before_model_delete
BEFORE DELETE ON MODEL_METADATA
FOR EACH ROW
BEGIN
    IF OLD.is_active = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete the currently active machine learning model.';
    END IF;
END //
DELIMITER ;


-- ============================================================================
-- 3. STORED PROCEDURES
-- Handle complex, multi-step database operations
-- ============================================================================

-- Procedure 1: Insert Core Transaction Record
-- Simplifies the process of inserting a transaction and returning its ID
DROP PROCEDURE IF EXISTS sp_add_core_transaction;
DELIMITER //
CREATE PROCEDURE sp_add_core_transaction(
    IN p_customer_id INT,
    IN p_time INT,
    IN p_amount DECIMAL(10,2),
    OUT p_transaction_id INT
)
BEGIN
    -- Insert the core transaction fact
    INSERT INTO TRANSACTION (customer_id, time, amount)
    VALUES (p_customer_id, p_time, p_amount);
    
    -- Capture the auto-generated ID to pass back to the application
    SET p_transaction_id = LAST_INSERT_ID();
END //
DELIMITER ;


-- Procedure 2: Get Customer Fraud Summary
-- Returns a comprehensive view of a customer's history in a single call
DROP PROCEDURE IF EXISTS sp_get_customer_fraud_summary;
DELIMITER //
CREATE PROCEDURE sp_get_customer_fraud_summary(
    IN p_customer_id INT
)
BEGIN
    SELECT 
        c.customer_id,
        c.created_at AS 'customer_since',
        c.total_transactions,
        c.total_fraud_count,
        c.risk_score,
        (c.total_fraud_count / NULLIF(c.total_transactions, 0)) * 100 AS 'fraud_percentage',
        MAX(t.amount) AS 'max_transaction_amount',
        AVG(t.amount) AS 'avg_transaction_amount'
    FROM 
        CUSTOMER c
    LEFT JOIN 
        TRANSACTION t ON c.customer_id = t.customer_id
    WHERE 
        c.customer_id = p_customer_id
    GROUP BY 
        c.customer_id, c.created_at, c.total_transactions, c.total_fraud_count, c.risk_score;
END //
DELIMITER ;


-- Procedure 3: Archive Old Transactions
-- Moves transactions older than a specific threshold to the archive table
DROP PROCEDURE IF EXISTS sp_archive_old_transactions;
DELIMITER //
CREATE PROCEDURE sp_archive_old_transactions(
    IN p_older_than_seconds INT,
    OUT p_rows_archived INT
)
BEGIN
    -- This requires the TRANSACTION_ARCHIVE table to exist
    
    -- 1. Insert into archive
    INSERT INTO TRANSACTION_ARCHIVE (transaction_id, customer_id, time, amount, created_at, archived_at)
    SELECT transaction_id, customer_id, time, amount, created_at, CURRENT_TIMESTAMP
    FROM TRANSACTION
    WHERE time < p_older_than_seconds;
    
    -- 2. Capture rows affected
    SET p_rows_archived = ROW_COUNT();
    
    -- 3. Delete from active table
    -- Since we have ON DELETE CASCADE on related tables (TRANSACTION_FEATURES, FRAUD_LABEL),
    -- those records will automatically be removed from active tables as well.
    DELETE FROM TRANSACTION
    WHERE time < p_older_than_seconds;
    
END //
DELIMITER ;
