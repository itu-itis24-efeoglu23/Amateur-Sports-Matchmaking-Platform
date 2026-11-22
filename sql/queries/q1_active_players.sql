-- Q-01: Active players of a sport
-- Owner: Furkan Efeoğlu
-- Requirements: FR-03, FR-12
--
-- Lists players who attended at least 3 matches of a given sport in the last
-- 30 days, with their skill level in that sport and the average rating they
-- received from other players (hidden reviews excluded).
-- Techniques: 5-table join, GROUP BY ... HAVING, correlated subquery.
-- Parameter: %(sport_id)s (passed by the Flask app with psycopg)

SELECT u.username,
       p.skill_level,
       COUNT(*) AS matches_played,
       ROUND((SELECT AVG(r.rating)
              FROM player_reviews r
              WHERE r.reviewed_id = u.user_id
                AND NOT r.is_hidden), 2) AS avg_rating   -- hidden reviews are not counted (FR-21)
FROM users u
JOIN user_sport_profiles p ON p.user_id = u.user_id
                          AND p.sport_id = %(sport_id)s
JOIN match_participants mp ON mp.user_id = u.user_id
                          AND mp.status = 'attended'
JOIN matches m ON m.match_id = mp.match_id
JOIN venues v  ON v.venue_id = m.venue_id
              AND v.sport_id = p.sport_id
WHERE m.start_time >= NOW() - INTERVAL '30 days'
GROUP BY u.user_id, u.username, p.skill_level
HAVING COUNT(*) >= 3
ORDER BY matches_played DESC, avg_rating DESC NULLS LAST;
