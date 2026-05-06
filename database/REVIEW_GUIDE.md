# 🎓 Review 2 Presentation Guide: Financial Fraud Detection System

This guide is designed to help you ace your Review 2 by mapping your implementation to the rubric criteria.

---

## 📅 Timeline & Scope
- **Review 2**: Weeks 4, 5, and 6.
- **Goal**: Demonstrate database proficiency using SQL commands and advanced objects.

---

## 🏆 Rubric Mapping (Criterion 1-3)

### 1️⃣ Week 4: Constraints, Aggregates & Set Ops
**File**: [01_dml_constraints_sets.sql](file:///Users/namanrai/fraud_detection_system/database/01_dml_constraints_sets.sql)

| Concept | Location / Talking Points |
| :--- | :--- |
| **Constraints** | See `SECTION A`. We demonstrate **PK, FK, UNIQUE, NOT NULL, CHECK**, and **DEFAULT** on the `fraud_alert_log` table. |
| **Aggregates** | See `SECTION F`. We use `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` with `GROUP BY` and `HAVING` to find high-activity accounts. |
| **Set Operations** | See `SECTION E`. We use `UNION ALL`, `UNION`, and simulate `INTERSECT` and `EXCEPT` (using `INNER JOIN` and `NOT IN`). |

### 2️⃣ Week 5: Complex Queries (Subqueries, Joins, Views)
**File**: [02_subqueries_joins_views.sql](file:///Users/namanrai/fraud_detection_system/database/02_subqueries_joins_views.sql)

| Concept | Location / Talking Points |
| :--- | :--- |
| **Subqueries** | See `SECTION A`. Covers **Scalar** (avg price), **Row**, **Table** (derived), and **Correlated** subqueries. Mention `EXISTS` and `IN`. |
| **Joins** | See `SECTION B`. Demonstrates **INNER, LEFT, RIGHT, CROSS**, and a **SELF JOIN** to compare customer risk scores. |
| **Views** | See `SECTION C`. Includes **Simple** (active model), **Complex** (risk profile), **Updatable** (alerts), and **Nested** views. |

### 3️⃣ Week 6: PL/SQL (Functions, Triggers, Cursors, Exceptions)
**File**: [03_functions_triggers_cursors_exceptions.sql](file:///Users/namanrai/fraud_detection_system/database/03_functions_triggers_cursors_exceptions.sql)

| Concept | Location / Talking Points |
| :--- | :--- |
| **Functions** | `SECTION A`. `fn_classify_risk_tier` uses business logic to map scores to labels (High/Medium/Low). |
| **Triggers** | `SECTION B`. 4 Triggers: `BEFORE INSERT` (validation), `AFTER INSERT` (audit), `AFTER UPDATE` (auto-alerts), `BEFORE DELETE` (integrity). |
| **Cursors** | `SECTION C`. `sp_bulk_classify_customers` uses an explicit cursor with a `LOOP` and `FETCH`. |
| **Exceptions** | `SECTION D`. Uses `DECLARE HANDLER` for `NOT FOUND` and `SQLEXCEPTION`, and `SIGNAL SQLSTATE` for custom errors. |

---

## 📖 Report Guidance (Chapters 1-3)

- **Chapter 1: Introduction**: Mention the use of the Credit Card Fraud dataset and the goal of 3NF normalization.
- **Chapter 2: System Analysis**: Discuss the ER diagram (8 tables) and how the schema supports both transactions and ML versioning.
- **Chapter 3: Implementation**: Explain that the system is full-stack (Flask API + Chart.js Dashboard) but the core logic resides in optimized SQL objects.

---

## 🚀 Presentation Tips
1.  **Explain the "Why"**: Don't just show `JOIN`. Say: *"We use a LEFT JOIN to ensure no transaction is missed even if it doesn't have a fraud label yet."*
2.  **Show the Audit Log**: Run `SELECT * FROM audit_log;` to show that your triggers are actively monitoring the system.
3.  **Run a Procedure**: Call `CALL sp_bulk_classify_customers(@p, @e);` to show the cursor-driven logic in action.
