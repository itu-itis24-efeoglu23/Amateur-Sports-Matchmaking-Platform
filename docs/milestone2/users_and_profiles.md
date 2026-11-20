# Milestone 2 — users, user_sport_profiles and password_reset_tokens

**Owner:** Furkan Efeoğlu (150230003)
**Related requirements:** FR-01, FR-02, FR-03, FR-16, NFR-01, NFR-06 (revised proposal, 20 Nov 2026)

## 1. Data Requirements

| ID | Data to store | Rules | Supports |
|---|---|---|---|
| DR-01 | User accounts: username, email, password hash, full name, city, birth date, bio, role, active/suspended status, number of consecutive failed logins, lock time, registration date | Username and email are unique; role is `user` or `admin`; only a salted password hash is stored; after 5 failed logins the account is locked for 15 minutes; suspended users cannot log in | FR-01, FR-02, FR-16, NFR-01, NFR-06 |
| DR-02 | Sport profiles: a user's skill level and preferred position in a sport, and when the profile was last updated | A user has at most one profile per sport; skill level is 1 (beginner) to 5 (expert); position is optional | FR-03 |
| DR-03 | Password reset tokens: the user, a hash of the token, creation, expiry and use time | A token expires 30 minutes after creation and can be used only once; only its hash is stored | FR-01, NFR-06 |

A player's average rating is **not stored** in `users`; it is computed from `player_reviews` (hidden reviews excluded) so it can never become outdated.

## 2. Entities

| Entity | Type | Represents |
|---|---|---|
| `users` | Strong entity | Players, organizers, team captains and admins |
| `user_sport_profiles` | Associative entity | The M:N relationship between users and sports, with skill level and position as relationship attributes |
| `password_reset_tokens` | Strong (dependent) entity | One-time password reset links of a user |

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
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE |
| failed_login_count | SMALLINT | NOT NULL, DEFAULT 0, CHECK ≥ 0 |
| locked_until | TIMESTAMP | NULL |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### user_sport_profiles

| Column | Data type | Key / constraints |
|---|---|---|
| user_id | INTEGER | PK, FK → users(user_id) ON DELETE CASCADE |
| sport_id | INTEGER | PK, FK → sports(sport_id) ON DELETE CASCADE |
| skill_level | SMALLINT | NOT NULL, CHECK 1–5 |
| preferred_position | VARCHAR(30) | NULL |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### password_reset_tokens

| Column | Data type | Key / constraints |
|---|---|---|
| token_id | SERIAL | PK |
| user_id | INTEGER | NOT NULL, FK → users(user_id) ON DELETE CASCADE |
| token_hash | VARCHAR(255) | NOT NULL, UNIQUE |
| created_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| expires_at | TIMESTAMP | NOT NULL, CHECK > created_at |
| used_at | TIMESTAMP | NULL, CHECK ≥ created_at |

**Design decisions**

- `user_sport_profiles` uses the composite primary key (user_id, sport_id), so the database itself prevents a second profile for the same sport.
- ON DELETE CASCADE: profiles and reset tokens have no meaning without their user, so they are removed automatically.
- Skill level is a number, so it can be compared directly with a match's skill range (min_skill ≤ skill_level ≤ max_skill).
- Lockout data lives in `users` because only the current count and lock time are needed, not a full login history.
- Reset tokens are stored hashed, like passwords, so a database leak does not expose working reset links.

## 4. Relationships and Cardinalities

| # | Relationship | Cardinality | Implemented as |
|---|---|---|---|
| R1 | A user plays sports | M:N (a user plays 0..* sports; a sport has 0..* players) | `user_sport_profiles` with PK (user_id, sport_id) |
| R2 | A user requests password reset tokens | 1:N (a user has 0..* tokens; each token belongs to exactly one user) | `password_reset_tokens.user_id` |

`users` is also referenced by the other members' tables: teams (captain_id), team_members, matches (organizer_id), match_participants, match_results (recorded_by), team_requests, player_reviews (through match_participants) and messages (sender_id, recipient_id).

## 5. CRUD Operations

All queries use parameterized SQL (`%s` placeholders) through psycopg.

| Operation | Page / action | SQL |
|---|---|---|
| Create | Register | `INSERT INTO users (username, email, password_hash, full_name, city, birth_date) VALUES (%s, %s, %s, %s, %s, %s) RETURNING user_id;` |
| Read | Log in | `SELECT user_id, password_hash, role, is_active, locked_until FROM users WHERE username = %s;` then the hash, `is_active` and `locked_until` are checked in Python |
| Update | Failed login | `UPDATE users SET failed_login_count = failed_login_count + 1, locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN NOW() + INTERVAL '15 minutes' ELSE locked_until END WHERE user_id = %s;` |
| Update | Successful login | `UPDATE users SET failed_login_count = 0, locked_until = NULL WHERE user_id = %s;` |
| Create | Forgot password | `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES (%s, %s, NOW() + INTERVAL '30 minutes');` and the link is e-mailed |
| Read + Update | Reset password | In one transaction: `SELECT user_id FROM password_reset_tokens WHERE token_hash = %s AND used_at IS NULL AND expires_at > NOW() FOR UPDATE;` then `UPDATE users SET password_hash = %s ...` and `UPDATE password_reset_tokens SET used_at = NOW() WHERE token_id = %s;` |
| Read | Profile page | `SELECT u.full_name, u.city, u.bio, s.name, p.skill_level, p.preferred_position FROM users u LEFT JOIN user_sport_profiles p ON p.user_id = u.user_id LEFT JOIN sports s ON s.sport_id = p.sport_id WHERE u.user_id = %s;` |
| Update | Edit profile | `UPDATE users SET full_name = %s, city = %s, bio = %s WHERE user_id = %s;` |
| Update | Admin suspends / reactivates a user | `UPDATE users SET is_active = %s WHERE user_id = %s;` |
| Delete | Delete account | In one transaction: cancel the user's upcoming organized matches, then `DELETE FROM users WHERE user_id = %s;` (profiles, tokens, memberships, participations, reviews and messages are removed by CASCADE; blocked while the user is a team captain) |
| Create | Add a sport to profile | `INSERT INTO user_sport_profiles (user_id, sport_id, skill_level, preferred_position) VALUES (%s, %s, %s, %s);` |
| Update | Change skill or position | `UPDATE user_sport_profiles SET skill_level = %s, preferred_position = %s, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND sport_id = %s;` |
| Delete | Remove a sport | `DELETE FROM user_sport_profiles WHERE user_id = %s AND sport_id = %s;` |
| Delete | Clean up old tokens | `DELETE FROM password_reset_tokens WHERE expires_at < NOW() - INTERVAL '1 day';` |

## 6. Complex Query — Q-01: Active players of a sport

**Purpose:** list players who attended at least 3 matches of a sport in the last 30 days, with their skill level and average received rating (hidden reviews excluded). Organizers can use it to find reliable players.
**Techniques:** 5-table join, GROUP BY … HAVING, correlated subquery.
**SQL:** `sql/queries/q1_active_players.sql`

## 7. Data Population

Sample data is generated with a Python script using the Faker library (Turkish locale):

- 300 users, 2 of them admins and a few suspended; about 85% in İstanbul, the rest in Ankara, İzmir and Bursa
- Every user has 1–3 sport profiles (about 520 in total); skill levels follow a realistic distribution (mostly 2–4)
- About 50 password reset tokens, some used, some expired, some still valid
- All demo accounts use the same test password, stored as a hash
