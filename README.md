# Financial Fraud Detection System

A production-grade fraud detection system integrating MySQL database, machine learning models, and a full-stack web application for Database Management Systems course.

![System Architecture](docs/architecture_overview.png)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Database Schema](#database-schema)
- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Project Structure](#project-structure)
- [ML Models](#ml-models)
- [Contributing](#contributing)

## 🎯 Overview

This project implements a complete fraud detection pipeline that:
- Imports real-world credit card transaction data into MySQL
- Normalizes data into 3NF relational schema
- Performs SQL-based feature engineering
- Trains machine learning models (Logistic Regression & Random Forest)
- Provides REST API for predictions
- Offers interactive web dashboard for analytics

## ✨ Features

### Database Features
- **3NF Normalized Schema**: 7 tables with proper constraints and relationships
- **Performance Optimized**: Strategic indexing for fast queries
- **SQL Views**: Pre-built analytical views for feature engineering
- **Data Integrity**: Foreign key constraints and validation

### Machine Learning Features
- **Dual Models**: Logistic Regression and Random Forest
- **Class Balancing**: SMOTE for handling imbalanced data
- **Model Versioning**: Track multiple model versions in database
- **Comprehensive Metrics**: Precision, Recall, F1-Score, ROC-AUC

### Backend Features
- **RESTful API**: Flask-based API with 3 endpoints
- **Security**: Parameterized queries, input validation
- **Connection Pooling**: Efficient database connections
- **Error Handling**: Comprehensive error management

### Frontend Features
- **Responsive Design**: Bootstrap 5 with modern UI
- **Interactive Prediction**: Real-time fraud detection
- **Analytics Dashboard**: Charts and statistics
- **User-Friendly**: Sample data and helpful tooltips

## 🛠 Technology Stack

| Component | Technology |
|-----------|-----------|
| **Database** | MySQL 8.0+ |
| **Backend** | Python 3.8+, Flask |
| **ML Libraries** | scikit-learn, imbalanced-learn |
| **Frontend** | HTML5, CSS3, JavaScript, Bootstrap 5 |
| **Visualization** | Chart.js, Matplotlib, Seaborn |
| **Data Processing** | Pandas, NumPy |

## 🏗 System Architecture

```
┌─────────────┐
│   CSV Data  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│         ETL Pipeline                │
│  ┌──────────┐      ┌─────────────┐ │
│  │ Import   │─────▶│ Normalize   │ │
│  │ CSV      │      │ to 3NF      │ │
│  └──────────┘      └─────────────┘ │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│         MySQL Database              │
│  ┌──────────────────────────────┐  │
│  │ 7 Normalized Tables (3NF)    │  │
│  │ + Views + Indexes            │  │
│  └──────────────────────────────┘  │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│      ML Training Pipeline           │
│  ┌──────────┐      ┌─────────────┐ │
│  │ Extract  │─────▶│ Train       │ │
│  │ Features │      │ Models      │ │
│  └──────────┘      └─────────────┘ │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│         Flask Backend API           │
│  /predict  /dashboard  /analytics   │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│         Web Frontend                │
│  Prediction UI  +  Dashboard        │
└─────────────────────────────────────┘
```

## 🗄 Database Schema

### Tables (3NF Normalized)

1. **raw_transactions** - Staging table for CSV import
2. **CUSTOMER** - Customer dimension
3. **TRANSACTION** - Transaction facts
4. **TRANSACTION_FEATURES** - PCA features (V1-V28)
5. **FRAUD_LABEL** - Fraud classifications
6. **MODEL_METADATA** - ML model versioning
7. **ML_PREDICTION** - Prediction results

See [database/schema.sql](database/schema.sql) for complete schema.

## 📦 Installation

### Prerequisites

- MySQL 8.0 or higher
- Python 3.8 or higher
- pip package manager

### Step 1: Clone Repository

```bash
cd /Users/namanrai/.gemini/antigravity/scratch/fraud_detection_system
```

### Step 2: Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# venv\Scripts\activate  # On Windows

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your MySQL credentials
# DB_PASSWORD=your_mysql_password
# DATASET_PATH=/path/to/creditcard.csv
```

### Step 4: Set Up Database

```bash
# Create database and schema
mysql -u root -p < database/schema.sql

# Create indexes
mysql -u root -p < database/indexes.sql

# Create views
mysql -u root -p < database/views.sql
```

### Step 5: Import Data

```bash
# Import CSV to staging table
python etl/import_csv.py

# Normalize data to 3NF
python etl/normalize_data.py
```

### Step 6: Train ML Models

```bash
# Train models
python ml/train_model.py

# Evaluate models
python ml/evaluate_model.py
```

### Step 7: Run Application

```bash
# Start Flask server
python backend/app.py
```

Visit `http://localhost:5000` in your browser.

## 🚀 Usage

### Making Predictions

1. Navigate to `http://localhost:5000`
2. Enter transaction details (Time, Amount, V1-V28)
3. Click "Predict Fraud"
4. View fraud probability and risk level

### Viewing Dashboard

1. Navigate to `http://localhost:5000/dashboard-page`
2. View statistics, charts, and recent predictions
3. Analyze fraud patterns and model performance

### Using API

#### Predict Fraud
```bash
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "time": 12345,
    "amount": 149.62,
    "V1": -1.359807,
    ...
    "V28": -0.021053
  }'
```

#### Get Dashboard Data
```bash
curl http://localhost:5000/dashboard
```

#### Get Analytics
```bash
curl http://localhost:5000/analytics?metric=patterns
```

## 📚 API Documentation

### POST /predict

Make fraud prediction for a transaction.

**Request Body:**
```json
{
  "time": 12345,
  "amount": 149.62,
  "V1": -1.359807,
  ...
  "V28": -0.021053
}
```

**Response:**
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

### GET /dashboard

Get dashboard statistics and metrics.

**Response:**
```json
{
  "success": true,
  "data": {
    "overview": {...},
    "model_performance": [...],
    "recent_predictions": [...],
    "fraud_by_amount": [...]
  }
}
```

### GET /analytics

Get analytical insights.

**Query Parameters:**
- `metric`: `patterns` | `customers` | `trends`

**Response:**
```json
{
  "success": true,
  "metric": "patterns",
  "data": [...]
}
```

## 📁 Project Structure

```
fraud_detection_system/
├── database/
│   ├── schema.sql              # 3NF database schema
│   ├── indexes.sql             # Performance indexes
│   ├── views.sql               # Analytical views
│   └── sample_queries.sql      # Example queries
├── etl/
│   ├── config.py               # ETL configuration
│   ├── import_csv.py           # CSV import script
│   └── normalize_data.py       # Data normalization
├── ml/
│   ├── train_model.py          # Model training
│   ├── evaluate_model.py       # Model evaluation
│   ├── predict.py              # Prediction utilities
│   └── models/                 # Saved models
├── backend/
│   ├── app.py                  # Flask application
│   ├── config.py               # Backend config
│   ├── database.py             # DB utilities
│   └── routes/
│       ├── predict.py          # Prediction endpoint
│       ├── dashboard.py        # Dashboard endpoint
│       └── analytics.py        # Analytics endpoint
├── frontend/
│   ├── templates/
│   │   ├── index.html          # Prediction page
│   │   └── dashboard.html      # Dashboard page
│   └── static/
│       ├── css/
│       │   └── style.css       # Custom styles
│       └── js/
│           └── app.js          # Frontend logic
├── docs/                       # Documentation
├── requirements.txt            # Python dependencies
├── .env                        # Environment variables
└── README.md                   # This file
```

## 🤖 ML Models

### Logistic Regression
- **Purpose**: Baseline model with interpretability
- **Features**: Scaled features with StandardScaler
- **Class Weight**: Balanced to handle imbalance

### Random Forest
- **Purpose**: Ensemble model for better performance
- **Hyperparameters**: Tuned with GridSearchCV
- **Priority**: Optimized for recall (fraud detection)

### Evaluation Metrics

| Metric | Description | Priority |
|--------|-------------|----------|
| **Recall** | Minimize false negatives | ⭐⭐⭐ High |
| **Precision** | Minimize false positives | ⭐⭐ Medium |
| **F1-Score** | Balance of precision/recall | ⭐⭐ Medium |
| **ROC-AUC** | Overall discrimination | ⭐⭐ Medium |

## 🔐 Security Features

- **SQL Injection Prevention**: Parameterized queries
- **Input Validation**: Type checking and range validation
- **Error Handling**: Secure error messages
- **Connection Pooling**: Resource management

## 📊 Sample Results

After training on the Credit Card Fraud dataset:

- **Dataset Size**: 284,807 transactions
- **Fraud Rate**: ~0.17%
- **Model Recall**: >85% (fraud detection)
- **Model Precision**: >90%

## 🎓 Academic Context

This project demonstrates:
- **Database Design**: 3NF normalization, indexing
- **SQL Proficiency**: Complex queries, views, joins
- **ETL Pipeline**: Data extraction, transformation, loading
- **Machine Learning**: Classification, imbalanced data
- **Full-Stack Development**: Backend API, frontend UI
- **Software Engineering**: Modular code, documentation

## 📝 License

This project is created for educational purposes as part of a Database Management Systems course.

## 👥 Author

Database Management Systems Course Project

## 🙏 Acknowledgments

- Dataset: [Credit Card Fraud Detection](https://www.kaggle.com/mlg-ulb/creditcardfraud) from Kaggle
- Technologies: MySQL, Python, Flask, scikit-learn, Bootstrap

---

**Note**: This is a demonstration project for academic purposes. For production use, additional security measures and scalability considerations would be required.
