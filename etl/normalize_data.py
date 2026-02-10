"""
Data Normalization Script
Transforms data from raw_transactions staging table to normalized 3NF schema
"""

import mysql.connector
from mysql.connector import Error
import logging
import sys
from tqdm import tqdm
from config import DB_CONFIG, BATCH_SIZE, LOG_FORMAT

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


def create_customers(connection):
    """
    Create synthetic customers from transaction patterns
    Since dataset has no customer ID, we create one customer per transaction
    In production, you'd group by actual customer identifiers
    """
    logger.info("Creating customer records...")
    
    cursor = connection.cursor()
    
    try:
        # Get count of raw transactions
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        total_transactions = cursor.fetchone()[0]
        
        # For this dataset, we'll create customers in batches
        # In reality, we'd group transactions by customer ID
        # Here we create 1000 synthetic customers and distribute transactions
        num_customers = min(1000, total_transactions // 10)  # ~10 transactions per customer on average
        
        logger.info(f"Creating {num_customers} synthetic customers...")
        
        # Insert customers
        for i in tqdm(range(num_customers), desc="Creating customers"):
            cursor.execute("""
                INSERT INTO CUSTOMER (customer_id, created_at, total_transactions, total_fraud_count, risk_score)
                VALUES (%s, NOW(), 0, 0, 0.0)
            """, (i + 1,))
            
            if (i + 1) % BATCH_SIZE == 0:
                connection.commit()
        
        connection.commit()
        logger.info(f"✓ Created {num_customers} customers")
        cursor.close()
        return num_customers
        
    except Error as e:
        logger.error(f"Error creating customers: {e}")
        connection.rollback()
        cursor.close()
        raise


def populate_transactions(connection, num_customers):
    """Populate TRANSACTION table from raw_transactions"""
    logger.info("Populating TRANSACTION table...")
    
    cursor = connection.cursor()
    
    try:
        # Get total count
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        total_rows = cursor.fetchone()[0]
        
        logger.info(f"Processing {total_rows} transactions...")
        
        # Fetch and insert in batches
        offset = 0
        transaction_id = 1
        
        with tqdm(total=total_rows, desc="Inserting transactions") as pbar:
            while offset < total_rows:
                # Fetch batch
                cursor.execute(f"""
                    SELECT id, Time, Amount
                    FROM raw_transactions
                    LIMIT {BATCH_SIZE} OFFSET {offset}
                """)
                
                batch = cursor.fetchall()
                if not batch:
                    break
                
                # Insert batch with random customer assignment
                insert_data = []
                for raw_id, time, amount in batch:
                    # Assign customer (round-robin distribution)
                    customer_id = ((transaction_id - 1) % num_customers) + 1
                    insert_data.append((transaction_id, customer_id, time, amount))
                    transaction_id += 1
                
                cursor.executemany("""
                    INSERT INTO TRANSACTION (transaction_id, customer_id, time, amount)
                    VALUES (%s, %s, %s, %s)
                """, insert_data)
                
                connection.commit()
                offset += BATCH_SIZE
                pbar.update(len(batch))
        
        logger.info(f"✓ Populated {transaction_id - 1} transactions")
        cursor.close()
        
    except Error as e:
        logger.error(f"Error populating transactions: {e}")
        connection.rollback()
        cursor.close()
        raise


def populate_transaction_features(connection):
    """Populate TRANSACTION_FEATURES table with V1-V28 features"""
    logger.info("Populating TRANSACTION_FEATURES table...")
    
    cursor = connection.cursor()
    
    try:
        # Get total count
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        total_rows = cursor.fetchone()[0]
        
        logger.info(f"Processing features for {total_rows} transactions...")
        
        offset = 0
        
        with tqdm(total=total_rows, desc="Inserting features") as pbar:
            while offset < total_rows:
                # Fetch batch
                feature_columns = ', '.join([f'V{i}' for i in range(1, 29)])
                cursor.execute(f"""
                    SELECT id, {feature_columns}
                    FROM raw_transactions
                    LIMIT {BATCH_SIZE} OFFSET {offset}
                """)
                
                batch = cursor.fetchall()
                if not batch:
                    break
                
                # Prepare feature inserts
                insert_data = []
                for row in batch:
                    transaction_id = row[0]  # Maps to raw_transactions.id = TRANSACTION.transaction_id
                    features = row[1:]  # V1-V28 values
                    
                    for i, value in enumerate(features, 1):
                        if value is not None:  # Skip null values
                            insert_data.append((transaction_id, f'V{i}', value))
                
                # Batch insert features
                if insert_data:
                    cursor.executemany("""
                        INSERT INTO TRANSACTION_FEATURES (transaction_id, feature_name, feature_value)
                        VALUES (%s, %s, %s)
                    """, insert_data)
                
                connection.commit()
                offset += BATCH_SIZE
                pbar.update(len(batch))
        
        logger.info(f"✓ Populated transaction features")
        cursor.close()
        
    except Error as e:
        logger.error(f"Error populating features: {e}")
        connection.rollback()
        cursor.close()
        raise


def populate_fraud_labels(connection):
    """Populate FRAUD_LABEL table from Class column"""
    logger.info("Populating FRAUD_LABEL table...")
    
    cursor = connection.cursor()
    
    try:
        # Get total count
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        total_rows = cursor.fetchone()[0]
        
        logger.info(f"Processing fraud labels for {total_rows} transactions...")
        
        offset = 0
        
        with tqdm(total=total_rows, desc="Inserting fraud labels") as pbar:
            while offset < total_rows:
                # Fetch batch
                cursor.execute(f"""
                    SELECT id, Class
                    FROM raw_transactions
                    LIMIT {BATCH_SIZE} OFFSET {offset}
                """)
                
                batch = cursor.fetchall()
                if not batch:
                    break
                
                # Insert batch
                insert_data = [(transaction_id, bool(fraud_class)) for transaction_id, fraud_class in batch]
                
                cursor.executemany("""
                    INSERT INTO FRAUD_LABEL (transaction_id, is_fraud)
                    VALUES (%s, %s)
                """, insert_data)
                
                connection.commit()
                offset += BATCH_SIZE
                pbar.update(len(batch))
        
        # Count fraud cases
        cursor.execute("SELECT COUNT(*) FROM FRAUD_LABEL WHERE is_fraud = 1")
        fraud_count = cursor.fetchone()[0]
        
        logger.info(f"✓ Populated fraud labels ({fraud_count} fraud cases)")
        cursor.close()
        
    except Error as e:
        logger.error(f"Error populating fraud labels: {e}")
        connection.rollback()
        cursor.close()
        raise


def update_customer_stats(connection):
    """Update customer statistics (transaction counts, fraud ratios)"""
    logger.info("Updating customer statistics...")
    
    cursor = connection.cursor()
    
    try:
        cursor.execute("""
            UPDATE CUSTOMER c
            SET 
                total_transactions = (
                    SELECT COUNT(*) 
                    FROM TRANSACTION t 
                    WHERE t.customer_id = c.customer_id
                ),
                total_fraud_count = (
                    SELECT COUNT(*) 
                    FROM TRANSACTION t
                    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
                    WHERE t.customer_id = c.customer_id AND fl.is_fraud = 1
                ),
                risk_score = (
                    SELECT COALESCE(AVG(CASE WHEN fl.is_fraud = 1 THEN 1.0 ELSE 0.0 END), 0.0)
                    FROM TRANSACTION t
                    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
                    WHERE t.customer_id = c.customer_id
                ),
                last_transaction_time = (
                    SELECT MAX(time)
                    FROM TRANSACTION t
                    WHERE t.customer_id = c.customer_id
                )
        """)
        
        connection.commit()
        logger.info("✓ Updated customer statistics")
        cursor.close()
        
    except Error as e:
        logger.error(f"Error updating customer stats: {e}")
        connection.rollback()
        cursor.close()
        raise


def verify_normalization(connection):
    """Verify data integrity after normalization"""
    logger.info("Verifying data normalization...")
    
    cursor = connection.cursor()
    
    try:
        # Check counts
        cursor.execute("SELECT COUNT(*) FROM raw_transactions")
        raw_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM TRANSACTION")
        transaction_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM FRAUD_LABEL")
        label_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM CUSTOMER")
        customer_count = cursor.fetchone()[0]
        
        logger.info(f"Raw transactions: {raw_count}")
        logger.info(f"Normalized transactions: {transaction_count}")
        logger.info(f"Fraud labels: {label_count}")
        logger.info(f"Customers: {customer_count}")
        
        if transaction_count == raw_count and label_count == raw_count:
            logger.info("✓ Verification passed")
            return True
        else:
            logger.error("✗ Verification failed: Count mismatch")
            return False
            
        cursor.close()
        
    except Error as e:
        logger.error(f"Error during verification: {e}")
        cursor.close()
        return False


def main():
    """Main execution function"""
    logger.info("="*80)
    logger.info("Starting Data Normalization Process")
    logger.info("="*80)
    
    connection = create_connection()
    
    try:
        # Step 1: Create customers
        num_customers = create_customers(connection)
        
        # Step 2: Populate transactions
        populate_transactions(connection, num_customers)
        
        # Step 3: Populate transaction features
        populate_transaction_features(connection)
        
        # Step 4: Populate fraud labels
        populate_fraud_labels(connection)
        
        # Step 5: Update customer statistics
        update_customer_stats(connection)
        
        # Step 6: Verify normalization
        if verify_normalization(connection):
            logger.info("="*80)
            logger.info("Data Normalization Completed Successfully!")
            logger.info("="*80)
        else:
            logger.error("Normalization verification failed")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Normalization process failed: {e}")
        sys.exit(1)
    finally:
        if connection.is_connected():
            connection.close()
            logger.info("Database connection closed")


if __name__ == "__main__":
    main()
