-- cleanup the permissions from Part 1
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM time_off_anonymous;

-- setup dedicated schema API
CREATE SCHEMA api;

GRANT USAGE ON SCHEMA api TO time_off_anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT ON TABLES TO time_off_anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO time_off_anonymous;

CREATE VIEW api.users AS
SELECT 
    u.user_id,
    u.email,
    m.user_id as manager_user_id,
    m.email AS manager_email,
    u.created_at
FROM 
    public.users AS u
    LEFT JOIN public.users AS m ON u.manager_id = m.user_id
WHERE
	u.deleted_at is null;

CREATE VIEW api.vacation_balances AS
SELECT 
    EXTRACT(YEAR FROM transaction_date) AS year,
    user_id,
    SUM(amount) AS total_amount
FROM public.time_off_transactions
JOIN api.users USING (user_id)
WHERE 
    leave_type_id = (SELECT leave_type_id FROM public.leave_types WHERE label = 'vacation')
GROUP BY 
    EXTRACT(YEAR FROM transaction_date), user_id;
  
CREATE VIEW api.leave_types AS 
SELECT
	label
FROM public.leave_types
WHERE deleted_at is null;

-- approval workflow 
CREATE OR REPLACE FUNCTION api.add_user(
    email text,
    manager_id integer
) RETURNS integer AS $$
DECLARE
    new_user_id integer;
BEGIN
    -- check if email already exists
    PERFORM 1 FROM api.users WHERE users.email = add_user.email;
    IF FOUND THEN
        RAISE EXCEPTION 'The email address % is already in use', add_user.email
            USING ERRCODE = 'unique_violation';
    END IF;
    
    -- sample business logic: all employees must have manager
    IF manager_id IS NULL THEN
        RAISE EXCEPTION 'manager_id must be provided and cannot be null';
    END IF;
    
    INSERT INTO public.users (email, manager_id)
    VALUES (add_user.email, add_user.manager_id)
    RETURNING user_id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION api.get_max_vacation_days()
RETURNS INTEGER STABLE AS $$
    SELECT max_days
    FROM public.leave_types
    WHERE label = 'vacation';
$$ LANGUAGE sql SECURITY DEFINER;

CREATE TABLE public.time_off_requests (
    request_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES public.users(user_id),
    leave_type_id INT REFERENCES public.leave_types(leave_type_id),
    requested_date DATE,
    period DATERANGE,
    status TEXT CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

CREATE OR REPLACE FUNCTION api.request_time_off(
    user_id INT,
    leave_type TEXT,
    period DATERANGE
) RETURNS INTEGER AS $$
DECLARE
    v_leave_type_id INT;
    v_request_id INT;
BEGIN
    -- validate the leave type
    SELECT leave_type_id INTO v_leave_type_id 
    FROM public.leave_types 
    WHERE label = request_time_off.leave_type;
    
    IF v_leave_type_id IS NULL THEN
        RAISE EXCEPTION 'Invalid leave type: %', request_time_off.leave_type;
    END IF;

    -- check if the user ID is valid
    PERFORM 1 FROM public.users WHERE users.user_id = request_time_off.user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid user ID: %', request_time_off.user_id;
    END IF;
    
    -- insert the new time off request
    INSERT INTO public.time_off_requests (
        user_id, leave_type_id, requested_date, period, status
    ) VALUES (
        request_time_off.user_id, 
		v_leave_type_id,
		CURRENT_DATE,
		request_time_off.period,
		'pending'
    ) RETURNING request_id INTO v_request_id;
    
    RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE VIEW api.pending_requests AS
SELECT
    r.request_id,
    r.user_id,
    r.leave_type_id,
    r.requested_date,
    r.period,
    r.status,
    r.created_at,
    u.manager_id
FROM public.time_off_requests r
JOIN public.users u ON r.user_id = u.user_id
WHERE r.status = 'pending'
ORDER BY r.created_at;

CREATE OR REPLACE FUNCTION api.update_request(
    request_id INT,
    user_id INT,
    new_status TEXT
) RETURNS VOID AS $$
DECLARE
    requested_user_id INT;
    request_manager_id INT;
BEGIN
    -- validate the new status
    IF new_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Invalid status: %. Only "approved" or "rejected" are allowed', new_status;
    END IF;

    -- retrieve the request together with the users associated with it
    SELECT pr.user_id, pr.manager_id INTO requested_user_id, request_manager_id
    FROM api.pending_requests pr
    WHERE pr.request_id = update_request.request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'There''s no pending Time off request ID %', request_id;
    END IF;

    -- prevent users from self-approving their requests
    IF user_id = requested_user_id THEN
        RAISE EXCEPTION 'User cannot approve or reject their own request';
    END IF;

    -- check if the user is either the requester’s manager or the boss
    IF (request_manager_id IS NOT NULL AND user_id <> request_manager_id) THEN
		RAISE EXCEPTION 'Only the manager or The Boss can approve or reject the request';
    END IF;

    -- update the request status
    UPDATE public.time_off_requests
    SET status = new_status
    WHERE time_off_requests.request_id = update_request.request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.days_in_daterange(period daterange) RETURNS INT AS $$
	SELECT upper(period) - lower(period)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION public.create_transaction_on_approval() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' THEN
        INSERT INTO time_off_transactions (
            user_id, 
            leave_type_id, 
            transaction_date, 
            time_off_period, 
            amount
        ) VALUES (
            NEW.user_id,
            NEW.leave_type_id,
            CURRENT_DATE,
            NEW.period,
            -public.days_in_daterange(NEW.period)
        );
    END IF;
  
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


