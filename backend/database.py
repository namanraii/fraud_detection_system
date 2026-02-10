"""
Database Utilities for Backend
Provides connection pooling and query helpers
"""

import mysql.connector
from mysql.connector import pooling, Error
import os
import sys
from contextlib import contextmanager
import logging

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from etl.config import DB_CONFIG

logger = logging.getLogger(__name__)

# Create connection pool
try:
    connection_pool = pooling.MySQLConnectionPool(
        pool_name="fraud_detection_pool",
        pool_size=5,
        pool_reset_session=True,
        **DB_CONFIG
    )
    logger.info("Database connection pool created")
except Error as e:
    logger.error(f"Error creating connection pool: {e}")
    connection_pool = None


@contextmanager
def get_db_connection():
    """Context manager for database connections"""
    connection = None
    try:
        if connection_pool:
            connection = connection_pool.get_connection()
            yield connection
        else:
            connection = mysql.connector.connect(**DB_CONFIG)
            yield connection
    except Error as e:
        logger.error(f"Database connection error: {e}")
        if connection:
            connection.rollback()
        raise
    finally:
        if connection and connection.is_connected():
            connection.close()


def execute_query(query, params=None, fetch_one=False, fetch_all=False, commit=False):
    """Execute a parameterized query"""
    with get_db_connection() as connection:
        cursor = connection.cursor(dictionary=True)
        try:
            cursor.execute(query, params or ())
            
            if commit:
                connection.commit()
                return cursor.lastrowid
            elif fetch_one:
                result = cursor.fetchone()
                cursor.close()
                return result
            elif fetch_all:
                result = cursor.fetchall()
                cursor.close()
                return result
            else:
                cursor.close()
                return None
        except Error as e:
            logger.error(f"Query execution error: {e}")
            cursor.close()
            raise


def get_database_stats():
    """Get overall database statistics"""
    stats = {}
    
    with get_db_connection() as connection:
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Total transactions
            cursor.execute("SELECT COUNT(*) as count FROM TRANSACTION")
            stats['total_transactions'] = cursor.fetchone()['count']
            
            # Total fraud cases
            cursor.execute("SELECT COUNT(*) as count FROM FRAUD_LABEL WHERE is_fraud = 1")
            stats['total_fraud'] = cursor.fetchone()['count']
            
            # Fraud percentage
            if stats['total_transactions'] > 0:
                stats['fraud_percentage'] = (stats['total_fraud'] / stats['total_transactions']) * 100
            else:
                stats['fraud_percentage'] = 0
            
            # Total predictions
            cursor.execute("SELECT COUNT(*) as count FROM ML_PREDICTION")
            stats['total_predictions'] = cursor.fetchone()['count']
            
            # Active model
            cursor.execute("""
                SELECT model_name, version, trained_at
                FROM MODEL_METADATA
                WHERE is_active = 1
                LIMIT 1
            """)
            active_model = cursor.fetchone()
            stats['active_model'] = active_model if active_model else None
            
            cursor.close()
            return stats
            
        except Error as e:
            logger.error(f"Error getting database stats: {e}")
            cursor.close()
            return {}
