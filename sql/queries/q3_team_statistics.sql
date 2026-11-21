-- Q-03: Team statistics
-- Owner: Abdullah Eren Erentürk
-- Requirements: FR-09, NFR-03
--
-- Lists each team with its member count, completed match statistics (matches
-- played, wins, draws, losses, goals scored, goals conceded), and the average
-- rating of its members across non-hidden reviews.
-- Techniques: multiple joins, conditional aggregation (CASE WHEN), nested subquery.
-- Parameter: none

SELECT t.team_id,
       t.name AS team_name,
       t.city,
       s.name AS sport_name,
       u_cap.username AS captain_username,
       COUNT(DISTINCT tm.user_id) AS member_count,
       COUNT(DISTINCT m.match_id) FILTER (WHERE m.status = 'completed') AS matches_played,
       COALESCE(SUM(CASE
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND ((m.home_team_id = t.team_id AND mr.home_score > mr.away_score)
                  OR (m.away_team_id = t.team_id AND mr.away_score > mr.home_score))
           THEN 1 ELSE 0
       END), 0) AS wins,
       COALESCE(SUM(CASE
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND mr.home_score = mr.away_score
           THEN 1 ELSE 0
       END), 0) AS draws,
       COALESCE(SUM(CASE
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND ((m.home_team_id = t.team_id AND mr.home_score < mr.away_score)
                  OR (m.away_team_id = t.team_id AND mr.away_score < mr.home_score))
           THEN 1 ELSE 0
       END), 0) AS losses,
       COALESCE(SUM(CASE
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND m.home_team_id = t.team_id THEN mr.home_score
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND m.away_team_id = t.team_id THEN mr.away_score
           ELSE 0
       END), 0) AS goals_scored,
       COALESCE(SUM(CASE
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND m.home_team_id = t.team_id THEN mr.away_score
           WHEN m.status = 'completed' AND mr.match_id IS NOT NULL
                AND m.away_team_id = t.team_id THEN mr.home_score
           ELSE 0
       END), 0) AS goals_conceded,
       ROUND((
           SELECT AVG(r.rating)
           FROM player_reviews r
           WHERE NOT r.is_hidden
             AND r.reviewed_id IN (
                 SELECT tm_sub.user_id
                 FROM team_members tm_sub
                 WHERE tm_sub.team_id = t.team_id
             )
       ), 2) AS avg_member_rating
FROM teams t
JOIN sports s ON s.sport_id = t.sport_id
JOIN users u_cap ON u_cap.user_id = t.captain_id
LEFT JOIN team_members tm ON tm.team_id = t.team_id
LEFT JOIN matches m ON m.status = 'completed'
                   AND t.team_id IN (m.home_team_id, m.away_team_id)
LEFT JOIN match_results mr ON mr.match_id = m.match_id
GROUP BY t.team_id, t.name, t.city, s.name, u_cap.username
ORDER BY wins DESC, goals_scored DESC, t.name;