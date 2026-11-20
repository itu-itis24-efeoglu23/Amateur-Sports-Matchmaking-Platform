-- Table: users
-- Owner: Furkan Efeoğlu
-- Registered accounts of players, organizers, team captains and admins.
-- Requirements: FR-01, FR-02, FR-16, NFR-01, NFR-06

CREATE TABLE users (
    user_id             SERIAL       PRIMARY KEY,
    username            VARCHAR(30)  NOT NULL UNIQUE,
    email               VARCHAR(100) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,          -- salted hash, never the plain password
    full_name           VARCHAR(100) NOT NULL,
    city                VARCHAR(50)  NOT NULL,
    birth_date          DATE,
    bio                 TEXT,
    role                VARCHAR(10)  NOT NULL DEFAULT 'user'
                        CHECK (role IN ('user', 'admin')),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,     -- FALSE = suspended by an admin (FR-16)
    failed_login_count  SMALLINT     NOT NULL DEFAULT 0
                        CHECK (failed_login_count >= 0),        -- consecutive failed logins (NFR-06)
    locked_until        TIMESTAMP,                              -- set for 15 minutes after 5 failed logins
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
