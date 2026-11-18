-- Q5: Top-rated players
-- Owner: Baturalp Taha Yılmaz
-- Requirements: FR-15
--
-- Lists, for every sport, the players whose average received rating in that
-- sport is above the average of all ratings given in that sport. A player
-- needs at least 3 reviews in the sport to be listed. The sport of a review
-- is the sport of the venue where the match was played.
-- Techniques: 5-table join, GROUP BY ... HAVING, correlated subquery on the
-- outer group's sport (used in SELECT and in HAVING).
-- Parameter: none

SELECT s.name AS sport,
       u.username,
       u.city,
       COUNT(*) AS review_count,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       ROUND((SELECT AVG(r2.rating)
              FROM player_reviews r2
              JOIN matches m2 ON m2.match_id = r2.match_id
              JOIN venues v2  ON v2.venue_id = m2.venue_id
              WHERE v2.sport_id = s.sport_id), 2) AS sport_avg
FROM player_reviews r
JOIN users u   ON u.user_id = r.reviewed_id
JOIN matches m ON m.match_id = r.match_id
JOIN venues v  ON v.venue_id = m.venue_id
JOIN sports s  ON s.sport_id = v.sport_id
GROUP BY s.sport_id, s.name, u.user_id, u.username, u.city
HAVING COUNT(*) >= 3
   AND AVG(r.rating) > (SELECT AVG(r2.rating)
                        FROM player_reviews r2
                        JOIN matches m2 ON m2.match_id = r2.match_id
                        JOIN venues v2  ON v2.venue_id = m2.venue_id
                        WHERE v2.sport_id = s.sport_id)
ORDER BY s.name, avg_rating DESC, review_count DESC;
