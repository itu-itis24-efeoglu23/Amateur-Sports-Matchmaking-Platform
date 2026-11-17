# Milestone 2 — users and user_sport_profiles

**Owner:** Furkan Efeoğlu (150230003)
**Related requirements:** FR-01, FR-02, FR-03, NFR-01

## 1. Data Requirements

| ID | Data to store | Rules | Supports |
|---|---|---|---|
| DR-01 | User accounts: username, email, password hash, full name, city, birth date, bio, role, registration date | Username and email are unique; role is `user` or `admin` (default `user`); only a salted password hash is stored, never the plain password | FR-01, FR-02, NFR-01 |
| DR-03 | Sport profiles: a user's skill level and preferred position in a sport, and when the profile was last updated | A user has at most one profile per sport; skill level is 1 (beginner) to 5 (expert); position is optional | FR-03 |

A player's average rating is **not stored** in `users`; it is computed from `player_reviews` so it can never become outdated.

## 2. Entities

| Entity | Type | Represents |
|---|---|---|
| `users` | Strong entity | Players, organizers, team captains and admins |
| `user_sport_profiles` | Associative entity | The M:N relationship between users and sports, with skill level and position as relationship attributes |

## 3. Relational Schema

### users

| Column | Data type | Key / constraints |
|---|---|---|
| user_id | SERIAL | PK |
| username | VARCHAR(30) | NOT NULL, UNIQUE |
| email | VARCHAR(100) | NOT NULL, UNIQUE |
| password_hash | VARCHAR(255) | NOT NULL |
| full_name | VARCHAR(100) | NOT NULL |
| city | VARCHAR(50) | NOT NULL |
| birth_date | DATE | NULL |
| bio | TEXT | NULL |
| role | VARCHAR(10) | NOT NULL, DEFAULT 'user', CHECK IN ('user', 'admin') |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### user_sport_profiles

| Column | Data type | Key / constraints |
|---|---|---|
| user_id | INTEGER | PK, FK → users(user_id) ON DELETE CASCADE |
| sport_id | INTEGER | PK, FK → sports(sport_id) ON DELETE CASCADE |
| skill_level | SMALLINT | NOT NULL, CHECK 1–5 |
| preferred_position | VARCHAR(30) | NULL |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

**Design decisions**

- `user_sport_profiles` uses the composite primary key (user_id, sport_id), so the database itself prevents a second profile for the same sport.
- ON DELETE CASCADE: when a user or a sport is deleted, the related profiles are removed automatically, because a profile has no meaning without them.
- Skill level is a number, so it can be compared directly with a match's skill range (min_skill ≤ skill_level ≤ max_skill).

## 4. Relationships and Cardinalities

| # | Relationship | Cardinality | Implemented as |
|---|---|---|---|
| R1 | A user plays sports | M:N (a user plays 0..* sports; a sport has 0..* players) | `user_sport_profiles` with PK (user_id, sport_id) |

`users` is also referenced by the other members' tables:

| Table | Column | Meaning |
|---|---|---|
| teams | captain_id | A user captains 0..* teams; each team has exactly one captain |
| team_members | user_id | Users M:N teams |
| matches | organizer_id | A user organizes 0..* matches |
| match_participants | user_id | Users M:N matches |
| team_requests | user_id | A user sends or receives 0..* requests |
| player_reviews | reviewer_id, reviewed_id | Through match_participants |

## 5. CRUD Operations

All queries use parameterized SQL (`%s` placeholders) through psycopg.

| Operation | Page / action | SQL |
|---|---|---|
| Create | Register | `INSERT INTO users (username, email, password_hash, full_name, city, birth_date) VALUES (%s, %s, %s, %s, %s, %s) RETURNING user_id;` |
| Read | Login | `SELECT user_id, password_hash, role FROM users WHERE username = %s;` then the hash is checked in Python |
| Read | Profile page | `SELECT u.full_name, u.city, u.bio, s.name, p.skill_level, p.preferred_position FROM users u LEFT JOIN user_sport_profiles p ON p.user_id = u.user_id LEFT JOIN sports s ON s.sport_id = p.sport_id WHERE u.user_id = %s;` |
| Update | Edit profile | `UPDATE users SET full_name = %s, city = %s, bio = %s WHERE user_id = %s;` |
| Delete | Delete account | `DELETE FROM users WHERE user_id = %s;` (profiles, memberships and participations are removed by CASCADE; a team captain must first hand over or delete their teams) |
| Create | Add a sport to profile | `INSERT INTO user_sport_profiles (user_id, sport_id, skill_level, preferred_position) VALUES (%s, %s, %s, %s);` |
| Update | Change skill or position | `UPDATE user_sport_profiles SET skill_level = %s, preferred_position = %s, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND sport_id = %s;` |
| Delete | Remove a sport | `DELETE FROM user_sport_profiles WHERE user_id = %s AND sport_id = %s;` |

## 6. Complex Query — Q-01: Active players of a sport

**Purpose:** list players who attended at least 3 matches of a sport in the last 30 days, with their skill level and average received rating. Organizers can use it to find reliable players.
**Techniques:** 4-table join, GROUP BY … HAVING, correlated subquery.
**SQL:** `sql/queries/q1_active_players.sql`

## 7. Data Population (users and profiles)

Sample data is generated with a Python script using the Faker library (Turkish locale):

- 300 users, 2 of them admins; about 85% in İstanbul, the rest in Ankara, İzmir and Bursa
- Every user has 1–3 sport profiles (about 520 in total)
- Skill levels follow a realistic distribution: most players are level 2–4
- All demo accounts use the same test password, stored as a hash
