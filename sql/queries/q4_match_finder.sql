-- Q-04: Match finder
-- Owner: Ege Kucuk
-- Requirements: FR-11, NFR-07
-- Find open matches in the user's city with free spots and a matching skill level.
-- Parameter: %(user_id)s

SELECT m.match_id,
       m.title,
       v.name AS venue_name,
       v.city,
       s.name AS sport_name,
       m.start_time,
       m.end_time,
       m.capacity,
       COUNT(mp.user_id) AS participant_count,
       m.capacity - COUNT(mp.user_id) AS free_spots
FROM matches m
JOIN venues v ON v.venue_id = m.venue_id
JOIN sports s ON s.sport_id = v.sport_id
JOIN users u ON u.user_id = %(user_id)s
JOIN user_sport_profiles usp ON usp.user_id = u.user_id
                            AND usp.sport_id = v.sport_id
LEFT JOIN match_participants mp ON mp.match_id = m.match_id
WHERE m.status = 'open'
  AND m.start_time > CURRENT_TIMESTAMP
  AND v.city = u.city
  AND usp.skill_level BETWEEN m.min_skill AND m.max_skill
  AND NOT EXISTS (
      SELECT 1 FROM match_participants mine
      WHERE mine.match_id = m.match_id AND mine.user_id = u.user_id
  )
  AND (
      m.home_team_id IS NULL
      OR EXISTS (
          SELECT 1 FROM team_members tm
          WHERE tm.user_id = u.user_id
            AND tm.team_id IN (m.home_team_id, m.away_team_id)
      )
  )
GROUP BY m.match_id, v.venue_id, v.name, v.city, s.sport_id, s.name
HAVING COUNT(mp.user_id) < m.capacity
ORDER BY m.start_time, free_spots DESC;
