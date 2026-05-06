-- ============================================================================
-- Financial Fraud Detection System - Chapter 3 Demo
-- Complex Queries: Constraints, Sets, Joins, Views, Triggers and Cursors
-- ============================================================================

-- Setup: Using the fraud_db database
CREATE DATABASE IF NOT EXISTS fraud_db;
USE fraud_db;

-- Ensuring tables exist for the demo (Simplified versions for standalone demo)
CREATE TABLE IF NOT EXISTS CUSTOMER (
    customer_id INT PRIMARY KEY, 
    total_transactions INT DEFAULT 0,
    total_fraud_count INT DEFAULT 0,
    risk_score DECIMAL(5,4) DEFAULT 0.0000
);

CREATE TABLE IF NOT EXISTS TRANSACTION (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10,2),
    time INT,
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id)
);

CREATE TABLE IF NOT EXISTS FRAUD_LABEL (
    label_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT,
    is_fraud BOOLEAN,
    FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id)
);

CREATE TABLE IF NOT EXISTS MODEL_METADATA (
    model_id INT PRIMARY KEY,
    model_name VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS ML_PREDICTION (
    prediction_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT,
    model_id INT,
    predicted_class VARCHAR(20),
    probability_score DECIMAL(5,4),
    FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id),
    FOREIGN KEY (model_id) REFERENCES MODEL_METADATA(model_id)
);

CREATE TABLE IF NOT EXISTS prediction_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    prediction_id INT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inserting Sample Data for Demo
INSERT IGNORE INTO CUSTOMER (customer_id, total_transactions, total_fraud_count, risk_score) VALUES
(1, 15, 2, 0.1333),
(2, 5, 0, 0.0000),
(3, 12, 1, 0.0833),
(4, 8, 3, 0.3750);

INSERT IGNORE INTO TRANSACTION (transaction_id, customer_id, amount, time) VALUES
(1, 1, 1200.50, 100),
(2, 2, 50.00, 200),
(3, 3, 3000.00, 300),
(4, 4, 150.00, 400),
(5, 1, 200.00, 500);

INSERT IGNORE INTO FRAUD_LABEL (transaction_id, is_fraud) VALUES
(1, 1),
(3, 1),
(4, 0);

INSERT IGNORE INTO MODEL_METADATA (model_id, model_name) VALUES
(1, 'RandomForest'),
(2, 'LogisticRegression');

INSERT IGNORE INTO ML_PREDICTION (transaction_id, model_id, predicted_class, probability_score) VALUES
(1, 1, 'Fraud', 0.95),
(2, 1, 'Legit', 0.05),
(3, 1, 'Fraud', 0.88),
(4, 2, 'Fraud', 0.72); 

-- ============================================================================
-- 3.1 Constraints
-- ============================================================================

-- Q1: Retrieve transactions where the transaction amount is greater than 1000
SELECT transaction_id, amount FROM TRANSACTION WHERE amount > 1000;

-- Q2: Find customers whose fraud count is greater than zero
SELECT customer_id, total_fraud_count FROM CUSTOMER WHERE total_fraud_count > 0;

-- Q3: Find customers whose total transactions exceed 10
SELECT customer_id, total_transactions FROM CUSTOMER WHERE total_transactions > 10;

-- ============================================================================
-- 3.2 Aggregate Functions
-- ============================================================================

-- Q1: Find total number of transactions performed by each customer
SELECT customer_id, COUNT(transaction_id) FROM TRANSACTION GROUP BY customer_id;

-- Q2: Find average transaction amount
SELECT AVG(amount) FROM TRANSACTION;

-- Q3: Find maximum transaction amount
SELECT MAX(amount) FROM TRANSACTION;

-- ============================================================================
-- 3.3 Set Operations
-- ============================================================================

-- Q1: Find transactions that are either confirmed fraud or predicted fraud
SELECT transaction_id FROM FRAUD_LABEL WHERE is_fraud=1
UNION
SELECT transaction_id FROM ML_PREDICTION WHERE predicted_class='Fraud';

-- Q2: Find predicted fraud transactions not yet confirmed (Simulated EXCEPT)
SELECT transaction_id FROM ML_PREDICTION WHERE predicted_class='Fraud'
AND transaction_id NOT IN (SELECT transaction_id FROM FRAUD_LABEL WHERE is_fraud=1);

-- Q3: Find transactions both predicted and confirmed fraud (Simulated INTERSECT)
SELECT transaction_id FROM ML_PREDICTION WHERE predicted_class='Fraud'
AND transaction_id IN (SELECT transaction_id FROM FRAUD_LABEL WHERE is_fraud=1);

-- ============================================================================
-- 3.4 Subqueries
-- ============================================================================

-- Q1: Retrieve transactions above the average transaction value
SELECT transaction_id, amount FROM TRANSACTION
WHERE amount > (SELECT AVG(amount) FROM TRANSACTION);

-- Q2: Find customer with highest fraud count
SELECT customer_id FROM CUSTOMER
WHERE total_fraud_count = (SELECT MAX(total_fraud_count) FROM CUSTOMER);

-- Q3: Retrieve transactions greater than minimum amount
SELECT transaction_id, amount FROM TRANSACTION
WHERE amount > (SELECT MIN(amount) FROM TRANSACTION);

-- ============================================================================
-- 3.5 Joins
-- ============================================================================

-- Q1: Retrieve transaction details along with fraud label
SELECT t.transaction_id, t.amount, f.is_fraud
FROM TRANSACTION t JOIN FRAUD_LABEL f
ON t.transaction_id = f.transaction_id;

-- Q2: Retrieve predictions with model name
SELECT m.model_name, p.predicted_class
FROM ML_PREDICTION p JOIN MODEL_METADATA m
ON p.model_id = m.model_id;

-- Q3: Retrieve customers and their transactions
SELECT c.customer_id, t.transaction_id
FROM CUSTOMER c JOIN TRANSACTION t
ON c.customer_id = t.customer_id;

-- ============================================================================
-- 3.6 Views
-- ============================================================================

-- Q1: Create a view for fraud transactions
CREATE OR REPLACE VIEW fraud_transactions AS
SELECT t.transaction_id, t.amount
FROM TRANSACTION t JOIN FRAUD_LABEL f
ON t.transaction_id = f.transaction_id
WHERE f.is_fraud = 1;

-- Q2: Retrieve all records from the fraud view
SELECT * FROM fraud_transactions;

-- Q3: Count fraud transactions using the view
SELECT COUNT(*) FROM fraud_transactions;

-- ============================================================================
-- 3.7 Triggers
-- ============================================================================

-- Q1: Create trigger to update fraud count after fraud insertion
DROP TRIGGER IF EXISTS trg_update_fraud_count;
DELIMITER //
CREATE TRIGGER trg_update_fraud_count
AFTER INSERT ON FRAUD_LABEL
FOR EACH ROW
BEGIN
    IF NEW.is_fraud = 1 THEN
        UPDATE CUSTOMER SET total_fraud_count = total_fraud_count + 1
        WHERE customer_id = (SELECT customer_id FROM TRANSACTION WHERE transaction_id = NEW.transaction_id);
    END IF;
END //
DELIMITER ;

-- Q2: Create trigger to ensure transaction amount is positive
DROP TRIGGER IF EXISTS validate_amount;
CREATE TRIGGER validate_amount
BEFORE INSERT ON TRANSACTION
FOR EACH ROW SET NEW.amount = ABS(NEW.amount);

-- Q3: Create trigger to log prediction entries
DROP TRIGGER IF EXISTS log_prediction;
CREATE TRIGGER log_prediction
AFTER INSERT ON ML_PREDICTION
FOR EACH ROW INSERT INTO prediction_log (prediction_id) VALUES(NEW.prediction_id);

-- ============================================================================
-- 3.8 Cursors
-- ============================================================================

-- Demo Procedure for Cursor handling (as cursors are usually inside procedures/functions)
DROP PROCEDURE IF EXISTS demo_fraud_cursor;
DELIMITER //
CREATE PROCEDURE demo_fraud_cursor()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE txn_id INT;
    -- Q1: Declare cursor for fraud transactions
    DECLARE fraud_cursor CURSOR FOR SELECT transaction_id FROM FRAUD_LABEL WHERE is_fraud=1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Q2: Fetch cursor records
    OPEN fraud_cursor;
    
    read_loop: LOOP
        FETCH fraud_cursor INTO txn_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        -- (Optional: Perform processing on txn_id here)
        SELECT CONCAT('Processing Fraud Transaction: ', txn_id) AS Status;
    END LOOP;

    -- Q3: Close the cursor
    CLOSE fraud_cursor;
END //
DELIMITER ;

-- Execute Cursor Demo Procedure
CALL demo_fraud_cursor();
