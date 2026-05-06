-- ============================================================================
-- ACID Properties Proof (Review 3 Requirement)
-- Purpose: Explicitly demonstrates Atomicity, Consistency, Isolation, Durability
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- 1. ATOMICITY
-- "All or nothing" - A failed transaction rolls back all intermediate operations.
-- ============================================================================

-- Scenario A: Successful Atomicity (COMMIT)
START TRANSACTION;
    -- Step 1: Insert mock transaction
    INSERT INTO TRANSACTION (transaction_id, customer_id, time, amount) 
    VALUES (9999991, 1, 1000, 50.00);
    
    -- Step 2: Insert related fraud label
    INSERT INTO FRAUD_LABEL (transaction_id, is_fraud) 
    VALUES (9999991, 0);
COMMIT;
-- Proof: Both queries were successful.
SELECT * FROM TRANSACTION WHERE transaction_id = 9999991;
SELECT * FROM FRAUD_LABEL WHERE transaction_id = 9999991;

-- Scenario B: Failed Atomicity (ROLLBACK)
START TRANSACTION;
    -- Step 1: Insert mock transaction
    INSERT INTO TRANSACTION (transaction_id, customer_id, time, amount) 
    VALUES (9999992, 1, 1005, 75.00);
    
    -- Simulate an application error before step 2 happens
    -- We rollback the transaction intentionally
ROLLBACK;
-- Proof: The first insert was wiped out because the transaction was not committed.
SELECT * FROM TRANSACTION WHERE transaction_id = 9999992; -- Will return EMPTY.


-- ============================================================================
-- 2. CONSISTENCY
-- "Rule abiding" - A transaction can only bring the DB from one valid state to another.
-- ============================================================================

START TRANSACTION;
    -- Attempting to violate a Foreign Key Constraint
    -- We try to insert a fraud label for a transaction_id (9999993) that DOES NOT exist in TRANSACTION table
    -- This will force MySQL to throw error 1452 (Cannot add or update a child row: a foreign key constraint fails)
    
    -- Uncomment below to see the error thrown and transaction halted
    -- INSERT INTO FRAUD_LABEL (transaction_id, is_fraud) VALUES (9999993, 1);
    
    -- Look at the Check Constraint violation on ML_PREDICTION
    -- Probability score is strictly defined as DECIMAL(5,4), any attempt to insert string will fail formatting consistency
    -- INSERT INTO ML_PREDICTION (transaction_id, model_id, predicted_class, probability_score) VALUES (1, 1, 'UNKNOWN_BOOLEAN', 0.99);
ROLLBACK;


-- ============================================================================
-- 3. ISOLATION
-- "Invisible to others" - Concurrent transactions do not affect each other.
-- ============================================================================

-- Set the isolation level to demonstrate strict isolation behavior
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;
    -- Session A updates a customer risk score but doesn't commit yet
    UPDATE CUSTOMER SET risk_score = 99.99 WHERE customer_id = 1;
    
    -- At this EXACT moment, if you opened a second terminal/session (Session B) and ran:
    -- SELECT risk_score FROM CUSTOMER WHERE customer_id = 1;
    -- Session B would STILL see the old value (e.g. 0.00). 
    -- Session B is ISOLATED from the uncommitted changes of Session A.
    
COMMIT;
-- NOW Session B would see the new 99.99 value.

-- (Reset data for cleanliness)
UPDATE CUSTOMER SET risk_score = 0.00 WHERE customer_id = 1;


-- ============================================================================
-- 4. DURABILITY
-- "Saved forever" - Once completely committed, it survives system failure.
-- ============================================================================

START TRANSACTION;
    INSERT INTO TRANSACTION (transaction_id, customer_id, time, amount) 
    VALUES (9999994, 1, 2000, 1500.00);
COMMIT;
-- Because of COMMIT, the MySQL transaction log writes this change to disk permanently (redo log).
-- Even if the server loses power 1 ms from now, row 9999994 is 100% durable and will exist on reboot.

-- Cleanup demo data
DELETE FROM FRAUD_LABEL WHERE transaction_id IN (9999991);
DELETE FROM TRANSACTION WHERE transaction_id IN (9999991, 9999994);
