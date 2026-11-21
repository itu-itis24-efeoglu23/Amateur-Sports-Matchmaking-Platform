-- Table: venues
-- Owner: Nurhan Aliyev
-- Pitches and courts, each belonging to one sport.
-- Requirements: FR-05, FR-06, NFR-07, NFR-09
-- Depends on: sports

CREATE TABLE venues (
    venue_id     SERIAL PRIMARY KEY,
    sport_id     INTEGER NOT NULL
                 REFERENCES sports(sport_id) ON DELETE RESTRICT,
    name         VARCHAR(150) NOT NULL,
    address      TEXT NOT NULL,
    city         VARCHAR(50) NOT NULL,
    district     VARCHAR(50) NOT NULL,
    hourly_price NUMERIC(10, 2) NOT NULL,
    is_indoor    BOOLEAN NOT NULL DEFAULT FALSE,

    CHECK (LENGTH(TRIM(name)) > 0),
    CHECK (LENGTH(TRIM(address)) > 0),
    CHECK (LENGTH(TRIM(city)) > 0),
    CHECK (LENGTH(TRIM(district)) > 0),
    CHECK (
        hourly_price >= 0
        AND hourly_price <> 'NaN'::NUMERIC
    )
);


CREATE INDEX idx_venues_sport_city
    ON venues (sport_id, city, venue_id);


CREATE INDEX idx_venues_city
    ON venues (city, venue_id);