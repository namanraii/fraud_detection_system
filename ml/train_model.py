"""
Machine Learning Model Training Script
Trains Logistic Regression and Random Forest models for fraud detection
"""

import pandas as pd
import numpy as np
import mysql.connector
from mysql.connector import Error
import logging
import sys
import os
import json
from datetime import datetime

from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report, confusion_matrix, 
    roc_auc_score, precision_recall_fscore_support
)
from imblearn.over_sampling import SMOTE
import joblib

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from etl.config import DB_CONFIG, LOG_FORMAT

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


def extract_features_from_db(connection):
    """Extract features and labels from normalized database"""
    logger.info("Extracting features from database...")
    
    cursor = connection.cursor()
    
    try:
        # Query to get all features for ML training
        query = """
            SELECT 
                t.transaction_id,
                t.time,
                t.amount,
                tfs.V1, tfs.V2, tfs.V3, tfs.V4, tfs.V5, tfs.V6, tfs.V7, tfs.V8, tfs.V9, tfs.V10,
                tfs.V11, tfs.V12, tfs.V13, tfs.V14, tfs.V15, tfs.V16, tfs.V17, tfs.V18, tfs.V19, tfs.V20,
                tfs.V21, tfs.V22, tfs.V23, tfs.V24, tfs.V25, tfs.V26, tfs.V27, tfs.V28,
                fl.is_fraud
            FROM 
                TRANSACTION t
                JOIN transaction_feature_summary tfs ON t.transaction_id = tfs.transaction_id
                JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
        """
        
        logger.info("Executing feature extraction query...")
        cursor.execute(query)
        
        # Fetch all results
        results = cursor.fetchall()
        
        # Get column names
        columns = [desc[0] for desc in cursor.description]
        
        # Create DataFrame
        df = pd.DataFrame(results, columns=columns)
        
        logger.info(f"Extracted {len(df)} records with {len(columns)} features")
        logger.info(f"Fraud cases: {df['is_fraud'].sum()} ({df['is_fraud'].mean()*100:.4f}%)")
        
        cursor.close()
        return df
        
    except Error as e:
        logger.error(f"Error extracting features: {e}")
        cursor.close()
        raise


def preprocess_data(df):
    """Preprocess features for ML training"""
    logger.info("Preprocessing data...")
    
    # Separate features and target
    X = df.drop(['transaction_id', 'is_fraud'], axis=1)
    y = df['is_fraud'].astype(int)
    
    # Log transform amount (add 1 to avoid log(0))
    X['amount'] = np.log1p(X['amount'].astype(float))
    
    # Normalize time
    X['time'] = X['time'] / X['time'].max()
    
    logger.info(f"Feature matrix shape: {X.shape}")
    logger.info(f"Target distribution: {y.value_counts().to_dict()}")
    
    return X, y


def apply_smote(X_train, y_train):
    """Apply SMOTE to handle class imbalance"""
    logger.info("Applying SMOTE for class balancing...")
    
    original_counts = pd.Series(y_train).value_counts()
    logger.info(f"Original class distribution: {original_counts.to_dict()}")
    
    smote = SMOTE(random_state=42, sampling_strategy=0.5)  # Oversample minority to 50% of majority
    X_resampled, y_resampled = smote.fit_resample(X_train, y_train)
    
    new_counts = pd.Series(y_resampled).value_counts()
    logger.info(f"Resampled class distribution: {new_counts.to_dict()}")
    
    return X_resampled, y_resampled


def train_logistic_regression(X_train, y_train, X_test, y_test):
    """Train Logistic Regression model"""
    logger.info("Training Logistic Regression model...")
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Train model with class weights
    model = LogisticRegression(
        max_iter=1000,
        random_state=42,
        class_weight='balanced',
        solver='liblinear'
    )
    
    model.fit(X_train_scaled, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
    
    metrics = calculate_metrics(y_test, y_pred, y_pred_proba)
    
    logger.info("Logistic Regression Results:")
    logger.info(f"  Precision: {metrics['precision']:.4f}")
    logger.info(f"  Recall: {metrics['recall']:.4f}")
    logger.info(f"  F1-Score: {metrics['f1_score']:.4f}")
    logger.info(f"  ROC-AUC: {metrics['roc_auc']:.4f}")
    
    return model, scaler, metrics


def train_random_forest(X_train, y_train, X_test, y_test):
    """Train Random Forest model with hyperparameter tuning"""
    logger.info("Training Random Forest model...")
    
    # Define parameter grid for tuning
    param_grid = {
        'n_estimators': [100, 200],
        'max_depth': [None, 20],
        'min_samples_split': [2, 5],
        'class_weight': ['balanced']
    }
    
    # Base model
    rf_base = RandomForestClassifier(random_state=42, n_jobs=2)
    
    # Grid search with cross-validation
    logger.info("Performing hyperparameter tuning...")
    grid_search = GridSearchCV(
        rf_base, 
        param_grid, 
        cv=3, 
        scoring='f1',  # Prioritize recall for fraud detection
        n_jobs=2,
        verbose=1
    )
    
    grid_search.fit(X_train, y_train)
    
    # Best model
    model = grid_search.best_estimator_
    logger.info(f"Best parameters: {grid_search.best_params_}")
    
    # Evaluate
    y_pred = model.predict(X_test)
    y_pred_proba = model.predict_proba(X_test)[:, 1]
    
    metrics = calculate_metrics(y_test, y_pred, y_pred_proba)
    metrics['best_params'] = grid_search.best_params_
    
    logger.info("Random Forest Results:")
    logger.info(f"  Precision: {metrics['precision']:.4f}")
    logger.info(f"  Recall: {metrics['recall']:.4f}")
    logger.info(f"  F1-Score: {metrics['f1_score']:.4f}")
    logger.info(f"  ROC-AUC: {metrics['roc_auc']:.4f}")
    
    return model, metrics


def calculate_metrics(y_true, y_pred, y_pred_proba):
    """Calculate evaluation metrics"""
    precision, recall, f1, _ = precision_recall_fscore_support(
        y_true, y_pred, average='binary', zero_division=0
    )
    
    roc_auc = roc_auc_score(y_true, y_pred_proba)
    
    cm = confusion_matrix(y_true, y_pred)
    
    return {
        'precision': float(precision),
        'recall': float(recall),
        'f1_score': float(f1),
        'roc_auc': float(roc_auc),
        'confusion_matrix': cm.tolist(),
        'true_positives': int(cm[1, 1]),
        'false_positives': int(cm[0, 1]),
        'true_negatives': int(cm[0, 0]),
        'false_negatives': int(cm[1, 0])
    }


def save_model(model, scaler, model_name, metrics):
    """Save trained model and metadata"""
    logger.info(f"Saving {model_name} model...")
    
    # Create models directory if not exists
    os.makedirs('ml/models', exist_ok=True)
    
    # Save model
    model_path = f'ml/models/{model_name.lower().replace(" ", "_")}_model.pkl'
    joblib.dump(model, model_path)
    logger.info(f"Model saved to: {model_path}")
    
    # Save scaler if exists
    if scaler is not None:
        scaler_path = f'ml/models/{model_name.lower().replace(" ", "_")}_scaler.pkl'
        joblib.dump(scaler, scaler_path)
        logger.info(f"Scaler saved to: {scaler_path}")
    
    # Save metrics
    metrics_path = f'ml/models/{model_name.lower().replace(" ", "_")}_metrics.json'
    with open(metrics_path, 'w') as f:
        json.dump(metrics, f, indent=2)
    logger.info(f"Metrics saved to: {metrics_path}")
    
    return model_path


def store_model_metadata(connection, model_name, version, metrics, hyperparams, training_samples):
    """Store model metadata in database"""
    logger.info("Storing model metadata in database...")
    
    cursor = connection.cursor()
    
    try:
        # Prepare metrics JSON
        metrics_json = json.dumps({
            'precision': metrics['precision'],
            'recall': metrics['recall'],
            'f1_score': metrics['f1_score'],
            'roc_auc': metrics['roc_auc'],
            'confusion_matrix': metrics['confusion_matrix']
        })
        
        hyperparams_json = json.dumps(hyperparams) if hyperparams else None
        
        # Insert model metadata
        # Insert model metadata
        cursor.execute("""
            INSERT INTO MODEL_METADATA
            (model_name, version, metrics, hyperparameters, training_samples, is_active)
            VALUES (%s, %s, %s, %s, %s, %s)
         """, (
             model_name,
             version,
             metrics_json,
             hyperparams_json,
             training_samples,
             False
         ))
        model_id = cursor.lastrowid
        connection.commit()
        
        logger.info(f"Model metadata stored with ID: {model_id}")
        cursor.close()
        return model_id
        
    except Error as e:
        logger.error(f"Error storing model metadata: {e}")
        connection.rollback()
        cursor.close()
        raise


def main():
    """Main training pipeline"""
    logger.info("="*80)
    logger.info("Starting ML Model Training Pipeline")
    logger.info("="*80)
    
    # Connect to database
    connection = create_connection()
    
    try:
        # Extract features
        df = extract_features_from_db(connection)
        
        # Preprocess data
        X, y = preprocess_data(df)
        
        # Train-test split (stratified)
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        logger.info(f"Training set size: {len(X_train)}")
        logger.info(f"Test set size: {len(X_test)}")
        
        # Apply SMOTE to training data
        X_train_balanced, y_train_balanced = apply_smote(X_train, y_train)
        
        # Train Logistic Regression
        lr_model, lr_scaler, lr_metrics = train_logistic_regression(
            X_train_balanced, y_train_balanced, X_test, y_test
        )
        
        # Save Logistic Regression
        lr_path = save_model(lr_model, lr_scaler, "Logistic Regression", lr_metrics)
        
        # Store in database
        store_model_metadata(
            connection, 
            "LogisticRegression", 
            "v1.2", 
            lr_metrics, 
            {'solver': 'liblinear', 'class_weight': 'balanced'},
            len(X_train_balanced)
        )
        
        # Train Random Forest
        rf_model, rf_metrics = train_random_forest(
            X_train_balanced, y_train_balanced, X_test, y_test
        )
        
        # Save Random Forest
        rf_path = save_model(rf_model, None, "Random Forest", rf_metrics)
        
        # Store in database
        store_model_metadata(
            connection, 
            "RandomForest", 
            "v1.2", 
            rf_metrics, 
            rf_metrics.get('best_params', {}),
            len(X_train_balanced)
        )
        
        # Compare models
        logger.info("="*80)
        logger.info("Model Comparison:")
        logger.info("="*80)
        logger.info(f"Logistic Regression - Recall: {lr_metrics['recall']:.4f}, F1: {lr_metrics['f1_score']:.4f}")
        logger.info(f"Random Forest       - Recall: {rf_metrics['recall']:.4f}, F1: {rf_metrics['f1_score']:.4f}")
        
        # Select best model based on recall (priority for fraud detection)
        # Select best model based on F1-score (better balance)
        if rf_metrics['f1_score'] > lr_metrics['f1_score']:
            best_model = "RandomForest"
            logger.info(f"\n✓ Best Model: Random Forest (F1: {rf_metrics['f1_score']:.4f})")        
        else:
            best_model = "LogisticRegression"
            logger.info(f"\n✓ Best Model: Logistic Regression (F1: {lr_metrics['f1_score']:.4f})")
    
        # Mark best model as active
        cursor = connection.cursor()
        cursor.execute("""
            UPDATE MODEL_METADATA 
            SET is_active = 1 
            WHERE model_name = %s AND version = 'v1.1'
        """, (best_model,))
        connection.commit()
        cursor.close()
        
        logger.info("="*80)
        logger.info("Model Training Completed Successfully!")
        logger.info("="*80)
        
    except Exception as e:
        logger.error(f"Training pipeline failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        if connection.is_connected():
            connection.close()
            logger.info("Database connection closed")


if __name__ == "__main__":
    main()
