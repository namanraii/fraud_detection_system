"""
Database Configuration Module
Manages database connection settings and utilities
"""

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database Configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': os.getenv('DB_NAME', 'fraud_db'),
    'charset': 'utf8mb4',
    'use_unicode': True,
    'autocommit': False,
    'raise_on_warnings': True
}

# Dataset Configuration
DATASET_PATH = os.getenv('DATASET_PATH', 'creditcard.csv')

# Batch Processing Configuration
BATCH_SIZE = 1000  # Number of records to process at once
COMMIT_FREQUENCY = 5000  # Commit every N records

# Logging Configuration
LOG_LEVEL = 'INFO'
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

def get_db_connection_string():
    """Generate MySQL connection string for SQLAlchemy"""
    return f"mysql+mysqlconnector://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"

def validate_config():
    """Validate configuration settings"""
    errors = []
    
    if not os.path.exists(DATASET_PATH):
        errors.append(f"Dataset not found at: {DATASET_PATH}")
    
    if not DB_CONFIG['password']:
        errors.append("Database password not set")
    
    if errors:
        raise ValueError("Configuration errors:\n" + "\n".join(errors))
    
    return True
