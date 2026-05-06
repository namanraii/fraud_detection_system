-- ============================================================================
-- Financial Fraud Detection System - Database Schema
-- 3NF Normalized Design for Credit Card Fraud Detection
-- ============================================================================

-- Drop existing database if exists (for clean setup)
DROP DATABASE IF EXISTS fraud_db;

-- Create database
CREATE DATABASE fraud_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE fraud_db;

-- ============================================================================
-- STAGING TABLE: Raw Transactions
-- Purpose: Initial landing zone for CSV data import
-- ============================================================================

CREATE TABLE raw_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    Time INT NOT NULL COMMENT 'Seconds elapsed between this transaction and first transaction',
    V1 DOUBLE COMMENT 'PCA component 1',
    V2 DOUBLE COMMENT 'PCA component 2',
    V3 DOUBLE COMMENT 'PCA component 3',
    V4 DOUBLE COMMENT 'PCA component 4',
    V5 DOUBLE COMMENT 'PCA component 5',
    V6 DOUBLE COMMENT 'PCA component 6',
    V7 DOUBLE COMMENT 'PCA component 7',
    V8 DOUBLE COMMENT 'PCA component 8',
    V9 DOUBLE COMMENT 'PCA component 9',
    V10 DOUBLE COMMENT 'PCA component 10',
    V11 DOUBLE COMMENT 'PCA component 11',
    V12 DOUBLE COMMENT 'PCA component 12',
    V13 DOUBLE COMMENT 'PCA component 13',
    V14 DOUBLE COMMENT 'PCA component 14',
    V15 DOUBLE COMMENT 'PCA component 15',
    V16 DOUBLE COMMENT 'PCA component 16',
    V17 DOUBLE COMMENT 'PCA component 17',
    V18 DOUBLE COMMENT 'PCA component 18',
    V19 DOUBLE COMMENT 'PCA component 19',
    V20 DOUBLE COMMENT 'PCA component 20',
    V21 DOUBLE COMMENT 'PCA component 21',
    V22 DOUBLE COMMENT 'PCA component 22',
    V23 DOUBLE COMMENT 'PCA component 23',
    V24 DOUBLE COMMENT 'PCA component 24',
    V25 DOUBLE COMMENT 'PCA component 25',
    V26 DOUBLE COMMENT 'PCA component 26',
    V27 DOUBLE COMMENT 'PCA component 27',
    V28 DOUBLE COMMENT 'PCA component 28',
    Amount DECIMAL(10,2) NOT NULL COMMENT 'Transaction amount',
    Class TINYINT NOT NULL COMMENT '1 = Fraud, 0 = Legitimate',
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Import timestamp'
) ENGINE=InnoDB COMMENT='Staging table for raw CSV data';

-- ============================================================================
-- NORMALIZED TABLES (3NF)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CUSTOMER Table
-- Purpose: Customer dimension (derived from transaction patterns)
-- Note: Original dataset has no customer ID, so we create synthetic customers
-- ----------------------------------------------------------------------------

CREATE TABLE CUSTOMER (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_transactions INT DEFAULT 0 COMMENT 'Cached transaction count',
    total_fraud_count INT DEFAULT 0 COMMENT 'Cached fraud count',
    risk_score DOUBLE DEFAULT 0.0000 COMMENT 'Calculated risk score (0-1)',
    last_transaction_time INT COMMENT 'Last transaction time in seconds',
    INDEX idx_risk_score (risk_score),
    INDEX idx_last_transaction (last_transaction_time)
) ENGINE=InnoDB COMMENT='Customer dimension table';

-- ----------------------------------------------------------------------------
-- TRANSACTION Table
-- Purpose: Core transaction facts
-- ----------------------------------------------------------------------------

CREATE TABLE TRANSACTION (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    time INT NOT NULL COMMENT 'Seconds elapsed from first transaction',
    amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id) ON DELETE CASCADE,
    INDEX idx_customer_time (customer_id, time),
    INDEX idx_amount (amount),
    INDEX idx_time (time)
) ENGINE=InnoDB COMMENT='Transaction facts table';

-- ----------------------------------------------------------------------------
-- TRANSACTION_FEATURES Table
-- Purpose: Store PCA features (V1-V28) in normalized form
-- Design: EAV pattern for flexibility
-- ----------------------------------------------------------------------------

CREATE TABLE TRANSACTION_FEATURES (
    feature_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL,
    feature_name VARCHAR(10) NOT NULL COMMENT 'V1 through V28',
    feature_value DOUBLE NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id) ON DELETE CASCADE,
    INDEX idx_transaction_feature (transaction_id, feature_name),
    UNIQUE KEY uk_transaction_feature (transaction_id, feature_name)
) ENGINE=InnoDB COMMENT='PCA features in normalized form';

-- ----------------------------------------------------------------------------
-- FRAUD_LABEL Table
-- Purpose: Fraud classification labels
-- ----------------------------------------------------------------------------

CREATE TABLE FRAUD_LABEL (
    label_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL UNIQUE,
    is_fraud BOOLEAN NOT NULL COMMENT 'TRUE = Fraud, FALSE = Legitimate',
    labeled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id) ON DELETE CASCADE,
    INDEX idx_fraud_flag (is_fraud)
) ENGINE=InnoDB COMMENT='Fraud labels for transactions';

-- ----------------------------------------------------------------------------
-- MODEL_METADATA Table
-- Purpose: Track ML model versions and performance
-- ----------------------------------------------------------------------------

CREATE TABLE MODEL_METADATA (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL COMMENT 'e.g., LogisticRegression, RandomForest',
    version VARCHAR(50) NOT NULL COMMENT 'Model version identifier',
    trained_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metrics JSON COMMENT 'Performance metrics: precision, recall, f1, roc_auc',
    hyperparameters JSON COMMENT 'Model hyperparameters',
    training_samples INT COMMENT 'Number of training samples',
    is_active BOOLEAN DEFAULT FALSE COMMENT 'Currently active model',
    notes TEXT COMMENT 'Additional notes about the model',
    UNIQUE KEY uk_model_version (model_name, version),
    INDEX idx_active (is_active)
) ENGINE=InnoDB COMMENT='ML model metadata and versioning';

-- ----------------------------------------------------------------------------
-- ML_PREDICTION Table
-- Purpose: Store model predictions
-- ----------------------------------------------------------------------------

CREATE TABLE ML_PREDICTION (
    prediction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NULL,
    model_id INT NOT NULL,
    predicted_class BOOLEAN NOT NULL COMMENT 'TRUE = Fraud, FALSE = Legitimate',
    probability_score DECIMAL(5,4) NOT NULL COMMENT 'Fraud probability (0-1)',
    predicted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES TRANSACTION(transaction_id) ON DELETE CASCADE,
    FOREIGN KEY (model_id) REFERENCES MODEL_METADATA(model_id) ON DELETE CASCADE,
    INDEX idx_transaction (transaction_id),
    INDEX idx_model (model_id),
    INDEX idx_predicted_class (predicted_class),
    INDEX idx_probability (probability_score),
    INDEX idx_predicted_at (predicted_at)
) ENGINE=InnoDB COMMENT='ML model predictions';

-- ----------------------------------------------------------------------------
-- TRANSACTION_ARCHIVE Table
-- Purpose: Store old transactions moved by the archiving stored procedure
-- ----------------------------------------------------------------------------

CREATE TABLE TRANSACTION_ARCHIVE (
    transaction_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    time INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_archive_customer_time (customer_id, time),
    INDEX idx_archive_time (time)
) ENGINE=InnoDB COMMENT='Archive for old transaction records';

-- ----------------------------------------------------------------------------
-- 4NF DEMONSTRATION TABLES (Multivalued Dependencies)
-- Purpose: Decomposed from hypothetical CUSTOMER_INFO(cust, card, branch)
-- ----------------------------------------------------------------------------

CREATE TABLE CUSTOMER_CARD (
    customer_id INT,
    credit_card_number VARCHAR(20),
    PRIMARY KEY (customer_id, credit_card_number),
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='4NF: Independent Multivalued Attribute';

CREATE TABLE CUSTOMER_BRANCH (
    customer_id INT,
    branch_name VARCHAR(50),
    PRIMARY KEY (customer_id, branch_name),
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT='4NF: Independent Multivalued Attribute';

-- ----------------------------------------------------------------------------
-- 5NF DEMONSTRATION TABLES (Join Dependencies)
-- Purpose: Decomposed from ternary INVESTIGATION(investigator, branch, category)
-- ----------------------------------------------------------------------------

CREATE TABLE INVESTIGATOR_BRANCH (
    investigator_name VARCHAR(50),
    branch_name VARCHAR(50),
    PRIMARY KEY (investigator_name, branch_name)
) ENGINE=InnoDB COMMENT='5NF: Pairwise relationship 1';

CREATE TABLE BRANCH_FRAUD (
    branch_name VARCHAR(50),
    fraud_category VARCHAR(50),
    PRIMARY KEY (branch_name, fraud_category)
) ENGINE=InnoDB COMMENT='5NF: Pairwise relationship 2';

CREATE TABLE INVESTIGATOR_FRAUD (
    investigator_name VARCHAR(50),
    fraud_category VARCHAR(50),
    PRIMARY KEY (investigator_name, fraud_category)
) ENGINE=InnoDB COMMENT='5NF: Pairwise relationship 3';

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Tables created: 13
-- 1. raw_transactions (staging)
-- 2. CUSTOMER (dimension)
-- 3. TRANSACTION (fact)
-- 4. TRANSACTION_FEATURES (normalized features)
-- 5. FRAUD_LABEL (labels)
-- 6. MODEL_METADATA (model versioning)
-- 7. ML_PREDICTION (predictions)
-- 8. TRANSACTION_ARCHIVE (archive)
-- 9. CUSTOMER_CARD (4NF)
-- 10. CUSTOMER_BRANCH (4NF)
-- 11. INVESTIGATOR_BRANCH (5NF)
-- 12. BRANCH_FRAUD (5NF)
-- 13. INVESTIGATOR_FRAUD (5NF)
-- ============================================================================
