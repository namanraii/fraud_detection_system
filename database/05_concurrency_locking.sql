-- ============================================================================
-- Concurrency Control & Locking Mechanisms (Review 3 Requirement)
-- Purpose: Demonstrates Table-level and Row-level locking (Shared/Exclusive)
-- ============================================================================

USE fraud_db;

-- ============================================================================
-- PART 1: ROW-LEVEL LOCKING (InnoDB Specific)
-- Use case: High-volume concurrency on specific resources
-- ============================================================================

-- ---------------------------------------------------------
-- Example A: Shared Lock (READ Lock)
-- Concept: We want to read a Model Metadata row and ensure no one deletes 
-- or amends it while we do our analysis. Other sessions CAN read it too.
-- ---------------------------------------------------------
START TRANSACTION;

    SELECT model_name, version, metrics 
    FROM MODEL_METADATA 
    WHERE model_id = 1 
    FOR SHARE; -- <--- SHARED ROW LOCK
    
    -- If Session B attempts to UPDATE model_id = 1, it will wait.
    -- If Session B attempts to SELECT it FOR SHARE, it will succeed instantly.
    
COMMIT; -- Releases the lock


-- ---------------------------------------------------------
-- Example B: Exclusive Lock (WRITE Lock)
-- Concept: We are evaluating a transaction and modifying its fraud prediction. 
-- NO OTHER SESSION should be allowed to read or modify this specific row until we finish.
-- ---------------------------------------------------------
START TRANSACTION;

    SELECT predicted_class, probability_score 
    FROM ML_PREDICTION 
    WHERE transaction_id = 100 
    FOR UPDATE; -- <--- EXCLUSIVE ROW LOCK

    -- Do business logic offline (e.g. recalculate fraud via Python)
    -- Then update the database
    
    UPDATE ML_PREDICTION 
    SET probability_score = 0.99, predicted_class = 1 
    WHERE transaction_id = 100;
    
    -- If Session B runs just a basic SELECT on transaction 100, it reads a snapshot.
    -- If Session B runs SELECT ... FOR SHARE or UPDATE, it is completely BLOCKED.

COMMIT; -- Releases the lock



-- ============================================================================
-- PART 2: TABLE-LEVEL LOCKING
-- Use case: Maintenance tasks, mass bulk updates, schema migrations
-- ============================================================================

-- ---------------------------------------------------------
-- Example C: Table READ Lock
-- Concept: We are generating an expansive statistical report across all customers.
-- We want to prevent ANY writes/inserts to the tables during the report generation 
-- so numbers don't change halfway through.
-- ---------------------------------------------------------

-- Lock both tables for READ access only
LOCK TABLES CUSTOMER READ, TRANSACTION READ;

    -- Valid action: Select query
    SELECT count(*), sum(amount) FROM TRANSACTION;
    
    -- Invalid action (Blocked): Attempting to insert a transaction. 
    -- Even this current session cannot insert!
    -- INSERT INTO CUSTOMER (risk_score) VALUES (0.50); -- Fails with "Table was locked with a READ lock"

-- Must explicitly release
UNLOCK TABLES;


-- ---------------------------------------------------------
-- Example D: Table WRITE Lock
-- Concept: We are doing a full rebuild of the Feature Summary tables via Python.
-- We do not want anyone to even READ the table while we rebuild it.
-- ---------------------------------------------------------

-- Lock table exclusively for the current session
LOCK TABLES transaction_feature_summary WRITE;

    -- Valid action: Mass delete or structural change
    -- DELETE FROM transaction_feature_summary WHERE transaction_id < 5000;
    
    -- Invalid action (Blocked): For any OTHER session
    -- ALL reads and writes from Session B will hang until Session A unlocks.

-- Release to world
UNLOCK TABLES;
