-- ============================================================================
-- Chapter 5 Transactions and Concurrency Implementations
-- Purpose: 5 Explicit TCL Transactions and Concurrency Proofs
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- TRANSACTION 1: Inserting a Transaction and its Label
-- ============================================================================
-- Step 1: Start transaction by inserting a raw transaction record
START TRANSACTION;
INSERT INTO TRANSACTION (transaction_id, customer_id, time, amount) 
VALUES (9901, 10, 500, 150.00);

-- Step 2: Set a savepoint after the safe insertion
SAVEPOINT after_transaction_insert;
SELECT transaction_id, customer_id, amount FROM TRANSACTION WHERE transaction_id = 9901;

-- Step 3: Attempt to insert a feature associated with a different transaction ID by mistake
INSERT INTO TRANSACTION_FEATURES (transaction_id, feature_name, feature_value) 
VALUES (9902, 'V1', 1.05);

-- Step 4: Oops! The transaction ID was wrong, rollback the erroneous feature insertion
ROLLBACK TO after_transaction_insert;
SELECT * FROM TRANSACTION_FEATURES WHERE transaction_id = 9902;

-- Step 5: Continue with a safe insertion of the correct Fraud Label
INSERT INTO FRAUD_LABEL (transaction_id, is_fraud) 
VALUES (9901, 0);

-- Step 6: Commit the initial transaction and the correct label
COMMIT;
SELECT transaction_id, is_fraud FROM FRAUD_LABEL WHERE transaction_id = 9901;


-- ============================================================================
-- TRANSACTION 2: Safely Updating Customer Risk Scoring
-- ============================================================================
-- Step 1: Start transaction by updating a customer's risk score based on mild activity
START TRANSACTION;
UPDATE CUSTOMER SET risk_score = 0.50 WHERE customer_id = 10;

-- Step 2: Set a savepoint denoting the mild risk update
SAVEPOINT after_mild_risk;
SELECT customer_id, risk_score FROM CUSTOMER WHERE customer_id = 10;

-- Step 3: Reviewer flags an extreme potential fraud, escalating risk score to maximum
UPDATE CUSTOMER SET risk_score = 0.99 WHERE customer_id = 10;
SELECT customer_id, risk_score FROM CUSTOMER WHERE customer_id = 10;

-- Step 4: The escalation is rejected by an automated compliance check, rollback to mild risk
ROLLBACK TO after_mild_risk;
SELECT customer_id, risk_score FROM CUSTOMER WHERE customer_id = 10;

-- Step 5: Continue instead with a moderate and approved risk adjustment
UPDATE CUSTOMER SET risk_score = 0.65 WHERE customer_id = 10;

-- Step 6: Commit all legitimate changes since the savepoint
COMMIT;
SELECT customer_id, risk_score FROM CUSTOMER WHERE customer_id = 10;


-- ============================================================================
-- TRANSACTION 3: Processing Heavy ML Predictions
-- ============================================================================
-- Step 1: Start transaction by inserting a new algorithmic prediction
START TRANSACTION;
INSERT INTO ML_PREDICTION (transaction_id, model_id, predicted_class, probability_score)
VALUES (305, 1, 1, 0.98);

-- Step 2: Set a savepoint after successfully logging the prediction
SAVEPOINT pred_logged;
SELECT transaction_id, probability_score FROM ML_PREDICTION WHERE transaction_id = 305;

-- Step 3: Attempt an unauthorized modification to zero out the transaction amount
UPDATE TRANSACTION SET amount = 0 WHERE transaction_id = 305; 
SELECT transaction_id, amount FROM TRANSACTION WHERE transaction_id = 305;

-- Step 4: System audit detects tampering with historical balances, rollback to safe prediction state
ROLLBACK TO pred_logged;
SELECT transaction_id, amount FROM TRANSACTION WHERE transaction_id = 305;

-- Step 5: Read just the probability score slightly based on a secondary model check
UPDATE ML_PREDICTION SET probability_score = 0.95 WHERE transaction_id = 305;

-- Step 6: Commit the final validated prediction
COMMIT;


-- ============================================================================
-- TRANSACTION 4: Model Version Control Rollout
-- ============================================================================
-- Step 1: Start transaction by deactivating the currently active but aging model
START TRANSACTION;
UPDATE MODEL_METADATA SET is_active = 0 WHERE model_id = 1;

-- Step 2: Set a savepoint after clearing the active model slate
SAVEPOINT old_deactivated;
SELECT model_id, is_active FROM MODEL_METADATA WHERE model_id = 1;

-- Step 3: Attempt to activate a hastily trained experimental model
UPDATE MODEL_METADATA SET is_active = 1 WHERE model_id = 99;
SELECT model_id, is_active FROM MODEL_METADATA WHERE model_id IN (1, 99);

-- Step 4: Experimental model fails health check constraints, rollback activation
ROLLBACK TO old_deactivated;
SELECT model_id, is_active FROM MODEL_METADATA WHERE model_id = 99;

-- Step 5: Proceed to activate the verified stable model version instead
UPDATE MODEL_METADATA SET is_active = 1 WHERE model_id = 2;

-- Step 6: Commit the safe model hot-swap
COMMIT;


-- ============================================================================
-- TRANSACTION 5: Deleting Fraudulent Records
-- ============================================================================
-- Step 1: Start transaction by clearing a disputed fraud label
START TRANSACTION;
DELETE FROM FRAUD_LABEL WHERE transaction_id = 412;

-- Step 2: Set a savepoint after clearing the label
SAVEPOINT label_cleared;
SELECT * FROM FRAUD_LABEL WHERE transaction_id = 412;

-- Step 3: Attempt to also delete the core transaction log
DELETE FROM TRANSACTION WHERE transaction_id = 412;
SELECT * FROM TRANSACTION WHERE transaction_id = 412;

-- Step 4: Violation! Compliance requires keeping raw transaction logs for 5 years, rollback
ROLLBACK TO label_cleared;
SELECT transaction_id FROM TRANSACTION WHERE transaction_id = 412;

-- Step 5: Instead of deleting, just update a cached customer fraud count to reflect the label removal
UPDATE CUSTOMER SET total_fraud_count = total_fraud_count - 1 WHERE customer_id = (SELECT customer_id FROM TRANSACTION WHERE transaction_id = 412);

-- Step 6: Commit the label deletion and count adjustment
COMMIT;


-- ============================================================================
-- CONCURRENCY CONTROL EXAMPLE (Exclusive Locking)
-- ============================================================================
-- Scenario: Analyst A is analyzing Transaction 1004. 
-- They issue an Exclusive Row Lock so nobody can touch or predict on it while they verify.

START TRANSACTION;

    SELECT predicted_class, probability_score 
    FROM ML_PREDICTION 
    WHERE transaction_id = 1004 
    FOR UPDATE; -- << EXCLUSIVE ROW LOCK IS APPLIED

    -- If a background task tries to issue an UPDATE on Transaction 1004, 
    -- it is forced to WAIT until Analyst A is done.
    
    UPDATE ML_PREDICTION 
    SET probability_score = 0.99, predicted_class = 1 
    WHERE transaction_id = 1004;

COMMIT; 
-- << EXCLUSIVE LOCK IS RELEASED
