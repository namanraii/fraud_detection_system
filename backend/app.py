"""
Flask Application Entry Point
Main application setup and route registration
"""

from flask import Flask, jsonify, render_template
from flask_cors import CORS
import logging
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.config import FLASK_HOST, FLASK_PORT, FLASK_DEBUG, CORS_ORIGINS
from backend.routes.predict import predict_bp, init_model
from backend.routes.dashboard import dashboard_bp
from backend.routes.analytics import analytics_bp
from ml.predict import load_active_model
from backend.database import get_db_connection

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__, 
            template_folder='../frontend/templates',
            static_folder='../frontend/static')

# Enable CORS
CORS(app, resources={r"/*": {"origins": CORS_ORIGINS}})

# Register blueprints
app.register_blueprint(predict_bp)
app.register_blueprint(dashboard_bp)
app.register_blueprint(analytics_bp)


@app.route('/')
def index():
    """Serve main page"""
    return render_template('index.html')


@app.route('/dashboard-page')
def dashboard_page():
    """Serve dashboard page"""
    return render_template('dashboard.html')


@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        # Check database connection
        with get_db_connection() as connection:
            if connection.is_connected():
                db_status = 'connected'
            else:
                db_status = 'disconnected'
        
        return jsonify({
            'status': 'healthy',
            'database': db_status
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500


def initialize_app():
    """Initialize application (load model, etc.)"""
    logger.info("Initializing application...")
    
    try:
        # Load active model
        with get_db_connection() as connection:
            model, scaler, model_id = load_active_model(connection)
        
        if model is None:
            logger.warning("No active model found. Prediction endpoint will not work.")
        else:
            # Initialize prediction endpoint with model
            init_model(model, scaler, model_id)
            logger.info("Application initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize application: {e}")
        logger.warning("Application will start but predictions may not work")


if __name__ == '__main__':
    # Initialize app
    initialize_app()
    
    # Run Flask app
    logger.info(f"Starting Flask server on {FLASK_HOST}:{FLASK_PORT}")
    logger.info(f"Debug mode: {FLASK_DEBUG}")
    
    app.run(
        host=FLASK_HOST,
        port=FLASK_PORT,
        debug=FLASK_DEBUG
    )
