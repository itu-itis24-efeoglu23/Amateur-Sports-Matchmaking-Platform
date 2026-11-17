-- Table: users
-- Owner: Furkan Efeoğlu
-- Registered accounts of players, organizers, team captains and admins.
-- Requirements: FR-01, FR-02, NFR-01

CREATE TABLE users (
    user_id        SERIAL       PRIMARY KEY,
    username       VARCHAR(30)  NOT NULL UNIQUE,
    email          VARCHAR(100) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,          -- salted hash, never the plain password
    full_name      VARCHAR(100) NOT NULL,
    city           VARCHAR(50)  NOT NULL,
    birth_date     DATE,
    bio            TEXT,
    role           VARCHAR(10)  NOT NULL DEFAULT 'user'
                   CHECK (role IN ('user', 'admin')),
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
