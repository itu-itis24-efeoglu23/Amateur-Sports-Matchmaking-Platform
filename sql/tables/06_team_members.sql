-- Table: team_members
-- Owner: Abdullah Eren Erentürk
-- Junction table representing user memberships and positions within teams.
-- Requirements: FR-07, FR-08, FR-09, FR-19, FR-20, NFR-03
-- Depends on: teams, users

CREATE TABLE team_members (
    team_id    INTEGER     NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    user_id    INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    position   VARCHAR(30) CHECK (position IS NULL OR LENGTH(TRIM(position)) > 0),
    joined_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (team_id, user_id) -- A user can be in the same team at most once (NFR-03)
);

CREATE INDEX idx_team_members_user ON team_members (user_id);