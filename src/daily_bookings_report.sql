-- Daily bookings per route for the last 7 days
-- Requirements:
--  - Day-level buckets based on booking_time
--  - Only the last 7 days, including today
--  - Exclude cancelled bookings
--  - Exclude rows with NULL route_id
--  - Join to dim_routes to get route_name
--  - Use a sargable (index-friendly) date predicate on booking_time

SELECT
    fb.route_id,
    dr.route_name,
    -- Day-level bucket
    DATE_TRUNC('day', fb.booking_time)::date AS booking_date,
    COUNT(*) AS booking_count
FROM fact_bookings AS fb
JOIN dim_routes AS dr
  ON dr.route_id = fb.route_id              -- INNER JOIN excludes NULL route_id rows
WHERE
    -- Sargable date range: last 7 days including today
    -- Uses booking_time directly, without wrapping it in a function
    fb.booking_time >= CURRENT_DATE - INTERVAL '6 days'  -- start of 7‑day window
    AND fb.booking_time < CURRENT_DATE + INTERVAL '1 day' -- up to (but not incl.) tomorrow

    -- Exclude cancelled bookings
    -- Adjust the column/value here if your schema differs (e.g. booking_status, is_cancelled, etc.)
    AND fb.status <> 'cancelled'

    -- Explicitly exclude NULL route_id for clarity (also enforced by the JOIN)
    AND fb.route_id IS NOT NULL
GROUP BY
    fb.route_id,
    dr.route_name,
    DATE_TRUNC('day', fb.booking_time)::date
ORDER BY
    booking_date,
    dr.route_name;
