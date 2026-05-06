import numpy as np
from ml.predict import predict_fraud
import joblib

model = joblib.load('ml/models/random_forest_model.pkl')
base_data = {
    "time": 472, "amount": 529.00,
    "V1": -3.0435406, "V2": -3.157307, "V3": 1.0884627, "V4": 2.2886436, "V5": 1.3598051, 
    "V6": -1.064822, "V7": 0.3255742, "V8": -0.067793, "V9": -0.270952, "V10": -0.838586, 
    "V11": -0.414575, "V12": -0.503140, "V13": 0.6765015, "V14": -1.692028, "V15": 2.0006348, 
    "V16": 0.6667796, "V17": 0.5997174, "V18": 1.725321, "V19": 0.2833448, "V20": 2.1023387, 
    "V21": 0.6616959, "V22": 0.4354772, "V23": 1.3759657, "V24": -0.293803, "V25": 0.279798, 
    "V26": -0.145361, "V27": -0.252773, "V28": 0.0357642
}

def custom_predict_fraud(features_dict):
    feature_names = ['time', 'amount'] + [f'V{i}' for i in range(1, 29)]
    feature_values = []
    for name in feature_names:
        key = name.upper() if name.startswith('V') else name
        value = features_dict.get(key, 0.0)
        feature_values.append(value)
    
    X = np.array(feature_values).reshape(1, -1)
    
    # NO TRANSFORMATIONS, as it was before my fix
    probability = model.predict_proba(X)[0, 1]
    predicted_class = 1 if probability > 0.005 else 0
    return predicted_class, probability

for t in [472, 473]:
    data = base_data.copy()
    data['time'] = t
    is_fraud, prob = custom_predict_fraud(data)
    print(f"Time: {t}, is_fraud: {bool(is_fraud)}, probability: {prob}")

