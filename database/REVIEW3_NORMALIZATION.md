# 🎓 Review 3 Normalization Guide & Dependencies

This guide provides the required explanations and proofs for the **Normalization (Dependencies & Anomalies)** rubric criteria. Use this document during your presentation to answer questions about your database design.

---

## 1️⃣ Unnormalized Form (UNF) & Anomalies

Imagine if we stored all our data in a single massive flat table `RAW_DATA_DUMP` which looked like this:

`RAW_DATA_DUMP (transaction_id, time, amount, customer_id, customer_risk_score, is_fraud, V1, V2 ... V28, model_name, fraud_probability)`

If we designed the system this way, we would encounter three major database anomalies:

1.  **Insertion Anomaly**: We cannot add a new `CUSTOMER` (along with their `risk_score`) to the database until they make a `TRANSACTION`, because `transaction_id` would be the primary key and cannot be NULL.
2.  **Update Anomaly**: If a customer's `risk_score` changes, we would have to update thousands of individual transaction rows where that `customer_id` appears. If we miss even one, the database becomes inconsistent.
3.  **Deletion Anomaly**: If we purge old transactions to save space, and we delete the only transaction a specific customer ever made, we accidentally lose all the customer's data (like their `risk_score`) along with it.

---

## 2️⃣ Functional Dependencies

By analyzing the data, we identify the following **Functional Dependencies (FD)**:

*   **FD1**: `transaction_id` → `customer_id`, `time`, `amount`
*   **FD2**: `transaction_id` → `is_fraud`  *(Every transaction has exactly one definitive fraud label)*
*   **FD3**: `customer_id` → `risk_score`, `last_transaction_time` *(A customer's identity uniquely defines their risk score)*
*   **FD4**: `transaction_id`, `feature_name` → `feature_value` *(To get a specific PCA value like V1, we need both the exact transaction and the feature name)*
*   **FD5**: `model_id` → `model_name`, `version`, `is_active`
*   **FD6**: `prediction_id` → `transaction_id`, `model_id`, `predicted_class`, `probability_score`

---

## 3️⃣ Normalization Progression (Up to 3NF)

Our final schema natively satisfies all requirements up to the Third Normal Form (3NF) and Boyce-Codd Normal Form (BCNF).

### First Normal Form (1NF)
**Rule**: All attributes must be atomic (indivisible) and there are no repeating groups.
**Our Implementation**: 
- `transaction_id`, `amount`, `is_fraud` are all scalar values.
- Instead of having an array of PCA features `[V1, V2...V28]` stored as a single string inside `TRANSACTION`, we successfully decomposed it into the `TRANSACTION_FEATURES` table where each string combination of `(transaction_id, feature_name)` stores exactly one scalar atomic `feature_value`.

### Second Normal Form (2NF)
**Rule**: Must be in 1NF, and no non-prime attribute is dependent on any proper subset of any candidate key.
**Our Implementation**:
- In `TRANSACTION_FEATURES`, the composite primary key is `(transaction_id, feature_name)`. The `feature_value` depends on the **ENTIRE** composite key, not just `transaction_id` or just `feature_name`. Thus, there are no partial dependencies.
- `TRANSACTION` has a single-column primary key (`transaction_id`), so partial dependencies are impossible by definition. 

### Third Normal Form (3NF) / BCNF
**Rule**: Must be in 2NF, and there are no transitive dependencies (Non-key attributes cannot depend on other non-key attributes).
**Our Implementation**:
- If we stored `customer_risk_score` in the `TRANSACTION` table, it would depend on `customer_id`, but `customer_id` is not the Primary Key of `TRANSACTION` (it is a Foreign Key). This is a transitive dependency (`transaction_id` → `customer_id` → `customer_risk_score`).
- **Resolution**: We completely separated this into the `CUSTOMER` table. The `CUSTOMER` table has `customer_id` as the Primary Key and `risk_score` as the attribute. 
- In our schema, **every determinant is a candidate key**. Therefore, our database is strictly compliant with **BCNF**.

---

## 💡 Quick QA Checklist for the Reviewer

- **Examiner**: *Why didn't you just add `is_fraud` as a column in the `TRANSACTION` table to save a join?*
  - **You**: While `transaction_id → is_fraud` is a valid functional dependency, keeping labels in `FRAUD_LABEL` allows us to isolate the raw ingest stream from the labeling stream. Normalization is not just about avoiding redundancy, but also enforcing distinct entity boundaries.

- **Examiner**: *Can you show me an example of an anomaly?*
  - **You**: Yes, if we didn't have a `CUSTOMER` table, updating a customer's `risk_score` would require a mass-update query over thousands of `TRANSACTION` rows. With 3NF, I only update 1 row in the `CUSTOMER` table.
