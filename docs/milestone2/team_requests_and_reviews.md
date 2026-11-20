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

## 5. CRUD Operations

All queries use parameterized SQL (`%s` placeholders) through psycopg.

| Operation | Page / action | SQL |
|---|---|---|
| Create | Apply to a team | `INSERT INTO team_requests (team_id, user_id, request_type, message) VALUES (%s, %s, 'join', %s) RETURNING request_id;` |
| Create | Invite a player (captain) | `INSERT INTO team_requests (team_id, user_id, request_type, message) VALUES (%s, %s, 'invite', %s) RETURNING request_id;` (Flask first checks that the current user is the team's captain) |
| Read | My pending requests and invitations | `SELECT tr.request_id, t.name, tr.request_type, tr.message, tr.created_at FROM team_requests tr JOIN teams t ON t.team_id = tr.team_id WHERE tr.user_id = %s AND tr.status = 'pending' ORDER BY tr.created_at DESC;` |
| Read | Pending applications to my teams (captain) | `SELECT tr.request_id, t.name, u.username, tr.message, tr.created_at FROM team_requests tr JOIN teams t ON t.team_id = tr.team_id JOIN users u ON u.user_id = tr.user_id WHERE t.captain_id = %s AND tr.request_type = 'join' AND tr.status = 'pending' ORDER BY t.name, tr.created_at;` |
| Update | Accept | In **one transaction**: `UPDATE team_requests SET status = 'accepted', responded_at = CURRENT_TIMESTAMP WHERE request_id = %s AND status = 'pending' RETURNING team_id, user_id;` then `INSERT INTO team_members (team_id, user_id) VALUES (%s, %s);` If either statement fails, the whole transaction is rolled back. A join request is accepted by the captain, an invitation by the player. |
| Update | Reject | `UPDATE team_requests SET status = 'rejected', responded_at = CURRENT_TIMESTAMP WHERE request_id = %s AND status = 'pending';` |
| Update | Cancel (by the sender) | `UPDATE team_requests SET status = 'cancelled', responded_at = CURRENT_TIMESTAMP WHERE request_id = %s AND status = 'pending';` |
| Delete | — | Requests are not deleted by users, so the history is kept; they are removed by CASCADE when the team or the user is deleted |
| Create | Rate a player after a match | `INSERT INTO player_reviews (match_id, reviewer_id, reviewed_id, rating, comment) VALUES (%s, %s, %s, %s, %s);` (Flask first checks that the match is completed and both players attended) |
| Read | A player's reviews | `SELECT u.username, r.rating, r.comment, r.created_at FROM player_reviews r JOIN users u ON u.user_id = r.reviewer_id WHERE r.reviewed_id = %s ORDER BY r.created_at DESC;` |
| Read | A player's average rating | `SELECT COUNT(*), ROUND(AVG(rating), 2) FROM player_reviews WHERE reviewed_id = %s;` |
| Update | Edit my review | `UPDATE player_reviews SET rating = %s, comment = %s WHERE review_id = %s AND reviewer_id = %s;` |
| Delete | Delete my review | `DELETE FROM player_reviews WHERE review_id = %s AND reviewer_id = %s;` |

The `AND status = 'pending'` condition in the update statements makes sure an already answered request is never answered again; the `AND reviewer_id = %s` condition makes sure users can only change their own reviews.

## 6. Complex Query — Q-05: Top-rated players

**Purpose:** list, for every sport, the players whose average received rating in that sport is above the average of all ratings given in that sport (at least 3 reviews required). Captains can use it to find good players to invite, and players can see who is rated highly in their sport.
**Techniques:** 5-table join, GROUP BY … HAVING, correlated subquery on the outer group's sport (in SELECT and in HAVING).
**SQL:** `sql/queries/q5_top_rated_players.sql`

## 7. Data Population (requests and reviews)

Sample data is generated with a Python script using the Faker library (Turkish locale), after users, teams, team members, matches and participants are populated:

- 80 team requests: about 60% join requests and 40% invitations
- Status distribution: about 25% pending, 50% accepted, 20% rejected, 5% cancelled; answered requests get a response time 0–7 days after the request
- At most one pending request per team and player; the captain is never the player of a request
- Every accepted request has a matching row in `team_members`
- About 1,450 reviews, created only between players who both attended the same completed match, within 3 days after the match
- Ratings follow a realistic distribution: most are 3–5; about 40% of reviews have a comment
