-- Table: teams
-- Owner: Abdullah Eren Erentürk
-- Amateur sports teams formed by users, managed by a team captain.
-- Requirements: FR-07, FR-08, FR-09, FR-19, FR-20, NFR-03
-- Depends on: users, sports, team_members

CREATE TABLE teams (
    team_id      SERIAL       PRIMARY KEY,
    sport_id     INTEGER      NOT NULL REFERENCES sports(sport_id) ON DELETE RESTRICT,
    captain_id   INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    name         VARCHAR(80)  NOT NULL CHECK (LENGTH(TRIM(name)) > 0),
    city         VARCHAR(50)  NOT NULL CHECK (LENGTH(TRIM(city)) > 0),
    description  TEXT         CHECK (description IS NULL OR LENGTH(TRIM(description)) > 0),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- A team's name must be unique within the same sport (case-insensitive / trimmed).
CREATE UNIQUE INDEX uq_teams_sport_name
    ON teams (sport_id, LOWER(TRIM(name)));

-- The captain must always be a member of the team (NFR-03, FR-08, FR-19).
-- Deferred so creating a team and inserting its captain into team_members can happen in one transaction.
ALTER TABLE teams
    ADD CONSTRAINT fk_teams_captain_is_member
    FOREIGN KEY (team_id, captain_id)
    REFERENCES team_members (team_id, user_id)
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX idx_teams_sport_city ON teams (sport_id, city);
CREATE INDEX idx_teams_captain ON teams (captain_id);