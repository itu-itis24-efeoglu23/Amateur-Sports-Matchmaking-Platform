# Milestone 2 — team_requests and player_reviews

**Owner:** Baturalp Taha Yılmaz (150220302)
**Related requirements:** FR-13, FR-14, FR-15, NFR-03

## 1. Data Requirements

| ID | Data to store | Rules | Supports |
|---|---|---|---|
| DR-10 | Team requests: the team, the player, whether the player applied (`join`) or the captain invited (`invite`), status, an optional message, when the request was sent and when it was answered | Request type is `join` or `invite`; status is `pending`, `accepted`, `rejected` or `cancelled` (default `pending`); a pending request has no response time and an answered one always has one, not earlier than the request; a player can have at most one pending request per team; answered requests are kept as history | FR-13, FR-14 |
| DR-11 | Player reviews: the match, the player who gives the review, the player who receives it, a rating, an optional comment and the review date | Rating is 1 (poor) to 5 (excellent); both players must be participants of the same match; a player cannot rate themselves; a player rates another player at most once per match | FR-15, NFR-03 |

A player's average rating is **not stored**; it is computed from `player_reviews` so it can never become outdated.

## 2. Entities

| Entity | Type | Represents |
|---|---|---|
| `team_requests` | Strong entity (surrogate key) | A join request or an invitation between a team and a player, including its answer |
| `player_reviews` | Strong entity (surrogate key) | A rating that one participant of a match gives another participant of the same match |

## 3. Relational Schema

### team_requests

| Column | Data type | Key / constraints |
|---|---|---|
| request_id | SERIAL | PK |
| team_id | INTEGER | NOT NULL, FK → teams(team_id) ON DELETE CASCADE |
| user_id | INTEGER | NOT NULL, FK → users(user_id) ON DELETE CASCADE |
| request_type | VARCHAR(10) | NOT NULL, CHECK IN ('join', 'invite') |
| status | VARCHAR(10) | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'accepted', 'rejected', 'cancelled') |
| message | VARCHAR(300) | NULL |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| responded_at | TIMESTAMP | NULL |

Table constraints:

- `CHECK ((status = 'pending') = (responded_at IS NULL))`
- `CHECK (responded_at IS NULL OR responded_at >= created_at)`
- Partial unique index `uq_team_requests_one_pending` ON (team_id, user_id) WHERE status = 'pending'

### player_reviews

| Column | Data type | Key / constraints |
|---|---|---|
| review_id | SERIAL | PK |
| match_id | INTEGER | NOT NULL, FK (with reviewer_id and reviewed_id, see below) |
| reviewer_id | INTEGER | NOT NULL |
| reviewed_id | INTEGER | NOT NULL |
| rating | SMALLINT | NOT NULL, CHECK 1–5 |
| comment | VARCHAR(500) | NULL |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

Table constraints:

- FK (match_id, reviewer_id) → match_participants(match_id, user_id) ON DELETE CASCADE
- FK (match_id, reviewed_id) → match_participants(match_id, user_id) ON DELETE CASCADE
- `CHECK (reviewer_id <> reviewed_id)`
- `UNIQUE (match_id, reviewer_id, reviewed_id)`

**Design decisions**

- **One table for join requests and invitations.** Both have the same columns and the same life cycle (pending → accepted / rejected / cancelled); only the sender differs. A `request_type` column avoids two almost identical tables and lets a player see all pending requests and invitations with one query. `user_id` is always the player, never the captain; the captain is found through `teams.captain_id`.
- **Partial unique index instead of UNIQUE (team_id, user_id).** A plain UNIQUE constraint would stop a player from applying again after a rejection, or the old request would have to be deleted and the history lost. The partial index only covers rows with `status = 'pending'`, so any number of answered requests can stay as history while the database still guarantees at most one open request per team and player. It also blocks a pending join request and a pending invitation for the same pair at the same time.
- **Status and response time are checked together.** `(status = 'pending') = (responded_at IS NULL)` makes "accepted without a response time" and "pending with a response time" impossible, and the second CHECK keeps the answer from being earlier than the request.
- **Reviews reference match_participants, not users.** The two composite foreign keys point to the primary key (match_id, user_id) of `match_participants`, so the database itself guarantees that the reviewer and the reviewed player both took part in that match (NFR-03: a user cannot rate a match they did not play). This requires `match_participants` to have the primary key (match_id, user_id).
- **The 'attended' and 'completed' checks are done in Flask.** A foreign key cannot require `match_participants.status = 'attended'` and a CHECK constraint cannot read other tables, so before inserting a review the application checks that the match is completed and that both players have the status `attended`. The database guarantees participation; the application guarantees attendance.
- **Rules that need other tables are also checked in Flask:** an invitation is only sent by the team's captain, the captain is never the `user_id` of a request, and a request is not created for a player who is already a member. When a request is accepted, the primary key of `team_members` still prevents a double membership.
- **ON DELETE CASCADE:** a request has no meaning without its team or player, and a review has no meaning without the participations it refers to. When a team, user or match (and so its participants) is deleted, the related requests and reviews are removed automatically.

## 4. Relationships and Cardinalities

| # | Relationship | Cardinality | Implemented as |
|---|---|---|---|
| R1 | A team receives requests | 1:N (a team has 0..* requests; each request belongs to exactly 1 team) | `team_requests.team_id` FK → teams |
| R2 | A player is in requests | 1:N (a user has 0..* requests; each request concerns exactly 1 user) | `team_requests.user_id` FK → users |
| R3 | A participant gives reviews | 1:N (a participation has 0..* given reviews; each review has exactly 1 reviewer) | FK (match_id, reviewer_id) → match_participants |
| R4 | A participant receives reviews | 1:N (a participation has 0..* received reviews; each review has exactly 1 reviewed player) | FK (match_id, reviewed_id) → match_participants |

Together, R1 and R2 form an M:N relationship between users and teams over time, with at most one pending request per pair at any moment. R3 and R4 form an M:N "rates" relationship between users, limited to players of the same match and to one review per pair per match.
