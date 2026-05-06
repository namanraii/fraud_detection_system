"""
Live Prediction Simulator
Simulates a real-time production stream by continuously making predictions on unseen transactions.
"""

import time
import random
import mysql.connector
import sys
import os
import logging

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from etl.config import DB_CONFIG, LOG_FORMAT
from ml.predict import load_active_model, batch_predict

# Configure logging
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger(__name__)

def run_simulation(batch_size=5, sleep_seconds=2):
    logger.info("=" * 80)
    logger.info("Starting Live Prediction Simulator")
    logger.info(f"Targeting {batch_size} transactions every {sleep_seconds} seconds")
    logger.info("=" * 80)
    
    while True:
        try:
            connection = mysql.connector.connect(**DB_CONFIG)
            
            # Load active model every iteration in case it changes
            model, scaler, model_id = load_active_model(connection)
            
            if model is None:
                logger.error("Failed to load active model for scoring. Waiting...")
                time.sleep(5)
                connection.close()
                continue
                
            cursor = connection.cursor(dictionary=True)
            
            # Find batch of unpredicted transactions
            query = f"""
                SELECT 
                    t.transaction_id,
                    t.time,
                    t.amount,
                    tfs.V1, tfs.V2, tfs.V3, tfs.V4, tfs.V5, tfs.V6, tfs.V7, tfs.V8, tfs.V9, tfs.V10,
                    tfs.V11, tfs.V12, tfs.V13, tfs.V14, tfs.V15, tfs.V16, tfs.V17, tfs.V18, tfs.V19, tfs.V20,
                    tfs.V21, tfs.V22, tfs.V23, tfs.V24, tfs.V25, tfs.V26, tfs.V27, tfs.V28
                FROM 
                    TRANSACTION t
                    JOIN transaction_feature_summary tfs ON t.transaction_id = tfs.transaction_id
                    LEFT JOIN ML_PREDICTION mp ON t.transaction_id = mp.transaction_id
                WHERE 
                    mp.prediction_id IS NULL
                ORDER BY RAND()
                LIMIT {batch_size}
            """
            cursor.execute(query)
            transactions = cursor.fetchall()
            cursor.close()
            
            if not transactions:
                logger.info("No unpredicted transactions left in DB!")
                connection.close()
                break
                
            # Make predictions
            from ml.predict import predict_fraud, store_prediction
            
            predicted_fraud_count = 0
            for txn in transactions:
                transaction_id = txn['transaction_id']
                predicted_class, probability = predict_fraud(model, scaler, txn)
                
                if store_prediction(connection, transaction_id, model_id, predicted_class, probability):
                    if predicted_class:
                        predicted_fraud_count += 1
                        
            logger.info(f"Generated {len(transactions)} predictions (Fraud detected: {predicted_fraud_count})")
            
            connection.close()
            
            # Sleep with some random jitter to simulate organic traffic
            current_sleep = sleep_seconds + random.uniform(-0.5, 0.5)
            time.sleep(max(0.1, current_sleep))
            
        except Exception as e:
            logger.error(f"Simulator error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    try:
        # Run 5-10 transactions every 3 seconds
        run_simulation(batch_size=8, sleep_seconds=3)
    except KeyboardInterrupt:
        logger.info("Simulator stopped by user.")
