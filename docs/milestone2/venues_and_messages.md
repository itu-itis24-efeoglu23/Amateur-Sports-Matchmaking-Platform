# Milestone 2 — venues and messages

**Owner:** Nurhan Aliyev (150240929)
**Related requirements:** FR-05, FR-06, FR-17, FR-18, FR-21, NFR-02, NFR-07, NFR-09 (revised proposal, 20 Nov 2026)

## 1. Data Requirements

| ID | Data to store | Rules | Supports |
|---|---|---|---|
| DR-05 | Venues: sport, name, address, city, district, hourly price and indoor status | Each venue belongs to one existing sport; name and location fields cannot be blank; hourly price is non-negative and not NaN; venues referenced by matches cannot be deleted | FR-05, FR-06, NFR-07, NFR-09 |
| DR-06 | Messages: sender, match/team/recipient destination, body, hidden status and sending time | Exactly one destination is required; body contains 1–2000 characters; board access requires participation or membership; direct conversations start with an organizer or captain, who can reply; hidden messages are excluded from ordinary views | FR-17, FR-18, FR-21, NFR-02, NFR-09 |

Venue statistics are **not stored**; Q-02 calculates them from venues and matches.

## 2. Entities

| Entity | Type | Represents |
|---|---|---|
| `venues` | Strong entity | Pitches and courts, each associated with one sport |
| `messages` | Strong entity | Match-board, team-board and direct messages sent by users |

## 3. Relational Schema

### venues

| Column | Data type | Key / constraints |
|---|---|---|
| venue_id | SERIAL | PK |
| sport_id | INTEGER | NOT NULL, FK → sports(sport_id) ON DELETE RESTRICT |
| name | VARCHAR(150) | NOT NULL, CHECK LENGTH(TRIM(name)) > 0 |
| address | TEXT | NOT NULL, CHECK LENGTH(TRIM(address)) > 0 |
| city | VARCHAR(50) | NOT NULL, CHECK LENGTH(TRIM(city)) > 0 |
| district | VARCHAR(50) | NOT NULL, CHECK LENGTH(TRIM(district)) > 0 |
| hourly_price | NUMERIC(10, 2) | NOT NULL, CHECK >= 0 AND <> 'NaN'::NUMERIC |
| is_indoor | BOOLEAN | NOT NULL, DEFAULT FALSE |

### messages

| Column | Data type | Key / constraints |
|---|---|---|
| message_id | SERIAL | PK |
| sender_id | INTEGER | NOT NULL, FK → users(user_id) ON DELETE CASCADE |
| match_id | INTEGER | NULL, FK → matches(match_id) ON DELETE CASCADE |
| team_id | INTEGER | NULL, FK → teams(team_id) ON DELETE CASCADE |
| recipient_id | INTEGER | NULL, FK → users(user_id) ON DELETE CASCADE |
| body | VARCHAR(2000) | NOT NULL, CHECK CHAR_LENGTH(body) BETWEEN 1 AND 2000 |
| is_hidden | BOOLEAN | NOT NULL, DEFAULT FALSE |
| sent_at | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

Table constraint:

- `CHECK (num_nonnulls(match_id, team_id, recipient_id) = 1)`

**Design decisions**

- Each venue references one sport. Its matches obtain their sport through the venue.
- ON DELETE RESTRICT prevents deleting sports used by venues. The existing `matches.venue_id` foreign key prevents deleting venues used by matches.
- NUMERIC(10, 2) stores exact decimal prices with two decimal places.
- One messages table handles all three destinations. The CHECK constraint rejects messages with no destination or multiple destinations.
- ON DELETE CASCADE removes messages when their sender, direct recipient or board destination is deleted.
- Users cannot edit or delete messages. Admins hide inappropriate messages using `is_hidden`; ordinary reads filter `NOT is_hidden`.
- Flask checks active login, board membership, direct-message eligibility and admin permissions. Direct replies to the initiating user are allowed.
- Venue indexes cover `(sport_id, city, venue_id)` and `(city, venue_id)`. Message indexes cover each destination followed by `(sent_at DESC, message_id DESC)`, with partial indexes excluding null destinations, plus an index on `(sender_id, sent_at DESC, message_id DESC)`.

## 4. Relationships and Cardinalities

| # | Relationship | Cardinality | Implemented as |
|---|---|---|---|
| R1 | A sport has venues | 1:N; each venue belongs to exactly one sport | `venues.sport_id` |
| R2 | A venue hosts matches | 1:N; each match takes place at exactly one venue | `matches.venue_id` |
| R3 | A user sends messages | 1:N; each message has exactly one sender | `messages.sender_id` |
| R4 | A match has board messages | 1:N; a message has zero or one match destination | `messages.match_id` |
| R5 | A team has board messages | 1:N; a message has zero or one team destination | `messages.team_id` |
| R6 | A user receives direct messages | 1:N; a message has zero or one direct recipient | `messages.recipient_id` |

Every parent may have zero related messages, venues or matches. The three message destinations are mutually exclusive: exactly one of match_id, team_id and recipient_id is non-null.

## 5. CRUD Operations

All queries use parameterized SQL (`%s` placeholders) through psycopg. List pages return 20 rows per page. Flask validates input and permissions before executing these operations; current-user IDs come from the authenticated session.

| Operation | Page / action | SQL |
|---|---|---|
| Create | Add venue (admin) | `INSERT INTO venues (sport_id, name, address, city, district, hourly_price, is_indoor) VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING venue_id;` |
| Read | Search venues by city and sport | `SELECT v.venue_id, v.name, s.name AS sport_name, v.city, v.hourly_price FROM venues v JOIN sports s ON s.sport_id = v.sport_id WHERE v.city = %s AND v.sport_id = %s ORDER BY v.venue_id LIMIT 20 OFFSET %s;` |
| Read | Venue details | `SELECT * FROM venues WHERE venue_id = %s;` |
| Read | Upcoming matches at a venue | `SELECT match_id, title, start_time, end_time, status FROM matches WHERE venue_id = %s AND start_time > CURRENT_TIMESTAMP AND status IN ('open', 'full') ORDER BY start_time, match_id LIMIT 20 OFFSET %s;` |
| Update | Edit venue (admin) | `UPDATE venues SET sport_id = %s, name = %s, address = %s, city = %s, district = %s, hourly_price = %s, is_indoor = %s WHERE venue_id = %s;` |
| Delete | Remove unused venue (admin) | `DELETE FROM venues WHERE venue_id = %s;` (blocked while matches reference it) |
| Create | Post to match board | `INSERT INTO messages (sender_id, match_id, body) VALUES (%s, %s, %s);` |
| Create | Post to team board | `INSERT INTO messages (sender_id, team_id, body) VALUES (%s, %s, %s);` |
| Create | Send direct message or reply | `INSERT INTO messages (sender_id, recipient_id, body) VALUES (%s, %s, %s);` |
| Read | Match board | `SELECT message_id, sender_id, body, sent_at FROM messages WHERE match_id = %s AND NOT is_hidden ORDER BY sent_at DESC, message_id DESC LIMIT 20 OFFSET %s;` |
| Read | Team board | `SELECT message_id, sender_id, body, sent_at FROM messages WHERE team_id = %s AND NOT is_hidden ORDER BY sent_at DESC, message_id DESC LIMIT 20 OFFSET %s;` |
| Read | Direct-message inbox, including sent messages | `SELECT message_id, sender_id, recipient_id, body, sent_at FROM messages WHERE recipient_id IS NOT NULL AND (sender_id = %s OR recipient_id = %s) AND NOT is_hidden ORDER BY sent_at DESC, message_id DESC LIMIT 20 OFFSET %s;` |
| Read | Conversation with one user | `SELECT message_id, sender_id, recipient_id, body, sent_at FROM messages WHERE ((sender_id = %s AND recipient_id = %s) OR (sender_id = %s AND recipient_id = %s)) AND NOT is_hidden ORDER BY sent_at DESC, message_id DESC LIMIT 20 OFFSET %s;` |
| Update | Hide or unhide message (admin) | `UPDATE messages SET is_hidden = %s WHERE message_id = %s;` |
| Delete | — | No user-facing message deletion; messages are removed by CASCADE when a referenced user or destination is deleted |

For the inbox, both user parameters are the current user's ID. Conversation parameters are current user, other user, other user, current user, then offset.

City-only and sport-only searches use corresponding parameterized query variants. Flask blocks changing a venue's sport when it already has matches, since this would change their implied sport. Message bodies containing only whitespace are rejected by server validation.

## 6. Complex Query — Q-02: Venue popularity

**Purpose:** list completed match counts, hours booked and estimated revenue per venue, ranked within each sport by completed match count. Venues without completed matches appear with zero totals.

**Techniques:** CTE, LEFT JOIN, INNER JOIN, GROUP BY, COUNT, SUM, COALESCE, EXTRACT and RANK() OVER (PARTITION BY ...).

**SQL:** `sql/queries/q2_venue_popularity.sql`

Completed matches have `end_time <= CURRENT_TIMESTAMP` and a status other than `pending` or `cancelled`, following revised FR-12 even when a stored open/full status has not yet been updated.

Duration is calculated as `EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0`. Revenue is total hours multiplied by the venue's current hourly price, so it is an estimate rather than historical payment data.

Equal completed match counts receive the same rank. Hours and revenue are displayed with two decimal places; revenue is calculated before rounding the hours.

## 7. Data Population

Sample data will be generated with a Python script using Faker (Turkish locale):

- Approximately 40 venues referencing the 6 existing sports, with consistent city/district values, realistic addresses, indoor/outdoor options and non-negative hourly prices.
- Approximately 3,000 messages across match boards, team boards and direct conversations.
- Board-message senders are selected from the relevant match participants or team members.
- Direct conversations begin with organizers or captains and may include replies to the initiating users.
- Every message has exactly one destination, a meaningful body of 1–2000 characters and a valid sending time.
- A small proportion of messages are hidden to check moderation filters; selected boards have more than 20 messages to check pagination.
- Venue data includes unused venues, different match durations and tied match counts to verify Q-02.

Venues are populated after sports and before matches. Messages are populated after users, teams, memberships, matches and participants.