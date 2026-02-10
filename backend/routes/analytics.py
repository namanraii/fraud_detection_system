"""
Analytics API Endpoint
GET /analytics - Get analytical insights and patterns
"""

from flask import Blueprint, jsonify, request
import logging
from backend.database import execute_query

logger = logging.getLogger(__name__)

analytics_bp = Blueprint('analytics', __name__)


@analytics_bp.route('/analytics', methods=['GET'])
def get_analytics():
    """
    Get analytical insights
    
    Query parameters:
    - metric: 'patterns' | 'customers' | 'trends' (default: 'patterns')
    
    Returns:
    {
        "success": true,
        "data": {...}
    }
    """
    try:
        metric = request.args.get('metric', 'patterns')
        
        if metric == 'patterns':
            # Fraud patterns by time and amount
            data = execute_query("""
                SELECT 
                    hour_bucket,
                    amount_bucket,
                    total_transactions,
                    fraud_transactions,
                    ROUND(fraud_rate * 100, 2) as fraud_rate_pct,
                    avg_amount
                FROM 
                    fraud_patterns
                ORDER BY 
                    fraud_rate DESC
                LIMIT 20
            """, fetch_all=True)
            
        elif metric == 'customers':
            # Customer risk segmentation
            data = execute_query("""
                SELECT 
                    CASE 
                        WHEN fraud_ratio = 0 THEN 'No Fraud'
                        WHEN fraud_ratio < 0.1 THEN 'Low Risk'
                        WHEN fraud_ratio < 0.3 THEN 'Medium Risk'
                        ELSE 'High Risk'
                    END AS risk_segment,
                    COUNT(*) AS customer_count,
                    ROUND(AVG(transaction_count), 2) AS avg_transactions,
                    ROUND(AVG(avg_transaction_amount), 2) AS avg_amount,
                    ROUND(AVG(fraud_ratio) * 100, 2) AS avg_fraud_ratio_pct
                FROM 
                    customer_transaction_stats
                WHERE 
                    transaction_count >= 3
                GROUP BY 
                    risk_segment
                ORDER BY 
                    FIELD(risk_segment, 'No Fraud', 'Low Risk', 'Medium Risk', 'High Risk')
            """, fetch_all=True)
            
        elif metric == 'trends':
            # Time-based fraud trends
            data = execute_query("""
                SELECT 
                    FLOOR(time / 3600) AS hour,
                    COUNT(*) AS total_transactions,
                    SUM(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
                    ROUND(AVG(CASE WHEN fl.is_fraud = 1 THEN 1 ELSE 0 END) * 100, 2) AS fraud_rate_pct,
                    ROUND(AVG(amount), 2) AS avg_amount
                FROM 
                    TRANSACTION t
                    JOIN FRAUD_LABEL fl ON t.transaction_id = fl.transaction_id
                GROUP BY 
                    hour
                ORDER BY 
                    hour
                LIMIT 48
            """, fetch_all=True)
            
        else:
            return jsonify({
                'success': False,
                'error': 'Invalid metric parameter'
            }), 400
        
        response = {
            'success': True,
            'metric': metric,
            'data': data or []
        }
        
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Analytics error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': 'Failed to fetch analytics data'
        }), 500


@analytics_bp.route('/analytics/high-risk', methods=['GET'])
def get_high_risk_transactions():
    """Get high-risk transactions"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        data = execute_query("""
            SELECT 
                transaction_id,
                customer_id,
                time,
                amount,
                is_fraud,
                amount_risk_flag,
                ROUND(customer_fraud_ratio * 100, 2) as customer_fraud_ratio_pct,
                customer_pattern_flag
            FROM 
                high_risk_transactions
            ORDER BY 
                amount DESC
            LIMIT %s
        """, params=(limit,), fetch_all=True)
        
        return jsonify({
            'success': True,
            'data': data or []
        }), 200
        
    except Exception as e:
        logger.error(f"High-risk transactions error: {e}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch high-risk transactions'
        }), 500
