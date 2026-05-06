# Chapter 3 Demo & Viva Guide
 
This guide will help you run and explain the Chapter 3 queries for your Financial Fraud Detection System.

## 1. Preparation: Start the MySQL Server
Before anything else, the database must be running:
```bash
sudo /usr/local/mysql/support-files/mysql.server start
```
*(Enter your Mac password if prompted)*

## 2. Using MySQL Workbench
To show this in a professional UI like Workbench:

1. **Open Workbench**: Ensure your connection to `localhost` is active.
2. **Open the Script**: File > Open SQL Script > Select `database/chapter3_demo.sql`.
3. **Execute ALL**: Click the **Lightning Bolt** icon (without a cursor) to run everything and create the tables/data.
4. **Execute ONE**: Highlight a specific query (e.g., a Join) and click the **Lightning Bolt with a Cursor** to show just that result.
5. **Schema Tree**: In the left sidebar, click **Refresh** on 'Schemas' to see `fraud_db`, its tables, views, and triggers.

## 3. How to Show Specific Objects (Viva Questions)

### A. How to Show a Trigger in Action
If the invigilator says: *"Show me the `trg_update_fraud_count` trigger,"* follow these steps:

1. **Show the Trigger Code**:
   ```sql
   SHOW CREATE TRIGGER trg_update_fraud_count;
   ```
2. **Demonstrate behavior**:
   Insert a new fraud label and show that the customer's `total_fraud_count` increases automatically.
   ```sql
   -- 1. Check current count
   SELECT total_fraud_count FROM CUSTOMER WHERE customer_id = 1;
   
   -- 2. Insert fraud label (Trigger fires here)
   INSERT INTO FRAUD_LABEL (transaction_id, is_fraud) VALUES (5, 1);
   
   -- 3. Show updated count
   SELECT total_fraud_count FROM CUSTOMER WHERE customer_id = 1;
   ```

### B. How to Show a Cursor
If the invigilator says: *"Show me the cursor implementation,"* follow these steps:

1. **Explanation**: *"A cursor allows us to process rows one by one in a loop, rather than as a set. This is useful for complex reporting where we need to perform logic on each individual record."*
2. **Show the Procedure**:
   ```sql
   SHOW CREATE PROCEDURE demo_fraud_cursor;
   ```
3. **Run the Cursor**:
   ```sql
   CALL demo_fraud_cursor();
   ```

### C. How to Show a View
If the invigilator says: *"Show me the `fraud_transactions` view,"* follow these steps:

1. **Show structure**:
   ```sql
   DESCRIBE fraud_transactions;
   ```
2. **Query the view**:
   ```sql
   SELECT * FROM fraud_transactions;
   ```

## 4. Key Definitions for Viva
- **Constraint**: A rule applied to a column (like `NOT NULL` or `CHECK`) to ensure data integrity.
- **Aggregate Function**: A function that performs a calculation on a set of values (like `SUM`, `AVG`, `COUNT`).
- **Join**: Combining rows from two or more tables based on a related column between them.
- **Subquery**: A query nested inside another query (e.g., using `SELECT` in a `WHERE` clause).
- **Set Operations**: Functions like `UNION`, `INTERSECT`, and `EXCEPT` that combine results from multiple queries.
