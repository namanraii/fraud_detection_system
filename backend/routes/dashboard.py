"""
Dashboard API Endpoint
GET /dashboard - Get dashboard statistics and metrics
"""

from flask import Blueprint, jsonify
import logging
from backend.database import get_database_stats, execute_query

logger = logging.getLogger(__name__)

dashboard_bp = Blueprint('dashboard', __name__)


@dashboard_bp.route('/dashboard', methods=['GET'])
def get_dashboard():
    """
    Get dashboard statistics
    
    Returns:
    {
        "success": true,
        "data": {
            "overview": {...},
            "model_performance": {...},
            "recent_predictions": [...]
        }
    }
    """
    try:
        # Get overall statistics
        stats = get_database_stats()
        
        # Get model performance metrics (precision/recall stored in metrics JSON)
        model_performance = execute_query("""
            SELECT 
                model_name,
                version,
                training_samples as total_predictions,
                ROUND(JSON_EXTRACT(metrics, '$.roc_auc') * 100, 2)   as accuracy_pct,
                ROUND(JSON_EXTRACT(metrics, '$.precision') * 100, 2) as precision_pct,
                ROUND(JSON_EXTRACT(metrics, '$.recall') * 100, 2)    as recall_pct,
                ROUND(JSON_EXTRACT(metrics, '$.f1_score') * 100, 2)  as f1_pct,
                is_active
            FROM 
                MODEL_METADATA
            WHERE metrics IS NOT NULL
            ORDER BY 
                trained_at DESC
            LIMIT 5
        """, fetch_all=True)
        
        # Get recent predictions
        recent_predictions = execute_query("""
            SELECT 
                prediction_id,
                transaction_id,
                customer_id,
                amount,
                model_name,
                predicted_class,
                ROUND(probability_score * 100, 2) as fraud_probability_pct,
                actual_class,
                prediction_result,
                predicted_at
            FROM 
                recent_predictions
            LIMIT 10
        """, fetch_all=True)
        
        # Get fraud distribution by amount
        fraud_by_amount = execute_query("""
            SELECT 
                CASE 
                    WHEN amount < 50 THEN '0-50'
                    WHEN amount < 100 THEN '50-100'
                    WHEN amount < 200 THEN '100-200'
                    WHEN amount < 500 THEN '200-500'
                    ELSE '500+'
                END AS amount_range,
                COUNT(*) AS transaction_count,
                SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count
            FROM 
                TRANSACTION t
                JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
            GROUP BY 
                amount_range
            ORDER BY 
                FIELD(amount_range, '0-50', '50-100', '100-200', '200-500', '500+')
        """, fetch_all=True)
        
        # Build response
        response = {
            'success': True,
            'data': {
                'overview': {
                    'total_transactions': stats.get('total_transactions', 0),
                    'total_fraud': stats.get('total_fraud', 0),
                    'fraud_percentage': round(stats.get('fraud_percentage', 0), 4),
                    'total_predictions': stats.get('total_predictions', 0),
                    'active_model': stats.get('active_model')
                },
                'model_performance': model_performance or [],
                'recent_predictions': recent_predictions or [],
                'fraud_by_amount': fraud_by_amount or []
            }
        }
        
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': 'Failed to fetch dashboard data'
        }), 500
