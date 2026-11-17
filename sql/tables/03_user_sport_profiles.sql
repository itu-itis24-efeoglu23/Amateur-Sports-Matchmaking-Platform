-- Table: user_sport_profiles
-- Owner: Furkan Efeoğlu
-- A user's skill level and preferred position in one sport.
-- Resolves the many-to-many relationship between users and sports.
-- Requirements: FR-3
-- Depends on: 01_users.sql, 02_sports.sql

CREATE TABLE user_sport_profiles (
    user_id             INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    sport_id            INTEGER     NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    skill_level         SMALLINT    NOT NULL CHECK (skill_level BETWEEN 1 AND 5),  -- 1 = beginner, 5 = expert
    preferred_position  VARCHAR(30),
    updated_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, sport_id)   -- one profile per user per sport
);
