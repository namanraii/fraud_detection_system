-- ============================================================================
-- SQL Helper for Generating Screenshots for Chapter 4
-- Run these queries individually in MySQL Workbench and take screenshots of the results
-- ============================================================================
USE fraud_db;

-- ----------------------------------------------------------------------------
-- 4.2 First Normal Form (1NF)
-- ----------------------------------------------------------------------------
-- BEFORE Normalization (UNF) - Showing multi-valued attributes
SELECT 
    1001 AS transaction_id, 
    472 AS time, 
    529.00 AS amount, 
    '-3.043540, 1.088462, 2.288643' AS pca_values;

-- AFTER Normalization (1NF) - Atomic attributes in separate rows
SELECT 
    1001 AS transaction_id, 
    'V1' AS feature_name, 
    -3.043540 AS feature_value
UNION ALL
SELECT 1001, 'V2', 1.088462
UNION ALL
SELECT 1001, 'V3', 2.288643;

-- ----------------------------------------------------------------------------
-- 4.3 Second Normal Form (2NF)
-- ----------------------------------------------------------------------------
-- BEFORE Normalization (1NF Table w/ Partial Dependency)
SELECT 
    1001 AS transaction_id, 
    1 AS model_id, 
    'RandomForest' AS model_name, 
    1 AS predicted_class
UNION ALL
SELECT 1002, 1, 'RandomForest', 0;


-- AFTER Normalization (2NF Tables)
-- (Screenshot 1: ML_PREDICTION)
SELECT transaction_id, model_id, predicted_class 
FROM ML_PREDICTION LIMIT 2;

-- (Screenshot 2: MODEL_METADATA)
SELECT model_id, model_name 
FROM MODEL_METADATA LIMIT 1;


-- ----------------------------------------------------------------------------
-- 4.4 Third Normal Form (3NF)
-- ----------------------------------------------------------------------------
-- BEFORE Normalization (2NF Table w/ Transitive Dependency)
SELECT 
    t.transaction_id, 
    t.customer_id, 
    t.amount, 
    c.risk_score
FROM TRANSACTION t
JOIN CUSTOMER c ON t.customer_id = c.customer_id
LIMIT 2;

-- AFTER Normalization (3NF Tables)
-- (Screenshot 1: TRANSACTION Fact Table)
SELECT transaction_id, customer_id, amount 
FROM TRANSACTION LIMIT 2;

-- (Screenshot 2: CUSTOMER Dimension Table)
SELECT customer_id, risk_score 
FROM CUSTOMER LIMIT 2;


-- ----------------------------------------------------------------------------
-- 4.6 Fourth Normal Form (4NF)
-- ----------------------------------------------------------------------------
-- BEFORE Normalization (BCNF Table w/ Multivalued Dependencies)
SELECT 55 AS customer_id, '1111-2222-3333-4444' AS credit_card_number, 'Downtown Branch' AS branch_name
UNION ALL
SELECT 55, '5555-6666-7777-8888', 'Downtown Branch'
UNION ALL
SELECT 55, '1111-2222-3333-4444', 'Midtown Branch'
UNION ALL
SELECT 55, '5555-6666-7777-8888', 'Midtown Branch';


-- AFTER Normalization (4NF Tables)
-- (Screenshot 1: CUSTOMER_CARD)
SELECT 55 AS customer_id, '1111-2222-3333-4444' AS credit_card_number
UNION ALL
SELECT 55, '5555-6666-7777-8888';

-- (Screenshot 2: CUSTOMER_BRANCH)
SELECT 55 AS customer_id, 'Downtown Branch' AS branch_name
UNION ALL
SELECT 55, 'Midtown Branch';

-- ----------------------------------------------------------------------------
-- 4.7 Fifth Normal Form (5NF)
-- ----------------------------------------------------------------------------
-- BEFORE Normalization (4NF w/ Join Dependency)
SELECT 'John Doe' AS investigator_name, 'Downtown Branch' AS branch_name, 'Identity Theft' AS fraud_category;

-- AFTER Normalization (5NF Tables)
-- (Screenshot 1)
SELECT 'John Doe' AS investigator_name, 'Downtown Branch' AS branch_name;
-- (Screenshot 2)
SELECT 'Downtown Branch' AS branch_name, 'Identity Theft' AS fraud_category;
-- (Screenshot 3)
SELECT 'John Doe' AS investigator_name, 'Identity Theft' AS fraud_category;

