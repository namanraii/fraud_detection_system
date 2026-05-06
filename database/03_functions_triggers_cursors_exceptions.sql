-- ============================================================================
-- Financial Fraud Detection System
-- TASK 3: FUNCTIONS, TRIGGERS, CURSORS, AND EXCEPTION HANDLING
-- ============================================================================
-- Concepts Covered:
--   Functions         : Scalar functions with business logic
--   Triggers          : BEFORE INSERT, AFTER INSERT, AFTER UPDATE, BEFORE DELETE
--   Cursors           : Explicit cursor with OPEN / FETCH / CLOSE loop
--   Exception Handling: DECLARE HANDLER (CONTINUE & EXIT), SIGNAL SQLSTATE
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- PREREQUISITE: Audit log table used by triggers and procedures below
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    log_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    table_name   VARCHAR(100) NOT NULL,
    operation    ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id    BIGINT,
    changed_by   VARCHAR(100) DEFAULT (USER()),
    details      TEXT
) ENGINE=InnoDB COMMENT='Central audit trail for all critical table changes';


-- ============================================================================
-- SECTION A: FUNCTIONS
-- ============================================================================

-- -----------------------------------------------------------------------
-- F1. fn_classify_risk_tier
-- Returns a human-readable risk tier string for a given risk score.
-- -----------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_classify_risk_tier;
DELIMITER //
CREATE FUNCTION fn_classify_risk_tier(p_risk_score DOUBLE)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_tier VARCHAR(20);

    -- Exception handler: if p_risk_score is somehow out of domain, return 'Unknown'
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        RETURN 'Unknown';
    END;

    IF p_risk_score IS NULL THEN
        SET v_tier = 'Unscored';
    ELSEIF p_risk_score >= 0.75 THEN
        SET v_tier = 'Critical';
    ELSEIF p_risk_score >= 0.50 THEN
        SET v_tier = 'High';
    ELSEIF p_risk_score >= 0.25 THEN
        SET v_tier = 'Medium';
    ELSEIF p_risk_score > 0.00 THEN
        SET v_tier = 'Low';
    ELSE
        SET v_tier = 'None';
    END IF;

    RETURN v_tier;
END //
DELIMITER ;

-- Usage Example
SELECT customer_id, risk_score, fn_classify_risk_tier(risk_score) AS risk_tier
FROM CUSTOMER
ORDER BY risk_score DESC
LIMIT 10;


-- -----------------------------------------------------------------------
-- F2. fn_days_since_transaction
-- Returns the number of "equivalent days" elapsed since a transaction
-- (the dataset stores seconds elapsed, so we convert for readability).
-- -----------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_days_since_transaction;
DELIMITER //
CREATE FUNCTION fn_days_since_transaction(p_transaction_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_time_seconds INT;
    DECLARE v_days         DECIMAL(10,2) DEFAULT -1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_days = -1;    -- sentinel: transaction not found
    END;

    SELECT time INTO v_time_seconds
    FROM TRANSACTION
    WHERE transaction_id = p_transaction_id;

    -- Dataset epoch: time=0 is the first transaction ever recorded
    -- Convert to days for human-readable output
    SET v_days = ROUND(v_time_seconds / 86400.0, 2);

    RETURN v_days;
END //
DELIMITER ;

-- Usage Example
SELECT 
    transaction_id,
    time AS seconds_elapsed,
    fn_days_since_transaction(transaction_id) AS dataset_day
FROM TRANSACTION
LIMIT 10;


-- -----------------------------------------------------------------------
-- F3. fn_model_f1_score
-- Calculates the F1-Score for a given model from live prediction data.
-- -----------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_model_f1_score;
DELIMITER //
CREATE FUNCTION fn_model_f1_score(p_model_id INT)
RETURNS DOUBLE
READS SQL DATA
BEGIN
    DECLARE v_tp       INT DEFAULT 0;
    DECLARE v_fp       INT DEFAULT 0;
    DECLARE v_fn       INT DEFAULT 0;
    DECLARE v_prec     DECIMAL(5,4) DEFAULT 0;
    DECLARE v_recall   DECIMAL(5,4) DEFAULT 0;
    DECLARE v_f1       DECIMAL(5,4) DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        RETURN 0.0000;    -- return 0 on any DB error
    END;

    -- Gather confusion matrix values
    SELECT 
        SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN mp.predicted_class = 1 AND fl.is_fraud = 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN mp.predicted_class = 0 AND fl.is_fraud = 1 THEN 1 ELSE 0 END)
    INTO v_tp, v_fp, v_fn
    FROM ML_PREDICTION mp
    JOIN FRAUD_LABEL fl ON mp.transaction_id = fl.transaction_id
    WHERE mp.model_id = p_model_id;

    -- Compute precision and recall with zero-division guard
    IF (v_tp + v_fp) > 0 THEN
        SET v_prec   = v_tp / (v_tp + v_fp);
    END IF;

    IF (v_tp + v_fn) > 0 THEN
        SET v_recall = v_tp / (v_tp + v_fn);
    END IF;

    -- Compute F1
    IF (v_prec + v_recall) > 0 THEN
        SET v_f1 = (2 * v_prec * v_recall) / (v_prec + v_recall);
    END IF;

    RETURN ROUND(v_f1, 4);
END //
DELIMITER ;

-- Usage Example
SELECT model_id, model_name, version, fn_model_f1_score(model_id) AS f1_score
FROM MODEL_METADATA
ORDER BY f1_score DESC;


-- ============================================================================
-- SECTION B: TRIGGERS
-- ============================================================================

-- -----------------------------------------------------------------------
-- T1. BEFORE INSERT on TRANSACTION
-- Validates that the amount is non-negative before allowing the insert.
-- Raises a custom application error if validation fails.
-- -----------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_transaction_insert;
DELIMITER //
CREATE TRIGGER trg_before_transaction_insert
BEFORE INSERT ON TRANSACTION
FOR EACH ROW
BEGIN
    -- Exception: prevent negative amounts
    IF NEW.amount < 0 THEN
        SIGNAL SQLSTATE '45001'
        SET MESSAGE_TEXT = 'TRANSACTION INSERT rejected: amount cannot be negative.';
    END IF;

    -- Clamp extremely small positive amounts to 0.01
    IF NEW.amount > 0 AND NEW.amount < 0.01 THEN
        SET NEW.amount = 0.01;
    END IF;
END //
DELIMITER ;


-- -----------------------------------------------------------------------
-- T2. AFTER INSERT on TRANSACTION
-- Writes an audit record every time a new transaction is inserted.
-- -----------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_transaction_insert;
DELIMITER //
CREATE TRIGGER trg_after_transaction_insert
AFTER INSERT ON TRANSACTION
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, details)
    VALUES (
        'TRANSACTION',
        'INSERT',
        NEW.transaction_id,
        CONCAT('customer_id=', NEW.customer_id,
               ' | amount=',    NEW.amount,
               ' | time=',      NEW.time)
    );
END //
DELIMITER ;


-- -----------------------------------------------------------------------
-- T3. AFTER UPDATE on CUSTOMER
-- When a customer's risk_score increases past 0.5, auto-create a
-- HIGH_RISK alert for their most recent transaction.
-- -----------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_customer_risk_update;
DELIMITER //
CREATE TRIGGER trg_after_customer_risk_update
AFTER UPDATE ON CUSTOMER
FOR EACH ROW
BEGIN
    DECLARE v_latest_txn_id INT DEFAULT NULL;

    -- Only act when risk_score crosses the 0.50 threshold upward
    IF OLD.risk_score <= 0.50 AND NEW.risk_score > 0.50 THEN

        -- Find the most recent transaction for this customer
        SELECT transaction_id INTO v_latest_txn_id
        FROM TRANSACTION
        WHERE customer_id = NEW.customer_id
        ORDER BY time DESC
        LIMIT 1;

        -- Insert a HIGH_RISK alert (silently ignore if already exists)
        IF v_latest_txn_id IS NOT NULL THEN
            INSERT IGNORE INTO fraud_alert_log
                (transaction_id, alert_type, severity, alert_message)
            VALUES (
                v_latest_txn_id,
                'HIGH_RISK_CUSTOMER',
                4,
                CONCAT('Customer ', NEW.customer_id,
                       ' risk score crossed 0.50 threshold: new score = ', NEW.risk_score)
            );
        END IF;
    END IF;
END //
DELIMITER ;


-- -----------------------------------------------------------------------
-- T4. BEFORE DELETE on CUSTOMER
-- Prevents deletion of customers who still have unresolved fraud alerts.
-- -----------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_customer_delete;
DELIMITER //
CREATE TRIGGER trg_before_customer_delete
BEFORE DELETE ON CUSTOMER
FOR EACH ROW
BEGIN
    DECLARE v_open_alerts INT DEFAULT 0;

    SELECT COUNT(*) INTO v_open_alerts
    FROM fraud_alert_log fal
    JOIN TRANSACTION t ON fal.transaction_id = t.transaction_id
    WHERE t.customer_id = OLD.customer_id
      AND fal.resolved  = FALSE;

    IF v_open_alerts > 0 THEN
        SIGNAL SQLSTATE '45002'
        SET MESSAGE_TEXT = 'CUSTOMER DELETE rejected: customer has unresolved fraud alerts.';
    END IF;

    -- Audit the deletion attempt
    INSERT INTO audit_log (table_name, operation, record_id, details)
    VALUES (
        'CUSTOMER',
        'DELETE',
        OLD.customer_id,
        CONCAT('risk_score=', OLD.risk_score,
               ' | total_transactions=', OLD.total_transactions)
    );
END //
DELIMITER ;


-- ============================================================================
-- SECTION C: CURSORS WITH EXCEPTION HANDLING
-- ============================================================================

-- -----------------------------------------------------------------------
-- C1. sp_bulk_classify_customers
-- Iterates over ALL customers using a cursor, computes each customer's
-- risk tier using fn_classify_risk_tier(), then logs a summary.
-- Demonstrates: DECLARE CURSOR, OPEN, FETCH, CLOSE, NOT FOUND handler.
-- -----------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_bulk_classify_customers;
DELIMITER //
CREATE PROCEDURE sp_bulk_classify_customers(
    OUT p_processed_count INT,
    OUT p_error_count     INT
)
BEGIN
    -- ---- Variable declarations ----
    DECLARE v_customer_id  INT;
    DECLARE v_risk_score   DOUBLE;
    DECLARE v_risk_tier    VARCHAR(20);
    DECLARE v_done         BOOLEAN DEFAULT FALSE;

    -- ---- Exception state variables ----
    DECLARE v_sql_err_msg  TEXT DEFAULT '';
    DECLARE v_sql_errcode  INT  DEFAULT 0;

    -- ---- Declare cursor ----
    DECLARE cur_customers CURSOR FOR
        SELECT customer_id, risk_score
        FROM CUSTOMER
        ORDER BY customer_id;

    -- ---- Handlers ----
    -- NOT FOUND: raised when cursor runs out of rows; sets exit flag
    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_done = TRUE;
    END;

    -- SQLEXCEPTION: catch any unexpected DB error per-row
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sql_errcode = MYSQL_ERRNO,
            v_sql_err_msg = MESSAGE_TEXT;
        SET p_error_count = p_error_count + 1;
        -- Log the error to audit_log and continue to next row
        INSERT INTO audit_log (table_name, operation, record_id, details)
        VALUES ('CUSTOMER', 'UPDATE',
                v_customer_id,
                CONCAT('Cursor error [', v_sql_errcode, ']: ', v_sql_err_msg));
    END;

    -- Initialize counters
    SET p_processed_count = 0;
    SET p_error_count     = 0;

    -- ---- Open cursor ----
    OPEN cur_customers;

    -- ---- Fetch loop ----
    fetch_loop: LOOP
        FETCH cur_customers INTO v_customer_id, v_risk_score;

        -- Exit loop when no more rows
        IF v_done THEN
            LEAVE fetch_loop;
        END IF;

        -- Classify this customer
        SET v_risk_tier = fn_classify_risk_tier(v_risk_score);

        -- Update the customer with the derived tier via a comment in notes column
        -- (storing tier in audit_log as CUSTOMER table has no free-text tier column)
        INSERT INTO audit_log (table_name, operation, record_id, details)
        VALUES (
            'CUSTOMER',
            'UPDATE',
            v_customer_id,
            CONCAT('risk_tier=', v_risk_tier, ' | risk_score=', v_risk_score)
        );

        SET p_processed_count = p_processed_count + 1;
    END LOOP fetch_loop;

    -- ---- Close cursor ----
    CLOSE cur_customers;

END //
DELIMITER ;

-- Call the procedure and check results
CALL sp_bulk_classify_customers(@processed, @errors);
SELECT @processed AS customers_processed, @errors AS rows_with_errors;


-- -----------------------------------------------------------------------
-- C2. sp_generate_fraud_report
-- Cursor-driven procedure: iterates over high-risk customers (risk > 0.3),
-- creates a fraud_alert_log entry for each, then returns a summary report.
-- -----------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_generate_fraud_report;
DELIMITER //
CREATE PROCEDURE sp_generate_fraud_report(
    IN  p_risk_threshold  DOUBLE,
    OUT p_alerts_created  INT
)
BEGIN
    DECLARE v_customer_id    INT;
    DECLARE v_risk_score     DOUBLE;
    DECLARE v_latest_txn_id  INT;
    DECLARE v_done           BOOLEAN DEFAULT FALSE;

    -- Declare cursor for high-risk customers
    DECLARE cur_high_risk CURSOR FOR
        SELECT customer_id, risk_score
        FROM   CUSTOMER
        WHERE  risk_score > p_risk_threshold
        ORDER  BY risk_score DESC;

    -- NOT FOUND handler to terminate the fetch loop
    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET v_done = TRUE;
    END;

    -- Generic exception handler: log and continue
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        INSERT INTO audit_log (table_name, operation, record_id, details)
        VALUES ('fraud_alert_log', 'INSERT', v_customer_id,
                'sp_generate_fraud_report: exception during alert creation');
    END;

    SET p_alerts_created = 0;

    OPEN cur_high_risk;

    report_loop: LOOP
        FETCH cur_high_risk INTO v_customer_id, v_risk_score;

        IF v_done THEN
            LEAVE report_loop;
        END IF;

        -- Find the most recent transaction for this customer
        SELECT transaction_id INTO v_latest_txn_id
        FROM TRANSACTION
        WHERE customer_id = v_customer_id
        ORDER BY time DESC
        LIMIT 1;

        -- Skip if no transactions exist
        IF v_latest_txn_id IS NULL THEN
            ITERATE report_loop;
        END IF;

        -- Create a report alert (ignore if already exists)
        INSERT IGNORE INTO fraud_alert_log
            (transaction_id, alert_type, severity, alert_message)
        VALUES (
            v_latest_txn_id,
            'PERIODIC_REPORT',
            CASE
                WHEN v_risk_score >= 0.75 THEN 5
                WHEN v_risk_score >= 0.50 THEN 4
                ELSE 3
            END,
            CONCAT('Periodic report: customer ', v_customer_id,
                   ' risk_score = ', v_risk_score,
                   ' [tier: ', fn_classify_risk_tier(v_risk_score), ']')
        );

        SET p_alerts_created = p_alerts_created + 1;

    END LOOP report_loop;

    CLOSE cur_high_risk;

    -- Final selection to display created alerts
    SELECT 
        fal.alert_id,
        fal.transaction_id,
        t.customer_id,
        fal.severity,
        fal.alert_message,
        fal.created_at
    FROM fraud_alert_log fal
    JOIN TRANSACTION t ON fal.transaction_id = t.transaction_id
    WHERE fal.alert_type  = 'PERIODIC_REPORT'
      AND fal.resolved    = FALSE
    ORDER BY fal.severity DESC, fal.created_at DESC;

END //
DELIMITER ;

-- Run the report for customers with risk_score > 0.30
CALL sp_generate_fraud_report(0.30, @alerts_created);
SELECT @alerts_created AS total_alerts_generated;


-- ============================================================================
-- SECTION D: EXCEPTION HANDLING — STANDALONE EXAMPLES
-- ============================================================================

-- -----------------------------------------------------------------------
-- D1. sp_safe_transaction_delete
-- Attempts to delete a transaction; uses EXIT handler + SIGNAL to provide
-- a meaningful message if the transaction has open alerts.
-- -----------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_safe_transaction_delete;
DELIMITER //
CREATE PROCEDURE sp_safe_transaction_delete(IN p_transaction_id INT)
BEGIN
    DECLARE v_open_alerts INT DEFAULT 0;
    DECLARE v_exists      INT DEFAULT 0;

    -- EXIT handler: rolls back and re-raises the error message
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Check if the transaction exists
    SELECT COUNT(*) INTO v_exists
    FROM TRANSACTION WHERE transaction_id = p_transaction_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45003'
        SET MESSAGE_TEXT = 'TRANSACTION DELETE failed: record not found.';
    END IF;

    -- Check for open alerts
    SELECT COUNT(*) INTO v_open_alerts
    FROM fraud_alert_log
    WHERE transaction_id = p_transaction_id AND resolved = FALSE;

    IF v_open_alerts > 0 THEN
        SIGNAL SQLSTATE '45004'
        SET MESSAGE_TEXT = 'TRANSACTION DELETE rejected: unresolved fraud alerts exist.';
    END IF;

    -- Safe to delete
    DELETE FROM TRANSACTION WHERE transaction_id = p_transaction_id;

    COMMIT;
    SELECT CONCAT('Transaction ', p_transaction_id, ' deleted successfully.') AS result;

END //
DELIMITER ;


-- -----------------------------------------------------------------------
-- D2. sp_activate_model
-- Activates a given model and deactivates all others.
-- Uses DECLARE HANDLER for NOT FOUND and SQLEXCEPTION.
-- -----------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_activate_model;
DELIMITER //
CREATE PROCEDURE sp_activate_model(
    IN  p_model_id INT,
    OUT p_status   VARCHAR(200)
)
BEGIN
    DECLARE v_model_exists INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SET p_status = CONCAT('ERROR: Model ID ', p_model_id, ' not found.');
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR: An unexpected database error occurred. Transaction rolled back.';
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Verify model exists
    SELECT COUNT(*) INTO v_model_exists
    FROM MODEL_METADATA WHERE model_id = p_model_id;

    IF v_model_exists = 0 THEN
        ROLLBACK;
        SET p_status = CONCAT('ERROR: No model found with model_id = ', p_model_id, '.');
        SIGNAL SQLSTATE '45005'
        SET MESSAGE_TEXT = 'Model ID does not exist in MODEL_METADATA.';
    END IF;

    -- Deactivate all other models
    UPDATE MODEL_METADATA
    SET is_active = FALSE
    WHERE model_id != p_model_id;

    -- Activate the requested model
    UPDATE MODEL_METADATA
    SET is_active = TRUE
    WHERE model_id = p_model_id;

    COMMIT;

    SET p_status = CONCAT('SUCCESS: Model ID ', p_model_id, ' is now active.');
END //
DELIMITER ;

-- Activate model 1 (adjust model_id as needed)
CALL sp_activate_model(1, @model_status);
SELECT @model_status AS activation_result;

-- ============================================================================
-- SECTION E: VERIFICATION QUERIES
-- ============================================================================

-- E1. Show all functions created
SHOW FUNCTION STATUS WHERE Db = 'fraud_db';

-- E2. Show all triggers created  
SHOW TRIGGERS FROM fraud_db;

-- E3. Show all procedures created
SHOW PROCEDURE STATUS WHERE Db = 'fraud_db';

-- E4. Audit log overview
SELECT 
    operation,
    table_name,
    COUNT(*) AS event_count,
    MIN(event_time) AS first_event,
    MAX(event_time) AS last_event
FROM audit_log
GROUP BY operation, table_name
ORDER BY event_count DESC;

-- ============================================================================
-- END OF TASK 3
-- ============================================================================
