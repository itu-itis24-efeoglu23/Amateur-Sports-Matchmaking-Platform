--Table: sports
--Owner: Nurhan Aliyev
--Sports table, independent 
--Requirements: FR-04 Admins can add, edit,and remove sports



Create Table Sports(
    sport_id SMALLINT NOT NULL,
    name VARCHAR(50) NOT NULL,
    players_per_side SMALLINT NOT NULL,
    is_team_sport BOOLEAN NOT NULL DEFAULT FALSE,

    PRIMARY KEY (sport_id),
    CHECK (players_per_side > 0),
    CHECK (sport_id > 0),
    CHECK (TRIM(name) <> '')
);

CREATE UNIQUE INDEX unique_sport_names
    ON Sports (LOWER(TRIM(name)));