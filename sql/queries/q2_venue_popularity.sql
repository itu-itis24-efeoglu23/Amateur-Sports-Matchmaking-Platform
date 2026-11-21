-- Q-02: Venue popularity
-- Owner: Nurhan Aliyev
-- Completed matches, hours booked and estimated revenue per venue.
-- Techniques: CTE, joins, aggregation and window function.
-- Parameters: none

WITH venue_statistics AS (
    SELECT
        v.venue_id,
        v.sport_id,
        v.name AS venue_name,
        v.city,
        v.hourly_price,
        COUNT(m.match_id) AS completed_matches,
        COALESCE(
            SUM(
                EXTRACT(EPOCH FROM (m.end_time - m.start_time))
                / 3600.0
            ),
            0
        ) AS hours_booked
    FROM venues v
    LEFT JOIN matches m
        ON m.venue_id = v.venue_id
        AND m.end_time <= CURRENT_TIMESTAMP
        AND m.status NOT IN ('pending', 'cancelled')
    GROUP BY
        v.venue_id,
        v.sport_id,
        v.name,
        v.city,
        v.hourly_price
)
SELECT
    vs.venue_id,
    vs.venue_name,
    s.name AS sport_name,
    vs.city,
    vs.completed_matches,
    ROUND(vs.hours_booked, 2) AS hours_booked,
    ROUND(
        vs.hours_booked * vs.hourly_price,
        2
    ) AS estimated_revenue,
    RANK() OVER (
        PARTITION BY vs.sport_id
        ORDER BY vs.completed_matches DESC
    ) AS rank_within_sport
FROM venue_statistics vs
JOIN sports s
    ON s.sport_id = vs.sport_id
ORDER BY
    vs.sport_id,
    rank_within_sport,
    vs.venue_id;