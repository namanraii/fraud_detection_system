USE fraud_db;

-- 1. Check Triggers
SHOW TRIGGERS;

-- 2. Check Functions
SELECT routine_name FROM information_schema.routines WHERE routine_type = 'FUNCTION' AND routine_schema = 'fraud_db';

-- 3. Check Stored Procedures
SELECT routine_name FROM information_schema.routines WHERE routine_type = 'PROCEDURE' AND routine_schema = 'fraud_db';
