-- Table: match_results
-- Owner: Ege Kucuk
-- Scores recorded after a match.
-- Requirements: FR-09, FR-12
-- Depends on: matches, users

CREATE TABLE match_results (
    match_id      INTEGER PRIMARY KEY REFERENCES matches(match_id) ON DELETE CASCADE, -- One result per match
    home_score    SMALLINT NOT NULL CHECK (home_score >= 0),
    away_score    SMALLINT NOT NULL CHECK (away_score >= 0),
    recorded_by   INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    recorded_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_result_timestamps CHECK (updated_at >= recorded_at)
);

CREATE INDEX idx_match_results_recorded_by ON match_results (recorded_by)
    WHERE recorded_by IS NOT NULL;
