DO $$
DECLARE
    v_boss_id int;
    v_manager_id int;
    i int;
BEGIN
    -- create "the boss"
    INSERT INTO users (email, manager_id)
    VALUES ('owner@example.com', NULL)
    RETURNING user_id INTO v_boss_id;
 
    -- setup 2 managers 
    FOR i IN 1..2 LOOP
        INSERT INTO users (email, manager_id)
        VALUES ('manager' || i || '@example.com', v_boss_id)
        RETURNING user_id INTO v_manager_id;

		-- and 5 employees for each one of them
        FOR j IN 1..5 LOOP
            INSERT INTO users (email, manager_id)
            VALUES ('employee' || (5 * (i - 1) + j) || '@example.com', v_manager_id);
        END LOOP;
    END LOOP;
END $$;

INSERT INTO leave_types (label, description, max_days) VALUES 
('vacation', 'Annual vacation leave', 25),
('sick-leave', 'Leave for health reasons', 10),
('unpaid-leave', 'Leave without pay', NULL),
('sabbatical', 'Extended leave for study or travel', NULL);

DO $$
DECLARE
    v_leave_type record;
BEGIN
    FOR v_leave_type IN SELECT * FROM leave_types WHERE label = 'vacation' LOOP
        INSERT INTO time_off_transactions (user_id, leave_type_id, transaction_date, amount, description)
        SELECT user_id, v_leave_type.leave_type_id, '2024-01-01', v_leave_type.max_days, 'Initial balance for year 2024'
        FROM users;
    END LOOP;
END $$;
