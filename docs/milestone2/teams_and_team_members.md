# Milestone 2 — teams and team_members

**Owner:** Abdullah Eren Erentürk (150210327)
**Related requirements:** FR-07, FR-08, FR-09, FR-19, FR-20, NFR-03, NFR-08 (revised proposal, 20 Nov 2026)

## 1. Data Requirements

| ID | Data to store | Rules | Supports |
|---|---|---|---|
| DR-07 | Teams: the sport, the team captain, team name, city, optional description and creation timestamp | Sport and captain are required; team name must be unique within the same sport (case-insensitive / trimmed); non-empty team name and city; the captain must also be a member of the team; cannot leave or be removed without transferring captaincy first; when the last member leaves, the team is deleted | FR-07, FR-08, FR-09, FR-19, FR-20, NFR-03 |
| DR-08 | Team memberships: the team, the member user, optional position within the team and join timestamp | A user can be a member of a given team at most once; captain is automatically added as the first member upon team creation; non-blank position if provided | FR-07, FR-08, FR-09, FR-19, FR-20, NFR-03 |

Team statistics (matches played, wins, draws, losses, goals scored, goals conceded, last five results) and average member rating are **not stored** on `teams`; they are computed from `matches`, `match_results`, `team_members` and `player_reviews` (excluding hidden reviews) so they stay consistent and never become stale.

## 2. Entities

| Entity | Type | Represents |
|---|---|---|
| `teams` | Strong entity (surrogate key) | Amateur sports teams formed by users and managed by a team captain |
| `team_members` | Associative entity | The M:N membership relationship between users and teams, with position and join time as relationship attributes |

## 3. Relational Schema

### teams (`sql/tables/05_teams.sql`)

| Column | Data type | Key / constraints |
|---|---|---|
| team_id | SERIAL | PK |
| sport_id | INTEGER | NOT NULL, FK → sports(sport_id) ON DELETE RESTRICT |
| captain_id | INTEGER | NOT NULL, FK → users(user_id) ON DELETE RESTRICT |
| name | VARCHAR(80) | NOT NULL, CHECK non-blank |
| city | VARCHAR(50) | NOT NULL, CHECK non-blank |
| description | TEXT | NULL, CHECK non-blank if not NULL |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

Table constraints and indexes:

- Unique index `uq_teams_sport_name` ON (sport_id, LOWER(TRIM(name)))
- Deferrable composite FK `fk_teams_captain_is_member` ON (team_id, captain_id) → team_members(team_id, user_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED (added at the end of `06_team_members.sql` after both tables are created)
- Index `idx_teams_sport_city` ON (sport_id, city)
- Index `idx_teams_captain` ON (captain_id)

### team_members (`sql/tables/06_team_members.sql`)

| Column | Data type | Key / constraints |
|---|---|---|
| team_id | INTEGER | PK, FK → teams(team_id) ON DELETE CASCADE |
| user_id | INTEGER | PK, FK → users(user_id) ON DELETE CASCADE |
| position | VARCHAR(30) | NULL, CHECK non-blank if not NULL |
| joined_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

Table constraints and indexes:

- Composite PK `(team_id, user_id)`
- Index `idx_team_members_user` ON (user_id)

**Design decisions**

- **Deferrable captain-member foreign key (`fk_teams_captain_is_member`).** Enforces at the database level that `captain_id` is always a member of `team_members` for that `team_id` (NFR-03). Because `05_teams.sql` runs before `06_team_members.sql` during sequential schema loading, the `ALTER TABLE teams ADD CONSTRAINT ...` statement is placed at the end of `06_team_members.sql` after both tables exist. Being `DEFERRABLE INITIALLY DEFERRED`, creating a team and inserting the captain's `team_members` row can happen inside a single transaction without chicken-and-egg lock failures, while `ON DELETE RESTRICT` blocks removing or leaving the captain before transferring captaincy.
- **Case-insensitive team name uniqueness per sport (`uq_teams_sport_name`).** Two teams can share a name across different sports, or have distinct names within the same sport, while duplicate/near-duplicate names (`"Kartal SK"` vs `"kartal sk"`) in the same sport are blocked.
- **Delete behaviors (`RESTRICT`, `CASCADE`, and `SET NULL` on `matches`).** A sport cannot be deleted while teams reference it (`ON DELETE RESTRICT`). Deleting a team cascades to `team_members` and `team_requests`, while `matches.home_team_id` and `matches.away_team_id` use `ON DELETE SET NULL` so match history is preserved. Deleting a user cascades to `team_members`, and if they were a captain, captaincy must be transferred or the team deleted first (FR-02, FR-08).
- **Rules coordinated in Flask / transactions:** transferring captaincy updates `teams.captain_id` only to an existing member of `team_members` (FR-19); when the last member leaves, the application deletes the empty team (FR-08); proposing/accepting a team match (`FR-20`) verifies both teams share the same `sport_id` and restricts match joining to members of `home_team_id` and `away_team_id` on their respective sides.

## 4. Relationships and Cardinalities

| # | Relationship | Cardinality | Implemented as |
|---|---|---|---|
| R1 | A sport has teams | 1:N (a sport has 0..* teams; each team belongs to 1 sport) | `teams.sport_id` FK → sports |
| R2 | A user captains teams | 1:N (a user captains 0..* teams; each team has 1 captain) | `teams.captain_id` FK → users |
| R3 | A team has a captain who is a member | 1:N (a team's captain must exist as a member in `team_members`) | Composite FK `(team_id, captain_id)` → team_members(team_id, user_id) |
| R4 | Users are members of teams | M:N (a user belongs to 0..* teams; a team has 0..* members) | `team_members` associative table with PK `(team_id, user_id)` |

`teams` is also referenced by `matches` (`home_team_id`, `away_team_id`) for team-versus-team matches (FR-20) and by `team_requests` (`team_id`) for invitations and join requests (FR-13, FR-14).

## 5. CRUD Operations

All queries use parameterized SQL (`%s` placeholders) through psycopg. List pages show 20 rows per page (`LIMIT 20 OFFSET %s`).

| Operation | Page / action | SQL |
|---|---|---|
| Create | Create team + add creator as captain/member | In **one transaction**: `INSERT INTO teams (sport_id, captain_id, name, city, description) VALUES (%s, %s, %s, %s, %s) RETURNING team_id;` then `INSERT INTO team_members (team_id, user_id, position) VALUES (%s, %s, %s);` |
| Read | Browse teams by sport and/or city | `SELECT t.team_id, t.name, t.city, s.name AS sport_name, u.username AS captain_username, COUNT(tm.user_id) AS member_count FROM teams t JOIN sports s ON s.sport_id = t.sport_id JOIN users u ON u.user_id = t.captain_id LEFT JOIN team_members tm ON tm.team_id = t.team_id WHERE (%s IS NULL OR t.sport_id = %s) AND (%s IS NULL OR LOWER(t.city) = LOWER(%s)) GROUP BY t.team_id, t.name, t.city, s.name, u.username ORDER BY t.name LIMIT 20 OFFSET %s;` |
| Read | Team page & members | `SELECT tm.user_id, u.username, u.full_name, tm.position, tm.joined_at FROM team_members tm JOIN users u ON u.user_id = tm.user_id WHERE tm.team_id = %s ORDER BY tm.joined_at;` |
| Update | Edit team details (captain) | `UPDATE teams SET name = %s, city = %s, description = %s WHERE team_id = %s AND captain_id = %s;` |
| Update | Transfer captaincy (captain → existing member) | In **one transaction** (after verifying new captain is in `team_members`): `UPDATE teams SET captain_id = %s WHERE team_id = %s AND captain_id = %s;` |
| Delete | Delete team (captain) | `DELETE FROM teams WHERE team_id = %s AND captain_id = %s;` |
| Delete | Remove member (captain, cannot remove self) | `DELETE FROM team_members WHERE team_id = %s AND user_id = %s AND user_id <> %s;` (Flask verifies caller is `captain_id`) |
| Delete | Leave team (member or post-transfer captain) | `DELETE FROM team_members WHERE team_id = %s AND user_id = %s;` (if no rows remain in `team_members`, Flask deletes the team) |
| Create | Propose a team match (captain, FR-20) | `INSERT INTO matches (venue_id, organizer_id, home_team_id, away_team_id, title, start_time, end_time, capacity, min_skill, max_skill, status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending') RETURNING match_id;` |
| Update | Accept or reject a pending team match (opponent captain, FR-20) | Accept: `UPDATE matches SET status = 'open' WHERE match_id = %s AND away_team_id = %s AND status = 'pending';` or Reject: `UPDATE matches SET status = 'cancelled' WHERE match_id = %s AND away_team_id = %s AND status = 'pending';` |

## 6. Complex Query — Q-03: Team statistics

**Purpose:** list each team with its member count, completed match statistics (matches played, wins, draws, losses, goals scored, goals conceded), and the average rating of its members across non-hidden reviews (FR-09). Member counts and match statistics are aggregated separately to prevent row multiplication across joins.
**Techniques:** CTEs, scalar subquery (`IN`), joins, conditional aggregation (`CASE WHEN`).
**SQL:** `sql/queries/q3_team_statistics.sql`

## 7. Data Population

Sample data is generated with a Python script using the Faker library (Turkish locale), after `users` and `sports` are populated:

- 30 teams across the platform's sports and cities (mostly İstanbul, plus major Turkish cities), each with a valid `captain_id`
- About 240 team memberships (~8 members per team on average), with every team's `captain_id` present in `team_members` and no duplicate `(team_id, user_id)` pairs
- Optional positions assigned consistently with each team's sport, and team matches (`home_team_id` / `away_team_id`) linked to `matches` so `Q-03` returns meaningful stats