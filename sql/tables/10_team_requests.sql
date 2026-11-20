-- Table: team_requests
-- Owner: Baturalp Taha Yılmaz
-- Join requests sent by players to teams and invitations sent by captains
-- to players. Answered requests are kept as history.
-- Requirements: FR-13, FR-14
-- Depends on: 01_users.sql, 05_teams.sql

CREATE TABLE team_requests (
    request_id    SERIAL       PRIMARY KEY,
    team_id       INTEGER      NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    user_id       INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,  -- the player, never the captain
    request_type  VARCHAR(10)  NOT NULL
                  CHECK (request_type IN ('join', 'invite')),   -- join = player applies, invite = captain invites
    status        VARCHAR(10)  NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    message       VARCHAR(300),
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at  TIMESTAMP,
    CHECK ((status = 'pending') = (responded_at IS NULL)),   -- only answered requests have a response time
    CHECK (responded_at IS NULL OR responded_at >= created_at)
);

-- At most one pending request per team and player; old answered requests stay as history.
CREATE UNIQUE INDEX uq_team_requests_one_pending
    ON team_requests (team_id, user_id)
    WHERE status = 'pending';
