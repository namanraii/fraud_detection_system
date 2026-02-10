"""
CSV Import Script
Imports creditcard.csv into MySQL raw_transactions staging table
"""

import pandas as pd
import mysql.connector
from mysql.connector import Error
import logging
import sys
from tqdm import tqdm
from config import DB_CONFIG, DATASET_PATH, BATCH_SIZE, LOG_FORMAT

# Configure logging
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger(__name__)


def create_connection():
    """Create MySQL database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        if connection.is_connected():
            logger.info(f"Connected to MySQL database: {DB_CONFIG['database']}")
            return connection
    except Error as e:
        logger.error(f"Error connecting to MySQL: {e}")
        sys.exit(1)


def validate_csv_structure(df):
    """Validate CSV structure matches expected schema"""
    required_columns = ['Time', 'Amount', 'Class'] + [f'V{i}' for i in range(1, 29)]
    
    missing_columns = set(required_columns) - set(df.columns)
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")
    
    logger.info(f"CSV validation passed. Rows: {len(df)}, Columns: {len(df.columns)}")
    return True


def load_csv_data():
    """Load and validate CSV data"""
    logger.info(f"Loading CSV from: {DATASET_PATH}")
    
    try:
        df = pd.read_csv(DATASET_PATH)
        validate_csv_structure(df)
        
        # Display basic statistics
        logger.info(f"Dataset shape: {df.shape}")
        logger.info(f"Fraud cases: {df['Class'].sum()} ({df['Class'].mean()*100:.4f}%)")
        logger.info(f"Legitimate cases: {(df['Class']==0).sum()}")
        
        return df
    except FileNotFoundError:
        logger.error(f"CSV file not found: {DATASET_PATH}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error loading CSV: {e}")
        sys.exit(1)


def truncate_staging_table(connection):
    """Truncate raw_transactions table for clean import"""
    try:
        cursor = connection.cursor()
        cursor.execute("TRUNCATE TABLE raw_transactions")
        connection.commit()
        logger.info("Truncated raw_transactions table")
        cursor.close()
    except Error as e:
        logger.error(f"Error truncating table: {e}")
        raise


def import_data_batch(connection, df):
    """Import data using batch INSERT statements"""
    cursor = connection.cursor()
    
    # Prepare INSERT statement
    columns = ['Time'] + [f'V{i}' for i in range(1, 29)] + ['Amount', 'Class']
    placeholders = ', '.join(['%s'] * len(columns))
    column_names = ', '.join(columns)
    
    insert_query = f"""
        INSERT INTO raw_transactions ({column_names})
        VALUES ({placeholders})
    """
    
    total_rows = len(df)
    rows_inserted = 0
    
    logger.info(f"Starting batch import of {total_rows} rows...")
    
    try:
        # Process in batches with progress bar
        for start_idx in tqdm(range(0, total_rows, BATCH_SIZE), desc="Importing batches"):
            end_idx = min(start_idx + BATCH_SIZE, total_rows)
            batch_df = df.iloc[start_idx:end_idx]
            
            # Convert batch to list of tuples
            batch_data = []
            for _, row in batch_df.iterrows():
                values = [row['Time']] + [row[f'V{i}'] for i in range(1, 29)] + [row['Amount'], row['Class']]
                batch_data.append(tuple(values))
            
            # Execute batch insert
            cursor.executemany(insert_query, batch_data)
            connection.commit()
            rows_inserted += len(batch_data)
        
        logger.info(f"Successfully imported {rows_inserted} rows")
        cursor.close()
        return rows_inserted
        
    except Error as e:
        logger.error(f"Error during batch import: {e}")
        connection.rollback()
        cursor.close()
        raise


def verify_import(connection, expected_count):
    """Verify imported data count"""
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        actual_count = cursor.fetchone()[0]
        cursor.close()
        
        if actual_count == expected_count:
            logger.info(f"✓ Verification passed: {actual_count} rows imported")
            return True
        else:
            logger.error(f"✗ Verification failed: Expected {expected_count}, got {actual_count}")
            return False
    except Error as e:
        logger.error(f"Error during verification: {e}")
        return False


def main():
    """Main execution function"""
    logger.info("="*80)
    logger.info("Starting CSV Import Process")
    logger.info("="*80)
    
    # Load CSV data
    df = load_csv_data()
    
    # Connect to database
    connection = create_connection()
    
    try:
        # Truncate staging table
        truncate_staging_table(connection)
        
        # Import data
        rows_imported = import_data_batch(connection, df)
        
        # Verify import
        if verify_import(connection, len(df)):
            logger.info("="*80)
            logger.info("CSV Import Completed Successfully!")
            logger.info("="*80)
        else:
            logger.error("Import verification failed")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Import process failed: {e}")
        sys.exit(1)
    finally:
        if connection.is_connected():
            connection.close()
            logger.info("Database connection closed")


if __name__ == "__main__":
    main()
