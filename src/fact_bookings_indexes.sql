-- Index(es) to support efficient daily bookings report on fact_bookings
-- Goal: enable an index scan (or index‑only scan) for range queries on booking_time
-- and grouping by route, while filtering out cancelled bookings.

-- 1) Core composite index on (booking_time, route_id) for generic date‑range queries
-- This supports:
--   - WHERE booking_time BETWEEN ... AND ...
--   - JOIN to dim_routes via route_id
--   - GROUP BY day(route_id, booking_time)

CREATE INDEX IF NOT EXISTS idx_fact_bookings_booking_time_route
    ON fact_bookings (booking_time, route_id);


-- 2) Optional, more targeted partial index tailored to this report pattern
-- Uncomment if you want a smaller, even more efficient index specifically
-- for non‑cancelled bookings. The query in daily_bookings_report.sql matches
-- this predicate exactly, so the planner can use this partial index.
--
-- CREATE INDEX IF NOT EXISTS idx_fact_bookings_booktime_route_not_cancelled
--     ON fact_bookings (booking_time, route_id)
--     WHERE status <> 'cancelled' AND route_id IS NOT NULL;


-- 3) Example: verify with EXPLAIN that the new index is used
-- (Run this manually in your SQL client after creating the index.)
--
-- EXPLAIN ANALYZE
-- SELECT
--     fb.route_id,
--     dr.route_name,
--     DATE_TRUNC('day', fb.booking_time)::date AS booking_date,
--     COUNT(*) AS booking_count
-- FROM fact_bookings AS fb
-- JOIN dim_routes AS dr
--   ON dr.route_id = fb.route_id
-- WHERE
--     fb.booking_time >= CURRENT_DATE - INTERVAL '6 days'
--     AND fb.booking_time < CURRENT_DATE + INTERVAL '1 day'
--     AND fb.status <> 'cancelled'
--     AND fb.route_id IS NOT NULL
-- GROUP BY
--     fb.route_id,
--     dr.route_name,
--     DATE_TRUNC('day', fb.booking_time)::date
-- ORDER BY
--     booking_date,
--     dr.route_name;