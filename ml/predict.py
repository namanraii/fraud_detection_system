"""
Prediction Utilities
Functions for making predictions and storing results in database
"""

import numpy as np
import pandas as pd
import mysql.connector
from mysql.connector import Error
import logging
import sys
import os
import joblib
from datetime import datetime

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from etl.config import DB_CONFIG, LOG_FORMAT

# Configure logging
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger(__name__)


def load_active_model(connection):
    """Load the active model from database metadata"""
    cursor = connection.cursor(dictionary=True)
    
    try:
        cursor.execute("""
            SELECT model_id, model_name, version
            FROM MODEL_METADATA
            WHERE is_active = 1
            ORDER BY trained_at DESC
            LIMIT 1
        """)
        
        model_info = cursor.fetchone()
        cursor.close()
        
        if not model_info:
            logger.error("No active model found in database")
            return None, None, None
        
        model_name = model_info['model_name']
        model_id = model_info['model_id']
        
        # Load model file
        if model_name == "RandomForest":
            model_filename = "random_forest_model.pkl"
        elif model_name == "LogisticRegression":
            model_filename = "logistic_regression_model.pkl"
        else:
            logger.error(f"Unknown model name: {model_name}")
            return None, None, None 
        model_path = f"ml/models/{model_filename}"
        
        if not os.path.exists(model_path):
            logger.error(f"Model file not found: {model_path}")
            return None, None, None
        
        model = joblib.load(model_path)
        logger.info(f"Loaded active model: {model_name} (ID: {model_id})")
        
        # Load scaler if exists (for Logistic Regression)
        scaler = None
        if model_name == "LogisticRegression":
            scaler_path = "ml/models/logistic_regression_scaler.pkl"
        else:
            scaler_path = None
        if scaler_path and os.path.exists(scaler_path):
            scaler = joblib.load(scaler_path)
            logger.info("Loaded scaler")
        
        return model, scaler, model_id
        
    except Error as e:
        logger.error(f"Error loading active model: {e}")
        cursor.close()
        return None, None, None


def preprocess_features(features_dict, scaler=None):
    """Preprocess features for prediction"""
    # Expected feature order
    feature_names = ['time', 'amount'] + [f'V{i}' for i in range(1, 29)]
    
    # Create feature array
    feature_values = []
    for name in feature_names:
        key = name.upper() if name.startswith('V') else name
        value = features_dict.get(key, 0.0)
        feature_values.append(value)
    
    # Convert to numpy array
    X = np.array(feature_values).reshape(1, -1)
    
    # Apply transformations
    # Log transform amount
    #X[0, 1] = np.log1p(X[0, 1])
    
    # Normalize time (assuming max time from training)
    #X[0, 0] = X[0, 0] / 172800.0  # Approximate max time from dataset
    if scaler is not None:
        X = scaler.transform(X)
    # Apply scaler if provided
    if scaler is not None:
        X = scaler.transform(X)
    
    return X


def predict_fraud(model, scaler, features_dict):
    """Make fraud prediction"""
    # Preprocess features
    X = preprocess_features(features_dict, scaler)
    
    # Make prediction
    probability = model.predict_proba(X)[0, 1]
    threshold = 0.005
    predicted_class = 1 if probability > threshold else 0
    return bool(predicted_class), float(probability)


def store_prediction(connection, transaction_id, model_id, predicted_class, probability_score):
    """Store prediction in database"""
    cursor = connection.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO ML_PREDICTION 
            (transaction_id, model_id, predicted_class, probability_score)
            VALUES (%s, %s, %s, %s)
        """, (transaction_id, model_id, predicted_class, probability_score))
        
        prediction_id = cursor.lastrowid
        connection.commit()
        cursor.close()
        
        logger.info(f"Stored prediction ID: {prediction_id}")
        return prediction_id
        
    except Error as e:
        logger.error(f"Error storing prediction: {e}")
        connection.rollback()
        cursor.close()
        return None


def batch_predict(connection, model, scaler, model_id, transaction_ids=None):
    """Make predictions for multiple transactions"""
    cursor = connection.cursor(dictionary=True)
    
    try:
        # Build query
        if transaction_ids:
            placeholders = ','.join(['%s'] * len(transaction_ids))
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
                WHERE 
                    t.transaction_id IN ({placeholders})
            """
            cursor.execute(query, transaction_ids)
        else:
            # Predict for all transactions without predictions
            query = """
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
                LIMIT 1000
            """
            cursor.execute(query)
        
        transactions = cursor.fetchall()
        cursor.close()
        
        logger.info(f"Making predictions for {len(transactions)} transactions...")
        
        predictions_stored = 0
        for txn in transactions:
            transaction_id = txn['transaction_id']
            
            # Make prediction
            predicted_class, probability = predict_fraud(model, scaler, txn)
            
            # Store prediction
            if store_prediction(connection, transaction_id, model_id, predicted_class, probability):
                predictions_stored += 1
        
        logger.info(f"Stored {predictions_stored} predictions")
        return predictions_stored
        
    except Error as e:
        logger.error(f"Error in batch prediction: {e}")
        cursor.close()
        return 0


def main():
    """Main prediction function for testing"""
    logger.info("Testing prediction functionality...")
    
    connection = mysql.connector.connect(**DB_CONFIG)
    
    try:
        # Load active model
        model, scaler, model_id = load_active_model(connection)
        
        if model is None:
            logger.error("Failed to load model")
            sys.exit(1)
        
        # Make batch predictions
        predictions_count = batch_predict(connection, model, scaler, model_id)
        
        logger.info(f"Successfully made {predictions_count} predictions")
        
    except Exception as e:
        logger.error(f"Prediction test failed: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if connection.is_connected():
            connection.close()


if __name__ == "__main__":
    main()
