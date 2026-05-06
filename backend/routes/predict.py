"""
Prediction API Endpoint
POST /predict - Make fraud prediction for a transaction
"""

from flask import Blueprint, request, jsonify
import logging
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from ml.predict import predict_fraud, store_prediction

logger = logging.getLogger(__name__)

predict_bp = Blueprint('predict', __name__)

# Global variables for model (loaded on app startup)
_model = None
_scaler = None
_model_id = None


def init_model(model, scaler, model_id):
    """Initialize model for predictions"""
    global _model, _scaler, _model_id
    _model = model
    _scaler = scaler
    _model_id = model_id
    logger.info("Prediction endpoint initialized with model")


@predict_bp.route('/predict', methods=['POST'])
def make_prediction():
    """
    Make fraud prediction for a transaction
    
    Expected JSON payload:
    {
        "time": 12345,
        "amount": 100.50,
        "V1": -1.359807,
        "V2": -0.072781,
        ...
        "V28": -0.021053,
        "transaction_id": 123 (optional, for storing prediction)
    }
    
    Returns:
    {
        "success": true,
        "prediction": {
            "is_fraud": false,
            "fraud_probability": 0.0234,
            "risk_level": "low"
        }
    }
    """
    try:
        # Validate request
        if not request.is_json:
            return jsonify({
                'success': False,
                'error': 'Content-Type must be application/json'
            }), 400
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['time', 'amount'] + [f'V{i}' for i in range(1, 29)]
        missing_fields = [field for field in required_fields if field not in data]
        
        if missing_fields:
            return jsonify({
                'success': False,
                'error': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        # Validate model is loaded
        if _model is None:
            return jsonify({
                'success': False,
                'error': 'Model not loaded'
            }), 500
        
        # Make prediction
        is_fraud, fraud_probability = predict_fraud(_model, _scaler, data)
        
        # Determine risk level
        if fraud_probability < 0.3:
            risk_level = 'low'
        elif fraud_probability < 0.7:
            risk_level = 'medium'
        else:
            risk_level = 'high'
        
        # Store prediction if transaction_id provided
        prediction_id = None
        if _model_id:
            from backend.database import get_db_connection
            try:
                with get_db_connection() as connection:
                    prediction_id = store_prediction(
                        connection,
                        data.get('transaction_id',None),
                        _model_id,
                        is_fraud,
                        fraud_probability,
                        data.get('amount')
                    )
            except Exception as e:
                logger.warning(f"Failed to store prediction: {e}")
        
        # Return response
        response = {
            'success': True,
            'prediction': {
                'is_fraud': bool(is_fraud),
                'fraud_probability': round(fraud_probability, 4),
                'risk_level': risk_level
            }
        }
        
        if prediction_id:
            response['prediction']['prediction_id'] = prediction_id
        
        logger.info(f"Prediction made: fraud={is_fraud}, probability={fraud_probability:.4f}")
        
        return jsonify(response), 200
        
    except ValueError as e:
        logger.error(f"Validation error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
