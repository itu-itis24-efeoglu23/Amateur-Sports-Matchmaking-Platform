-- Table: player_reviews
-- Owner: Baturalp Taha Yılmaz
-- Ratings (1-5) and optional comments that players give each other after a
-- match they both played in.
-- Requirements: FR-15, NFR-3
-- Depends on: 01_users.sql, 07_matches.sql, 08_match_participants.sql

CREATE TABLE player_reviews (
    review_id    SERIAL        PRIMARY KEY,
    match_id     INTEGER       NOT NULL,
    reviewer_id  INTEGER       NOT NULL,
    reviewed_id  INTEGER       NOT NULL,
    rating       SMALLINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),  -- 1 = poor, 5 = excellent
    comment      VARCHAR(500),
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- both players must be participants of the same match
    FOREIGN KEY (match_id, reviewer_id)
        REFERENCES match_participants(match_id, user_id) ON DELETE CASCADE,
    FOREIGN KEY (match_id, reviewed_id)
        REFERENCES match_participants(match_id, user_id) ON DELETE CASCADE,
    CHECK (reviewer_id <> reviewed_id),          -- no self-rating
    UNIQUE (match_id, reviewer_id, reviewed_id)  -- one review per player pair per match
);
