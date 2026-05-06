import numpy as np
from ml.predict import predict_fraud
import joblib

model = joblib.load('ml/models/random_forest_model.pkl')
base_data = {
    "time": 94813, "amount": 149.62,
    "V1": -1.359807, "V2": -0.072781, "V3": 2.536347, "V4": 1.378155, "V5": -0.338321, 
    "V6": 0.462388, "V7": 0.239599, "V8": 0.098698, "V9": 0.363787, "V10": 0.090794, 
    "V11": -0.551600, "V12": -0.617801, "V13": -0.991390, "V14": -0.311169, "V15": 1.468177, 
    "V16": -0.470401, "V17": 0.207971, "V18": 0.025791, "V19": 0.403993, "V20": 0.251412, 
    "V21": -0.018307, "V22": 0.277838, "V23": -0.110474, "V24": 0.066928, "V25": 0.128539, 
    "V26": -0.189115, "V27": 0.133558, "V28": -0.021053
}

def custom_predict_fraud(features_dict):
    feature_names = ['time', 'amount'] + [f'V{i}' for i in range(1, 29)]
    feature_values = []
    for name in feature_names:
        key = name.upper() if name.startswith('V') else name
        value = features_dict.get(key, 0.0)
        feature_values.append(value)
    
    X = np.array(feature_values).reshape(1, -1)
    
    probability = model.predict_proba(X)[0, 1]
    predicted_class = 1 if probability > 0.005 else 0
    return predicted_class, probability

for t in [472, 473]:
    data = base_data.copy()
    data['time'] = t
    data['amount'] = 529.00
    is_fraud, prob = custom_predict_fraud(data)
    print(f"Time: {t}, is_fraud: {bool(is_fraud)}, probability: {prob}")

