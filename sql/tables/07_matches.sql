-- Table: matches
-- Owner: Ege Kucuk
-- Match details, teams, time and venue.
-- Requirements: FR-10, FR-11, FR-12, FR-20, NFR-04
-- Depends on: users, venues, teams

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE matches (
    match_id        SERIAL PRIMARY KEY,
    venue_id        INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE RESTRICT,
    organizer_id    INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    home_team_id    INTEGER REFERENCES teams(team_id) ON DELETE SET NULL,  -- a deleted team's matches stay in the history
    away_team_id    INTEGER REFERENCES teams(team_id) ON DELETE SET NULL,
    title           VARCHAR(120) NOT NULL CHECK (LENGTH(TRIM(title)) > 0),
    start_time      TIMESTAMP NOT NULL,
    end_time        TIMESTAMP NOT NULL,
    capacity        SMALLINT NOT NULL CHECK (capacity >= 2),
    min_skill       SMALLINT NOT NULL CHECK (min_skill BETWEEN 1 AND 5),
    max_skill       SMALLINT NOT NULL CHECK (max_skill BETWEEN 1 AND 5),
    status          VARCHAR(10) NOT NULL DEFAULT 'open'
                    CHECK (status IN ('pending', 'open', 'full', 'completed', 'cancelled')),
    CONSTRAINT ck_match_time CHECK (end_time > start_time),
    CONSTRAINT ck_match_skill_range CHECK (min_skill <= max_skill),
    CONSTRAINT ck_match_distinct_teams CHECK (home_team_id IS NULL OR home_team_id <> away_team_id),
    CONSTRAINT ck_pending_requires_teams CHECK (status <> 'pending' OR home_team_id IS NOT NULL),
    -- Stop two matches from using the same venue at overlapping times.
    CONSTRAINT ex_match_venue_schedule EXCLUDE USING gist (
        venue_id WITH =,
        tsrange(start_time, end_time, '[)') WITH &&
    ) WHERE (status <> 'cancelled')
);

CREATE INDEX idx_matches_status_start ON matches (status, start_time);
CREATE INDEX idx_matches_organizer ON matches (organizer_id);
CREATE INDEX idx_matches_home_team ON matches (home_team_id) WHERE home_team_id IS NOT NULL;
CREATE INDEX idx_matches_away_team ON matches (away_team_id) WHERE away_team_id IS NOT NULL;
