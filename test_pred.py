
import numpy as np
import joblib
import os
import sys

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from ml.predict import preprocess_features, predict_fraud

# Sample data (Legit)
sample_data = {
    'time': 94813, 
    'amount': 149.62, 
    'V1': -1.359807, 'V2': -0.072781, 'V3': 2.536347, 'V4': 1.378155, 
    'V5': -0.338321, 'V6': 0.462388, 'V7': 0.239599, 'V8': 0.098698, 
    'V9': 0.363787, 'V10': 0.090794, 'V11': -0.551600, 'V12': -0.617801, 
    'V13': -0.991390, 'V14': -0.311169, 'V15': 1.468177, 'V16': -0.470401, 
    'V17': 0.207971, 'V18': 0.025791, 'V19': 0.403993, 'V20': 0.251412, 
    'V21': -0.018307, 'V22': 0.277838, 'V23': -0.110474, 'V24': 0.066928, 
    'V25': 0.128539, 'V26': -0.189115, 'V27': 0.133558, 'V28': -0.021053
}

print("Testing Preprocessing...")
X = preprocess_features(sample_data)
print(f"Preprocessed X (first 5 features): {X[0, :5]}")

model_path = "ml/models/random_forest_model.pkl"
if os.path.exists(model_path):
    print(f"Loading model: {model_path}")
    model = joblib.load(model_path)
    
    # Try prediction
    prob = model.predict_proba(X)[0, 1]
    print(f"Fraud Probability: {prob*100:.2f}%")
else:
    print("Model not found at ml/models/random_forest_model.pkl")
