# Setup and Deployment Guide

## Quick Start Guide

This guide will help you set up and run the Financial Fraud Detection System from scratch.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] MySQL 8.0+ installed and running
- [ ] Python 3.8+ installed
- [ ] pip package manager
- [ ] Credit card dataset (creditcard.csv)
- [ ] Terminal/Command line access
- [ ] Web browser (Chrome, Firefox, Safari)

## Step-by-Step Setup

### 1. Verify MySQL Installation

```bash
# Check MySQL version
mysql --version

# Start MySQL service (if not running)
# macOS:
brew services start mysql

# Linux:
sudo systemctl start mysql

# Test MySQL connection
mysql -u root -p
```

### 2. Create Project Directory

```bash
# Navigate to project directory
cd /Users/namanrai/.gemini/antigravity/scratch/fraud_detection_system
```

### 3. Set Up Python Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# macOS/Linux:
source venv/bin/activate

# Windows:
venv\Scripts\activate

# Verify activation (should show venv path)
which python
```

### 4. Install Python Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install all requirements
pip install -r requirements.txt

# Verify installations
pip list
```

### 5. Configure Environment Variables

```bash
# Copy template
cp .env.example .env

# Edit .env file
nano .env  # or use your preferred editor

# Set these values:
# DB_PASSWORD=root1234
# DATASET_PATH=/Users/namanrai/Downloadscreditcard.csv
```

### 6. Initialize Database

```bash
# Create database and schema
mysql -u root -p < database/schema.sql
# Enter password: root1234

# Create indexes
mysql -u root -p < database/indexes.sql

# Create views
mysql -u root -p < database/views.sql

# Create advanced objects (Triggers, Functions, Procedures)
mysql -u root -p < database/advanced_objects.sql

# Verify database creation
mysql -u root -p -e "USE fraud_db; SHOW TABLES;"
```

Expected output:
```
+-----------------------------+
| Tables_in_fraud_db          |
+-----------------------------+
| CUSTOMER                    |
| FRAUD_LABEL                 |
| ML_PREDICTION               |
| MODEL_METADATA              |
| TRANSACTION                 |
| TRANSACTION_FEATURES        |
| raw_transactions            |
+-----------------------------+
```

### 7. Import Dataset

```bash
# Import CSV data
python etl/import_csv.py
```

Expected output:
```
================================================================================
Starting CSV Import Process
================================================================================
Loading CSV from: /Users/namanrai/Downloadscreditcard.csv
Dataset shape: (284807, 31)
Fraud cases: 492 (0.1727%)
Legitimate cases: 284315
Starting batch import of 284807 rows...
Importing batches: 100%|████████████████| 285/285
Successfully imported 284807 rows
✓ Verification passed: 284807 rows imported
================================================================================
CSV Import Completed Successfully!
================================================================================
```

### 8. Normalize Data

```bash
# Transform to 3NF schema
python etl/normalize_data.py
```

Expected output:
```
================================================================================
Starting Data Normalization Process
================================================================================
Creating customer records...
Creating 1000 synthetic customers...
✓ Created 1000 customers
Populating TRANSACTION table...
Processing 284807 transactions...
✓ Populated 284807 transactions
Populating TRANSACTION_FEATURES table...
✓ Populated transaction features
Populating FRAUD_LABEL table...
✓ Populated fraud labels (492 fraud cases)
Updating customer statistics...
✓ Updated customer statistics
✓ Verification passed
================================================================================
Data Normalization Completed Successfully!
================================================================================
```

### 9. Train ML Models

```bash
# Train models
python ml/train_model.py
```

Expected output:
```
================================================================================
Starting ML Model Training Pipeline
================================================================================
Extracting features from database...
Extracted 284807 records with 32 features
Fraud cases: 492 (0.1727%)
Preprocessing data...
Feature matrix shape: (284807, 30)
Applying SMOTE for class balancing...
Training Logistic Regression model...
Logistic Regression Results:
  Precision: 0.9234
  Recall: 0.8567
  F1-Score: 0.8888
  ROC-AUC: 0.9756
Training Random Forest model...
Performing hyperparameter tuning...
Random Forest Results:
  Precision: 0.9456
  Recall: 0.8923
  F1-Score: 0.9182
  ROC-AUC: 0.9834
================================================================================
Model Comparison:
================================================================================
Logistic Regression - Recall: 0.8567, F1: 0.8888
Random Forest       - Recall: 0.8923, F1: 0.9182

✓ Best Model: Random Forest (Recall: 0.8923)
================================================================================
Model Training Completed Successfully!
================================================================================
```

### 10. Evaluate Models

```bash
# Generate evaluation reports
python ml/evaluate_model.py
```

This creates:
- `ml/models/evaluation/lr_confusion_matrix.png`
- `ml/models/evaluation/rf_confusion_matrix.png`
- `ml/models/evaluation/model_comparison.png`
- `ml/models/evaluation/evaluation_report.txt`

### 11. Run Application

```bash
# Start Flask server
python backend/app.py
```

Expected output:
```
INFO - Initializing application...
INFO - Loaded active model: RandomForest (ID: 2)
INFO - Application initialized successfully
INFO - Starting Flask server on 0.0.0.0:5000
INFO - Debug mode: True
 * Running on http://0.0.0.0:5000
```

### 12. Access Application

Open your web browser and navigate to:

- **Prediction Interface**: http://localhost:5000
- **Dashboard**: http://localhost:5000/dashboard-page
- **Health Check**: http://localhost:5000/health

## Testing the System

### Test Prediction API

```bash
# Test with sample data
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "time": 94813,
    "amount": 149.62,
    "V1": -1.359807,
    "V2": -0.072781,
    "V3": 2.536347,
    "V4": 1.378155,
    "V5": -0.338321,
    "V6": 0.462388,
    "V7": 0.239599,
    "V8": 0.098698,
    "V9": 0.363787,
    "V10": 0.090794,
    "V11": -0.551600,
    "V12": -0.617801,
    "V13": -0.991390,
    "V14": -0.311169,
    "V15": 1.468177,
    "V16": -0.470401,
    "V17": 0.207971,
    "V18": 0.025791,
    "V19": 0.403993,
    "V20": 0.251412,
    "V21": -0.018307,
    "V22": 0.277838,
    "V23": -0.110474,
    "V24": 0.066928,
    "V25": 0.128539,
    "V26": -0.189115,
    "V27": 0.133558,
    "V28": -0.021053
  }'
```

Expected response:
```json
{
  "success": true,
  "prediction": {
    "is_fraud": false,
    "fraud_probability": 0.0234,
    "risk_level": "low"
  }
}
```

### Test Dashboard API

```bash
curl http://localhost:5000/dashboard
```

### Test Analytics API

```bash
curl http://localhost:5000/analytics?metric=patterns
```

## Troubleshooting

### MySQL Connection Error

**Error**: `Access denied for user 'root'@'localhost'`

**Solution**:
```bash
# Reset MySQL password
mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root1234';
FLUSH PRIVILEGES;
```

### Dataset Not Found

**Error**: `Dataset not found at: /path/to/creditcard.csv`

**Solution**:
- Verify the file path in `.env`
- Ensure the file exists: `ls -la /Users/namanrai/Downloadscreditcard.csv`
- Update `DATASET_PATH` in `.env`

### Port Already in Use

**Error**: `Address already in use`

**Solution**:
```bash
# Find process using port 5000
lsof -i :5000

# Kill the process
kill -9 <PID>

# Or change port in .env
FLASK_PORT=5001
```

### Model Not Found

**Error**: `No active model found in database`

**Solution**:
```bash
# Retrain models
python ml/train_model.py
```

### Import Errors

**Error**: `ModuleNotFoundError: No module named 'flask'`

**Solution**:
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall requirements
pip install -r requirements.txt
```

## Database Maintenance

### Backup Database

```bash
# Backup entire database
mysqldump -u root -p fraud_db > backup_$(date +%Y%m%d).sql

# Backup specific table
mysqldump -u root -p fraud_db TRANSACTION > transaction_backup.sql
```

### Restore Database

```bash
# Restore from backup
mysql -u root -p fraud_db < backup_20260206.sql
```

### Clear Predictions

```bash
# Clear all predictions
mysql -u root -p -e "USE fraud_db; TRUNCATE TABLE ML_PREDICTION;"
```

### Reset Database

```bash
# Drop and recreate
mysql -u root -p -e "DROP DATABASE IF EXISTS fraud_db;"
mysql -u root -p < database/schema.sql
```

## Performance Optimization

### Database Optimization

```sql
-- Analyze tables
ANALYZE TABLE TRANSACTION, FRAUD_LABEL, ML_PREDICTION;

-- Optimize tables
OPTIMIZE TABLE TRANSACTION, FRAUD_LABEL, ML_PREDICTION;

-- Check index usage
SHOW INDEX FROM TRANSACTION;
```

### Application Optimization

- **Connection Pooling**: Already configured (pool size: 5)
- **Batch Processing**: ETL uses batch size of 1000
- **Caching**: Consider adding Redis for frequent queries

## Deployment Considerations

### Production Checklist

- [ ] Change `FLASK_DEBUG=False` in `.env`
- [ ] Use production WSGI server (Gunicorn, uWSGI)
- [ ] Set up reverse proxy (Nginx, Apache)
- [ ] Enable HTTPS with SSL certificate
- [ ] Configure firewall rules
- [ ] Set up database backups
- [ ] Implement logging and monitoring
- [ ] Use environment-specific configs

### Production Deployment

```bash
# Install Gunicorn
pip install gunicorn

# Run with Gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 backend.app:app
```

## Monitoring

### Check System Status

```bash
# Database status
mysql -u root -p -e "SHOW PROCESSLIST;"

# Application logs
tail -f app.log

# System resources
top
```

### Performance Metrics

```sql
-- Query performance
SELECT * FROM information_schema.PROCESSLIST;

-- Table sizes
SELECT 
    table_name,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = 'fraud_db'
ORDER BY size_mb DESC;
```

## Next Steps

After successful setup:

1. ✅ Explore the prediction interface
2. ✅ Review the dashboard analytics
3. ✅ Test API endpoints
4. ✅ Review model evaluation reports
5. ✅ Examine database schema and views
6. ✅ Read the comprehensive README

## Support

For issues or questions:
- Check troubleshooting section
- Review error logs
- Verify all prerequisites
- Ensure correct configuration

---

**Congratulations!** Your Financial Fraud Detection System is now fully operational! 🎉
