-- Table: player_reviews
-- Owner: Baturalp Taha Yılmaz
-- Ratings (1-5) and optional comments that players give each other within
-- 7 days after a completed match they both played in. Admins can hide
-- inappropriate reviews.
-- Requirements: FR-15, FR-21, NFR-03, NFR-07
-- Depends on: 01_users.sql, matches and match_participants (Ege Küçük)

CREATE TABLE player_reviews (
    review_id    SERIAL        PRIMARY KEY,
    match_id     INTEGER       NOT NULL,
    reviewer_id  INTEGER       NOT NULL,
    reviewed_id  INTEGER       NOT NULL,
    rating       SMALLINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),  -- 1 = poor, 5 = excellent
    comment      VARCHAR(500),
    is_hidden    BOOLEAN       NOT NULL DEFAULT FALSE,  -- TRUE = hidden by an admin (FR-21): not shown, not counted
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- both players must be participants of the same match
    FOREIGN KEY (match_id, reviewer_id)
        REFERENCES match_participants(match_id, user_id) ON DELETE CASCADE,
    FOREIGN KEY (match_id, reviewed_id)
        REFERENCES match_participants(match_id, user_id) ON DELETE CASCADE,
    CHECK (reviewer_id <> reviewed_id),          -- no self-rating
    UNIQUE (match_id, reviewer_id, reviewed_id)  -- one review per player pair per match
);

-- Player page and average rating: visible reviews of one player (NFR-07).
CREATE INDEX idx_player_reviews_reviewed
    ON player_reviews (reviewed_id)
    WHERE NOT is_hidden;

-- "My reviews" page, and the FK lookup when a participation is deleted (NFR-07).
CREATE INDEX idx_player_reviews_reviewer
    ON player_reviews (reviewer_id);
