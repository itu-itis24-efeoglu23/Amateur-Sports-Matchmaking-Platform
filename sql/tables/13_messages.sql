-- Table: messages
-- Owner: Nurhan Aliyev
-- Match boards, team boards and direct messages.
-- Requirements: FR-17, FR-18, FR-21, NFR-07, NFR-09
-- Depends on: users, matches, teams

CREATE TABLE messages (
    message_id   SERIAL PRIMARY KEY,
    sender_id    INTEGER NOT NULL
                 REFERENCES users(user_id) ON DELETE CASCADE,
    match_id     INTEGER
                 REFERENCES matches(match_id) ON DELETE CASCADE,
    team_id      INTEGER
                 REFERENCES teams(team_id) ON DELETE CASCADE,
    recipient_id INTEGER
                 REFERENCES users(user_id) ON DELETE CASCADE,
    body         VARCHAR(2000) NOT NULL,
    is_hidden    BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_messages_body_length
        CHECK (CHAR_LENGTH(body) BETWEEN 1 AND 2000),

    CONSTRAINT ck_messages_one_target
        CHECK (num_nonnulls(match_id, team_id, recipient_id) = 1)
);


CREATE INDEX idx_messages_match_sent
    ON messages (match_id, sent_at DESC, message_id DESC)
    WHERE match_id IS NOT NULL;


CREATE INDEX idx_messages_team_sent
    ON messages (team_id, sent_at DESC, message_id DESC)
    WHERE team_id IS NOT NULL;


CREATE INDEX idx_messages_recipient_sent
    ON messages (recipient_id, sent_at DESC, message_id DESC)
    WHERE recipient_id IS NOT NULL;


CREATE INDEX idx_messages_sender_sent
    ON messages (sender_id, sent_at DESC, message_id DESC);