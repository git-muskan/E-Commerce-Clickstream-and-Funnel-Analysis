use mydb;

-- Step 1: Create base event table (the data is loaded using Python from CSV dataset)
CREATE TABLE events_ecomm (
    event_time DATETIME,
    event_type VARCHAR(50),
    product_id VARCHAR(100),
    category_id VARCHAR(100),
    category_code VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10,2),
    user_id VARCHAR(100),
    user_session VARCHAR(100)
);

-- Check total events loaded
SELECT COUNT(*) FROM EVENTS_ECOMM;

-- Step 2: Generate session-level funnel steps
CREATE TABLE session_funnel AS
SELECT
  user_session,
  MIN(CASE WHEN event_type = 'view'     THEN event_time END) AS view_time,
  MIN(CASE WHEN event_type = 'cart'     THEN event_time END) AS cart_time,
  MIN(CASE WHEN event_type = 'purchase' THEN event_time END) AS purchase_time
FROM (
  SELECT *
  FROM events_ecomm
  WHERE event_type IN ('view', 'cart', 'purchase')
) AS filtered_events
GROUP BY user_session;
select * from session_funnel LIMIT 2;

-- Step 3: Add time deltas and flags
SELECT 
  *,
  CASE WHEN view_time IS NOT NULL THEN 1 ELSE 0 END AS viewed,
  CASE WHEN cart_time IS NOT NULL THEN 1 ELSE 0 END AS carted,
  CASE WHEN purchase_time IS NOT NULL THEN 1 ELSE 0 END AS purchased,
  TIMESTAMPDIFF(MINUTE, view_time, cart_time) AS time_to_cart,
  TIMESTAMPDIFF(MINUTE, view_time, purchase_time) AS time_to_purchase
FROM session_funnel;

-- Step 4: Consolidating and creating the final funnel
CREATE TABLE session_funnel_final AS
SELECT
  sf.user_session,
  sf.view_time,
  sf.cart_time,
  sf.purchase_time,
  CASE WHEN sf.view_time IS NOT NULL THEN 1 ELSE 0 END AS viewed,
  CASE WHEN sf.cart_time IS NOT NULL THEN 1 ELSE 0 END AS carted,
  CASE WHEN sf.purchase_time IS NOT NULL THEN 1 ELSE 0 END AS purchased,
  TIMESTAMPDIFF(MINUTE, sf.view_time, sf.cart_time) AS time_to_cart,
  TIMESTAMPDIFF(MINUTE, sf.view_time, sf.purchase_time) AS time_to_purchase,
  ce.category_code,
  ce.brand,
  ce.price
FROM session_funnel sf
LEFT JOIN (
  SELECT e.*
  FROM events_ecomm e
  JOIN (
    SELECT user_session, MIN(event_time) AS first_view_time
    FROM events_ecomm
    WHERE event_type = 'view'
    GROUP BY user_session
  ) fv ON e.user_session = fv.user_session AND e.event_time = fv.first_view_time
  WHERE e.event_type = 'view'
) ce ON sf.user_session = ce.user_session;

select * from session_funnel limit 5;


