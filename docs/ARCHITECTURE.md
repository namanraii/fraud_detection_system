# System Architecture

## High-Level Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│                          DATA SOURCE LAYER                            │
│                                                                       │
│              📄 creditcard.csv (284,807 transactions)                 │
│                     Kaggle Credit Card Fraud Dataset                  │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          ETL PIPELINE LAYER                           │
│                                                                       │
│   ┌──────────────────┐              ┌──────────────────┐            │
│   │  CSV Import      │─────────────▶│  Normalize Data  │            │
│   │  (import_csv.py) │              │  (normalize_data)│            │
│   │  • Validate      │              │  • Create 3NF    │            │
│   │  • Batch Load    │              │  • Transform     │            │
│   │  • 1000/batch    │              │  • Validate      │            │
│   └──────────────────┘              └──────────────────┘            │
│                                                                       │
│   Technologies: Python, Pandas, MySQL Connector                      │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         DATABASE LAYER (MySQL)                        │
│                                                                       │
│   ┌─────────────────────────────────────────────────────────┐       │
│   │  7 Normalized Tables (3NF)                              │       │
│   │  • CUSTOMER                                             │       │
│   │  • TRANSACTION                                          │       │
│   │  • TRANSACTION_FEATURES                                 │       │
│   │  • FRAUD_LABEL                                          │       │
│   │  • MODEL_METADATA                                       │       │
│   │  • ML_PREDICTION                                        │       │
│   │  • raw_transactions (staging)                           │       │
│   └─────────────────────────────────────────────────────────┘       │
│                                                                       │
│   ┌─────────────────────────────────────────────────────────┐       │
│   │  6 Analytical Views                                     │       │
│   │  • customer_transaction_stats                           │       │
│   │  • high_risk_transactions                               │       │
│   │  • fraud_patterns                                       │       │
│   │  • model_performance_summary                            │       │
│   │  • recent_predictions                                   │       │
│   │  • transaction_feature_summary                          │       │
│   └─────────────────────────────────────────────────────────┘       │
│                                                                       │
│   Performance: Indexes, Connection Pooling (5 connections)           │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      MACHINE LEARNING LAYER                           │
│                                                                       │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│   │   Extract    │───▶│    Train     │───▶│   Evaluate   │         │
│   │   Features   │    │    Models    │    │   Models     │         │
│   │              │    │              │    │              │         │
│   │ • Query DB   │    │ • SMOTE      │    │ • Precision  │         │
│   │ • Preprocess │    │ • LogReg     │    │ • Recall     │         │
│   │ • Scale      │    │ • RandomFor  │    │ • F1-Score   │         │
│   └──────────────┘    │ • GridSearch │    │ • ROC-AUC    │         │
│                       └──────────────┘    └──────────────┘         │
│                                                                       │
│   Technologies: scikit-learn, imbalanced-learn, joblib               │
│   Model Storage: ml/models/*.pkl                                     │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                        BACKEND API LAYER (Flask)                      │
│                                                                       │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │  REST API Endpoints                                      │      │
│   │                                                          │      │
│   │  POST   /predict          - Make fraud prediction       │      │
│   │  GET    /dashboard        - Get statistics & metrics    │      │
│   │  GET    /analytics        - Get analytical insights     │      │
│   │  GET    /health           - Health check                │      │
│   │                                                          │      │
│   └──────────────────────────────────────────────────────────┘      │
│                                                                       │
│   Features:                                                           │
│   • Input Validation                                                  │
│   • Parameterized Queries (SQL Injection Prevention)                 │
│   • Error Handling                                                    │
│   • CORS Support                                                      │
│   • Model Loading on Startup                                         │
│                                                                       │
│   Technologies: Flask, Flask-CORS                                     │
│   Port: 5000 (configurable)                                          │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                        FRONTEND LAYER                                 │
│                                                                       │
│   ┌─────────────────────┐          ┌─────────────────────┐          │
│   │  Prediction UI      │          │  Dashboard UI       │          │
│   │  (index.html)       │          │  (dashboard.html)   │          │
│   │                     │          │                     │          │
│   │ • Input Form        │          │ • Statistics Cards  │          │
│   │ • V1-V28 Features   │          │ • Charts (Chart.js) │          │
│   │ • Sample Data       │          │ • Model Performance │          │
│   │ • Result Display    │          │ • Recent Predictions│          │
│   │ • Risk Level        │          │ • Analytics         │          │
│   └─────────────────────┘          └─────────────────────┘          │
│                                                                       │
│   Technologies: HTML5, CSS3, JavaScript, Bootstrap 5, Chart.js       │
│   Design: Responsive, Modern, Accessible                             │
└───────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Data Ingestion Flow
```
CSV File → Validation → Staging Table → Normalization → 3NF Tables
```

### 2. ML Training Flow
```
Database → Feature Extraction → Preprocessing → SMOTE → Training → Evaluation → Model Storage
```

### 3. Prediction Flow
```
User Input → API Validation → Preprocessing → Model Prediction → Database Storage → Response
```

### 4. Dashboard Flow
```
User Request → API Query → Database Aggregation → JSON Response → Chart Rendering
```

## Component Interactions

### Database ↔ ETL
- **Direction**: Bidirectional
- **Protocol**: MySQL protocol
- **Operations**: INSERT, SELECT, UPDATE
- **Batch Size**: 1000 records

### Database ↔ ML Pipeline
- **Direction**: Bidirectional (Read for training, Write for predictions)
- **Protocol**: MySQL Connector
- **Operations**: Complex SELECT with JOINs, INSERT predictions

### ML Pipeline ↔ Backend
- **Direction**: Backend loads ML models
- **Protocol**: File system (joblib)
- **Operations**: Model loading, prediction inference

### Backend ↔ Frontend
- **Direction**: Bidirectional
- **Protocol**: HTTP/JSON
- **Operations**: POST /predict, GET /dashboard, GET /analytics

### Backend ↔ Database
- **Direction**: Bidirectional
- **Protocol**: Connection pooling
- **Operations**: All CRUD operations with parameterized queries

## Technology Stack Details

### Backend Stack
```
Python 3.8+
├── Flask 3.0.0           (Web framework)
├── Flask-CORS 4.0.0      (Cross-origin support)
├── mysql-connector       (Database driver)
├── scikit-learn 1.3.2    (ML library)
├── imbalanced-learn      (SMOTE)
├── pandas 2.1.4          (Data processing)
├── numpy 1.26.2          (Numerical computing)
└── joblib 1.3.2          (Model serialization)
```

### Frontend Stack
```
HTML5
├── Bootstrap 5.3.0       (UI framework)
├── Bootstrap Icons       (Icon library)
├── Chart.js 4.4.0        (Charting library)
└── Vanilla JavaScript    (No framework dependencies)
```

### Database Stack
```
MySQL 8.0+
├── InnoDB Engine         (Transactional support)
├── Connection Pooling    (5 connections)
├── Indexes               (B-tree, Composite)
└── Views                 (Materialized queries)
```

## Scalability Considerations

### Current Capacity
- **Transactions**: 284,807 (dataset size)
- **Predictions**: Unlimited (database constraint)
- **Concurrent Users**: ~50 (connection pool limit)
- **API Throughput**: ~100 req/sec (single instance)

### Scaling Options

**Horizontal Scaling**:
- Load balancer (Nginx)
- Multiple Flask instances
- Database replication (Master-Slave)

**Vertical Scaling**:
- Increase connection pool size
- Add database indexes
- Optimize queries
- Cache frequent queries (Redis)

**Performance Optimization**:
- Database query optimization
- Model inference caching
- Static file CDN
- Gzip compression

## Security Architecture

### Defense Layers

1. **Input Layer**: Form validation, type checking
2. **API Layer**: Parameterized queries, input sanitization
3. **Database Layer**: User permissions, prepared statements
4. **Network Layer**: CORS configuration, HTTPS (production)

### Security Features

- ✅ SQL Injection Prevention (parameterized queries)
- ✅ Input Validation (type and range checking)
- ✅ Error Handling (no sensitive data in errors)
- ✅ Connection Pooling (resource management)
- ⚠️ HTTPS (recommended for production)
- ⚠️ Authentication (not implemented - add for production)
- ⚠️ Rate Limiting (not implemented - add for production)

## Deployment Architecture

### Development
```
Single Server
├── MySQL (localhost:3306)
├── Flask (localhost:5000)
└── Frontend (served by Flask)
```

### Production (Recommended)
```
Load Balancer (Nginx)
├── Flask Instance 1
├── Flask Instance 2
└── Flask Instance N
    │
    ▼
Database Cluster
├── Master (Write)
└── Slaves (Read)
    │
    ▼
Cache Layer (Redis)
└── Frequent queries
```

## Monitoring & Logging

### Application Logs
- Request/Response logging
- Error tracking
- Performance metrics

### Database Monitoring
- Query performance
- Connection pool usage
- Table sizes

### ML Model Monitoring
- Prediction accuracy
- Model drift detection
- Feature importance tracking

---

**Architecture Version**: 1.0  
**Last Updated**: 2026-02-06  
**Status**: Production-Ready for Academic Use
