# Solution Steps

1. Identify the business requirements for the report: daily booking counts per route for the last 7 days, excluding cancelled bookings and NULL route_id rows, and including a human-readable route_name from dim_routes.

2. Decide on the correct time window logic: use a 7-day window including today by filtering booking_time between (CURRENT_DATE - INTERVAL '6 days') and (CURRENT_DATE + INTERVAL '1 day'), using a half-open range [start, end) so it is inclusive of the start day and exclusive of tomorrow.

3. Ensure the date predicate on booking_time is sargable by avoiding functions on the column in the WHERE clause; instead, put any date math on constants (e.g., CURRENT_DATE - INTERVAL '6 days') and compare booking_time directly with >= and < operators.

4. Construct the main SELECT query: select route_id, route_name, a day-level bucket derived from booking_time (DATE_TRUNC('day', booking_time)::date), and COUNT(*) as booking_count.

5. Join fact_bookings (aliased as fb) to dim_routes (aliased as dr) with an INNER JOIN on route_id so that bookings with NULL route_id are automatically excluded and each booking is associated with its route_name.

6. Add WHERE clause predicates: (a) the sargable booking_time range for the last 7 days; (b) a filter to exclude cancelled bookings (e.g., fb.status <> 'cancelled'); and optionally (c) an explicit fb.route_id IS NOT NULL condition for clarity, even though the INNER JOIN already enforces it.

7. GROUP BY route-level and day-level dimensions: fb.route_id, dr.route_name, and the DATE_TRUNC('day', fb.booking_time)::date expression used for the bucketed date, so that the COUNT(*) aggregates correctly per route per day.

8. ORDER the results in a sensible report order, e.g., first by booking_date, then by route_name, to make the report easy to read.

9. Design an index on fact_bookings that matches the common access pattern: queries filter primarily on booking_time and group by route_id, so create a composite B-tree index on (booking_time, route_id) to efficiently support the range scan and join operations.

10. Implement the index with CREATE INDEX IF NOT EXISTS idx_fact_bookings_booking_time_route ON fact_bookings (booking_time, route_id); so it can be safely re-run and will enable the planner to use an index or index-only scan when the date-range predicate on booking_time is applied.

11. Optionally, design and (if desired) create a more selective partial index for this specific report workload, such as CREATE INDEX ... ON fact_bookings (booking_time, route_id) WHERE status <> 'cancelled' AND route_id IS NOT NULL; to index only relevant rows and further reduce I/O for the report.

12. Run EXPLAIN or EXPLAIN ANALYZE on the improved SELECT query after creating the index, and verify that the query plan shows an Index Scan or Index Only Scan on fact_bookings instead of a Sequential Scan, confirming that the predicate is now sargable and the index is being used.

13. Compare the estimated cost and, ideally, the execution time (via EXPLAIN ANALYZE) of the original non-sargable query versus the new query to observe the reduction in query cost and runtime on the large fact_bookings table.

