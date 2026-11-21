-- Q-03: Team statistics
-- Owner: Abdullah Eren Erentürk
-- Requirements: FR-09, NFR-03
--
-- Lists each team with its member count, completed match statistics (matches
-- played, wins, draws, losses, goals scored, goals conceded), and the average
-- rating of its members across non-hidden reviews.
-- Techniques: CTEs / subqueries, joins, conditional aggregation (CASE WHEN).
-- Parameter: none

WITH member_counts AS (
    SELECT team_id,
           COUNT(*) AS member_count
    FROM team_members
    GROUP BY team_id
),
match_stats AS (
    SELECT t.team_id,
           COUNT(*) AS matches_played,
           COALESCE(SUM(CASE
               WHEN (m.home_team_id = t.team_id AND mr.home_score > mr.away_score)
                 OR (m.away_team_id = t.team_id AND mr.away_score > mr.home_score)
               THEN 1 ELSE 0
           END), 0) AS wins,
           COALESCE(SUM(CASE
               WHEN mr.home_score = mr.away_score
               THEN 1 ELSE 0
           END), 0) AS draws,
           COALESCE(SUM(CASE
               WHEN (m.home_team_id = t.team_id AND mr.home_score < mr.away_score)
                 OR (m.away_team_id = t.team_id AND mr.away_score < mr.home_score)
               THEN 1 ELSE 0
           END), 0) AS losses,
           COALESCE(SUM(CASE
               WHEN m.home_team_id = t.team_id THEN mr.home_score
               WHEN m.away_team_id = t.team_id THEN mr.away_score
               ELSE 0
           END), 0) AS goals_scored,
           COALESCE(SUM(CASE
               WHEN m.home_team_id = t.team_id THEN mr.away_score
               WHEN m.away_team_id = t.team_id THEN mr.home_score
               ELSE 0
           END), 0) AS goals_conceded
    FROM teams t
    JOIN matches m ON m.status = 'completed'
                  AND t.team_id IN (m.home_team_id, m.away_team_id)
    JOIN match_results mr ON mr.match_id = m.match_id
    GROUP BY t.team_id
)
SELECT t.team_id,
       t.name AS team_name,
       t.city,
       s.name AS sport_name,
       u_cap.username AS captain_username,
       COALESCE(mc.member_count, 0) AS member_count,
       COALESCE(ms.matches_played, 0) AS matches_played,
       COALESCE(ms.wins, 0) AS wins,
       COALESCE(ms.draws, 0) AS draws,
       COALESCE(ms.losses, 0) AS losses,
       COALESCE(ms.goals_scored, 0) AS goals_scored,
       COALESCE(ms.goals_conceded, 0) AS goals_conceded,
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
LEFT JOIN member_counts mc ON mc.team_id = t.team_id
LEFT JOIN match_stats ms ON ms.team_id = t.team_id
ORDER BY wins DESC, goals_scored DESC, t.name;