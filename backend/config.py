"""
Backend Configuration
"""

import os
from dotenv import load_dotenv

load_dotenv()

# Flask Configuration
FLASK_HOST = os.getenv('FLASK_HOST', '0.0.0.0')
FLASK_PORT = int(os.getenv('FLASK_PORT', 5000))
FLASK_DEBUG = os.getenv('FLASK_DEBUG', 'True').lower() == 'true'

# Model Configuration
MODEL_PATH = os.getenv('MODEL_PATH', 'ml/models/fraud_model.pkl')

# CORS Configuration
CORS_ORIGINS = ['http://localhost:5000', 'http://127.0.0.1:5000']
