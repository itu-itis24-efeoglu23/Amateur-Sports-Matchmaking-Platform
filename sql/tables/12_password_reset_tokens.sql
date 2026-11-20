-- Table: password_reset_tokens
-- Owner: Furkan Efeoğlu
-- One-time links for resetting a forgotten password.
-- Requirements: FR-01, NFR-06
-- Depends on: 01_users.sql

CREATE TABLE password_reset_tokens (
    token_id    SERIAL       PRIMARY KEY,
    user_id     INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,     -- only a hash of the token is stored
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP    NOT NULL,            -- created_at + 30 minutes
    used_at     TIMESTAMP,                        -- set when the token is used; a used token cannot be reused
    CHECK (expires_at > created_at),
    CHECK (used_at IS NULL OR used_at >= created_at)
);
