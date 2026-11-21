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

-- The captain must always be a member of the team (NFR-03, FR-08, FR-19).
-- Deferred so creating a team and inserting its captain into team_members can happen in one transaction.
ALTER TABLE teams
    ADD CONSTRAINT fk_teams_captain_is_member
    FOREIGN KEY (team_id, captain_id)
    REFERENCES team_members (team_id, user_id)
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY DEFERRED;