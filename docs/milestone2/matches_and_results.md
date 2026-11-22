# Milestone 2 — matches, match_participants and match_results

**Owner:** Ege Küçük (150230315)  
**Related requirements:** FR-06, FR-10, FR-11, FR-12, FR-20, NFR-04 (revised proposal, 20 Nov 2026)

This file collects the parts of the submitted Milestone 2 document that describe these three tables. The SQL is in `sql/tables/07_matches.sql`, `08_match_participants.sql`, `09_match_results.sql` and `sql/queries/q4_match_finder.sql`.

## 1. Data Requirements

| ID | Data to store and rules | Supports | Entities |
|---|---|---|---|
| DR-09 | Store each match's venue, organizer, home and away teams (team matches only), title, start and end time, capacity, skill range and status (pending, open, full, completed, cancelled). The end is after the start; capacity is at least 2; 1 ≤ min skill ≤ max skill ≤ 5; the two teams differ; a pending match is a team match; two matches that are not cancelled cannot overlap at the same venue. | FR-06, FR-10, FR-11, FR-12, FR-20 | Match, Venue, User, Team |
| DR-10 | Store the participants of each match with their side (home or away), attendance status (joined, attended, no_show) and join time. A user joins a match at most once; the number of participants never exceeds the capacity; only members of the two teams can join a team match. | FR-10, FR-11, FR-12, FR-15 | Match participant, Match, User |
| DR-11 | Store the result of a completed match: home and away score, the user who recorded it, and when it was recorded and last corrected. A match has at most one result; scores are not negative; it can be corrected until 48 hours after the end time. | FR-09, FR-12 | Match result, Match, User |

## 2. Entities

| Entity | Represents | Related FRs |
|---|---|---|
| Match | An individual or team-versus-team match at a venue: organizer, home and away teams (team matches only), title, start and end time, capacity, skill range and status. | FR-06, FR-10, FR-11, FR-12, FR-20 |
| Match participant | A user who joined a match, with their side (home/away), attendance status and join time. Associative entity that resolves the M:N relationship between User and Match. | FR-10, FR-11, FR-12, FR-15, FR-17 |
| Match result | The final score of a completed match, who recorded it and when it was recorded or corrected. Dependent entity in a 1:1 relationship with Match. | FR-09, FR-12 |

## 3. Relational Schema

### matches

Individual and team matches at venues.

| Column | Data type | PK / FK | Constraints |
|---|---|---|---|
| match_id | SERIAL | PK | NOT NULL, auto-increment |
| venue_id | INTEGER | FK → venues(venue_id) | NOT NULL, ON DELETE RESTRICT |
| organizer_id | INTEGER | FK → users(user_id) | NULL, ON DELETE SET NULL |
| home_team_id | INTEGER | FK → teams(team_id) | NULL, ON DELETE SET NULL |
| away_team_id | INTEGER | FK → teams(team_id) | NULL, ON DELETE SET NULL |
| title | VARCHAR(120) | – | NOT NULL, CHECK (LENGTH(TRIM(title)) > 0) |
| start_time | TIMESTAMP | – | NOT NULL |
| end_time | TIMESTAMP | – | NOT NULL, CHECK (end_time > start_time) |
| capacity | SMALLINT | – | NOT NULL, CHECK (capacity >= 2) |
| min_skill | SMALLINT | – | NOT NULL, CHECK (min_skill BETWEEN 1 AND 5) |
| max_skill | SMALLINT | – | NOT NULL, CHECK (max_skill BETWEEN 1 AND 5), CHECK (min_skill <= max_skill) |
| status | VARCHAR(10) | – | NOT NULL, DEFAULT 'open', CHECK (status IN ('pending', 'open', 'full', 'completed', 'cancelled')) |

**Table constraints and indexes:** CHECK (home_team_id IS NULL OR home_team_id <> away_team_id); CHECK (status <> 'pending' OR home_team_id IS NOT NULL); EXCLUDE USING gist (venue_id WITH =, tsrange(start_time, end_time, '[)') WITH &&) WHERE (status <> 'cancelled') – two active matches can never overlap at the same venue (NFR-04, uses the btree_gist extension); indexes on (status, start_time), (organizer_id), (home_team_id) and (away_team_id).

**Design notes:** the venue determines the sport. 'pending' is a proposed team match waiting for the opponent captain (FR-20). Capacity is enforced when joining by locking the match row (SELECT … FOR UPDATE) in the join transaction.

### match_participants

Players who joined a match.

| Column | Data type | PK / FK | Constraints |
|---|---|---|---|
| match_id | INTEGER | PK, FK → matches(match_id) | NOT NULL, ON DELETE CASCADE |
| user_id | INTEGER | PK, FK → users(user_id) | NOT NULL, ON DELETE CASCADE |
| side | VARCHAR(4) | – | NOT NULL, CHECK (side IN ('home', 'away')) |
| status | VARCHAR(10) | – | NOT NULL, DEFAULT 'joined', CHECK (status IN ('joined', 'attended', 'no_show')) |
| joined_at | TIMESTAMP | – | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

**Table constraints and indexes:** composite PK (match_id, user_id) – a player joins a match at most once; indexes on (user_id) and (match_id, status).

**Design notes:** the organizer is inserted as the first participant when the match is created. The primary key is also the target of the two composite foreign keys of player_reviews. The organizer sets status to attended or no_show when recording the result (FR-12).

### match_results

The final score of a completed match (1:1 with matches).

| Column | Data type | PK / FK | Constraints |
|---|---|---|---|
| match_id | INTEGER | PK, FK → matches(match_id) | NOT NULL, ON DELETE CASCADE |
| home_score | SMALLINT | – | NOT NULL, CHECK (home_score >= 0) |
| away_score | SMALLINT | – | NOT NULL, CHECK (away_score >= 0) |
| recorded_by | INTEGER | FK → users(user_id) | NULL, ON DELETE SET NULL |
| recorded_at | TIMESTAMP | – | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | – | NOT NULL, DEFAULT CURRENT_TIMESTAMP, CHECK (updated_at >= recorded_at) |

**Table constraints and indexes:** partial index on (recorded_by) WHERE recorded_by IS NOT NULL.

**Design notes:** using match_id as both primary and foreign key implements the 1:1 relationship – a match can have at most one result. The result is kept in a separate table because most rows of matches (upcoming or cancelled) have no score. The 48-hour correction window of FR-12 is checked in the UPDATE statement against matches.end_time.

## 4. Relationships and Cardinalities

R numbers are the same as in the ER diagram (`docs/milestone2/er_diagram.png`).

| # | Entity A | Relationship | Entity B | Cardinality | Explanation |
|---|---|---|---|---|---|
| R9 | Venue | hosts | Match | 1:N | A venue hosts 0..* matches; each match takes place at exactly one venue, which also determines its sport. |
| R10 | User | organizes | Match | 1:N | A user organizes 0..* matches; each match has at most one organizer (optional, because the organizer of a past match may have deleted their account). |
| R11 | Team | plays as home team in | Match | 1:N | A team is the home team of 0..* matches; a match has zero or one home team (only team matches have one). |
| R12 | Team | plays as away team in | Match | 1:N | A team is the away team of 0..* matches; a match has zero or one away team, which must differ from the home team. |
| R13 | User | takes part in | Match participant | 1:N | A user has 0..* participations; each participation is of exactly one user. |
| R14 | Match | has | Match participant | 1:N | A match has 0..* participants (the organizer joins automatically when the match is created); each participation is in exactly one match. R13 and R14 resolve the M:N relationship User participates in Match. |
| R15 | Match | has | Match result | 1:1 | A completed match has zero or one result; each result belongs to exactly one match (optional for Match, mandatory for Match result). match_id is both primary and foreign key of match_results. |
| R16 | User | records | Match result | 1:N | A user (the organizer) records 0..* results; a result has zero or one recorder (optional if the user is deleted). |

## 5. ER-to-Relational Mapping

| ER component | Table | Mapping |
|---|---|---|
| Venue hosts Match / User organizes Match (1:N, R9, R10) | matches | FK venue_id NOT NULL (RESTRICT); FK organizer_id nullable (SET NULL) so past matches stay in the history when the organizer's account is deleted. |
| Team plays home / away in Match (two 1:N, R11, R12) | matches | Two nullable FKs home_team_id and away_team_id → teams (SET NULL), with CHECK that they differ and that a pending match has teams. |
| User participates in Match (M:N, R13 + R14) | match_participants | Junction table with PK (match_id, user_id) and the attributes side, status and joined_at; both FKs ON DELETE CASCADE. |
| Match has Match result (1:1, R15) / User records result (1:N, R16) | match_results | match_id is both PK and FK → matches (CASCADE), which allows at most one result per match. recorded_by → users is nullable (SET NULL). |

## 6. CRUD Operations

| Operation | C/R/U/D | Role | Tables | FRs | Database interaction |
|---|---|---|---|---|---|
| Organize a match | C | User | matches, match_participants | FR-10 | In one transaction: INSERT the match (status 'open') RETURNING match_id, then INSERT the organizer as a participant; the EXCLUDE constraint rejects an overlapping booking at the venue. |
| Search and join a match | R, C | User | matches, venues, user_sport_profiles, match_participants | FR-11 | SELECT open upcoming matches by sport, city, date and skill (Q-04). Join in one transaction: SELECT the match FOR UPDATE, count participants, INSERT the participant if there is space, and set status 'full' when capacity is reached. |
| Edit / cancel a match, leave a match | U, D | Organizer, User | matches, match_participants | FR-10, FR-11 | UPDATE match details (venue and time only while no one else has joined) or set status 'cancelled'; a player DELETEs their participant row before the start, and a full match becomes 'open' again. |
| Record / correct result and attendance; match history | C, U, R | Organizer, User | match_results, match_participants, matches | FR-12 | Within 48 hours after end_time: INSERT the score into match_results (or UPDATE it and updated_at) and UPDATE participant status to attended / no_show; SELECT the user's past matches with their results. |

## 7. Complex Query — Q-04: Match finder

**Purpose:** Match finder – upcoming open matches in the user's city that fit the user's skill level and still have free spots.  
**Related FRs:** FR-11  
**Tables:** matches, venues, sports, users, user_sport_profiles, match_participants, team_members  
**Techniques:** Multi-table JOIN, LEFT JOIN with COUNT for participants, NOT EXISTS (not already joined), EXISTS (team matches only for team members), GROUP BY … HAVING COUNT < capacity. Returns match, venue, sport, time, capacity and free spots.  
**SQL:** `sql/queries/q4_match_finder.sql`

## 8. Data Population

Generated with a Python script (Faker, Turkish locale) after users, venues, teams and team members are populated:

- **matches** (about 500 rows): About 70% completed (spread over the last 6 months, more in the last 30 days for Q-01), 20% upcoming open or full, 10% cancelled; about 15% are team matches; times never overlap at the same venue; skill ranges and capacities fit the sport.
- **match_participants** (about 4,500 rows): Only users with a profile for the match's sport and a fitting skill level; never more than the capacity; the organizer is always a participant; only team members join team matches; mostly 'attended' with some 'no_show'.
- **match_results** (about 320 rows): Only for completed matches (most of them); realistic scores for the sport; recorded by the organizer within 48 hours.
