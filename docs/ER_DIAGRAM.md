# Entity-Relationship Diagram
## Fraud Detection System Database Schema (3NF)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CUSTOMER (Dimension)                            │
├─────────────────────────────────────────────────────────────────────────┤
│ PK  customer_id          INT                                            │
│     created_at           TIMESTAMP                                      │
│     total_transactions   INT                                            │
│     total_fraud_count    INT                                            │
│     risk_score           DECIMAL(5,4)                                   │
│     last_transaction_time INT                                           │
└──────────────────┬──────────────────────────────────────────────────────┘
                   │
                   │ 1:N
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRANSACTION (Fact)                              │
├─────────────────────────────────────────────────────────────────────────┤
│ PK  transaction_id       INT                                            │
│ FK  customer_id          INT  ───────────────────┐                      │
│     time                 INT                     │                      │
│     amount               DECIMAL(10,2)           │                      │
│     created_at           TIMESTAMP               │                      │
└──────────┬───────────────┬───────────────────────┼──────────────────────┘
           │               │                       │
           │ 1:N           │ 1:1                   │ 1:N
           │               │                       │
           ▼               ▼                       ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐
│ TRANSACTION_     │  │  FRAUD_LABEL     │  │   ML_PREDICTION          │
│ FEATURES         │  │                  │  │                          │
├──────────────────┤  ├──────────────────┤  ├──────────────────────────┤
│ PK feature_id    │  │ PK label_id      │  │ PK prediction_id         │
│ FK transaction_id│  │ FK transaction_id│  │ FK transaction_id        │
│    feature_name  │  │    is_fraud      │  │ FK model_id              │
│    feature_value │  │    labeled_at    │  │    predicted_class       │
└──────────────────┘  └──────────────────┘  │    probability_score     │
                                            │    predicted_at          │
                                            └────────┬─────────────────┘
                                                     │
                                                     │ N:1
                                                     │
                                                     ▼
                                            ┌──────────────────────────┐
                                            │  MODEL_METADATA          │
                                            ├──────────────────────────┤
                                            │ PK model_id              │
                                            │    model_name            │
                                            │    version               │
                                            │    trained_at            │
                                            │    metrics (JSON)        │
                                            │    hyperparameters (JSON)│
                                            │    is_active             │
                                            └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    raw_transactions (Staging)                           │
├─────────────────────────────────────────────────────────────────────────┤
│ PK  id                   INT                                            │
│     Time                 INT                                            │
│     V1...V28             DECIMAL(10,6)  [28 PCA features]              │
│     Amount               DECIMAL(10,2)                                  │
│     Class                TINYINT                                        │
│     imported_at          TIMESTAMP                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Relationships Summary

| Relationship | Type | Description |
|--------------|------|-------------|
| CUSTOMER → TRANSACTION | 1:N | One customer has many transactions |
| TRANSACTION → TRANSACTION_FEATURES | 1:N | One transaction has 28 features (V1-V28) |
| TRANSACTION → FRAUD_LABEL | 1:1 | One transaction has one fraud label |
| TRANSACTION → ML_PREDICTION | 1:N | One transaction can have multiple predictions |
| MODEL_METADATA → ML_PREDICTION | 1:N | One model generates many predictions |

## Key Constraints

- **Primary Keys**: All tables have auto-increment integer PKs
- **Foreign Keys**: CASCADE on delete for referential integrity
- **Unique Constraints**: 
  - FRAUD_LABEL.transaction_id (one label per transaction)
  - TRANSACTION_FEATURES(transaction_id, feature_name) (no duplicate features)
  - MODEL_METADATA(model_name, version) (unique model versions)

## Indexes

- Customer: risk_score, last_transaction_time
- Transaction: customer_id + time (composite), amount, time
- Transaction Features: transaction_id + feature_name (composite)
- Fraud Label: is_fraud
- ML Prediction: transaction_id, model_id, predicted_class, probability_score

## Normalization (3NF)

✅ **1NF**: All attributes are atomic
✅ **2NF**: No partial dependencies (all non-key attributes depend on entire PK)
✅ **3NF**: No transitive dependencies (non-key attributes depend only on PK)

## Design Decisions

1. **Synthetic Customers**: Dataset lacks customer IDs, so we create synthetic customers
2. **EAV Pattern**: TRANSACTION_FEATURES uses Entity-Attribute-Value for flexibility
3. **Model Versioning**: MODEL_METADATA tracks multiple model versions
4. **Staging Table**: raw_transactions preserves original CSV structure
5. **JSON Columns**: Flexible storage for metrics and hyperparameters
