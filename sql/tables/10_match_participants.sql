-- Table: match_participants
-- Owner: Ege Kucuk
-- Players who join a match.
-- Requirements: FR-10, FR-11, FR-12, FR-15
-- Depends on: matches, users

CREATE TABLE match_participants (
    match_id     INTEGER NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    user_id      INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    side         VARCHAR(4) NOT NULL CHECK (side IN ('home', 'away')),
    status       VARCHAR(10) NOT NULL DEFAULT 'joined'
                 CHECK (status IN ('joined', 'attended', 'no_show')),
    joined_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_id, user_id) -- One player per match
);

CREATE INDEX idx_match_participants_user ON match_participants (user_id);
CREATE INDEX idx_match_participants_match_status ON match_participants (match_id, status);
