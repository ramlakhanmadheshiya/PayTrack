-- PayTrack sync server database (Cloudflare D1).
-- One row per record of the app's data (mills, people, khatas, entries,
-- payments, sheets, log). Every change gets the next revision number, so a
-- phone asks "what changed since revision N?".

CREATE TABLE IF NOT EXISTS records (
  col TEXT NOT NULL,            -- collection: mills, people, khatas, entries, payments, sheets, log
  id TEXT NOT NULL,
  data TEXT NOT NULL,           -- the record as JSON ("{}" when deleted)
  deleted INTEGER NOT NULL DEFAULT 0,
  rev INTEGER NOT NULL,
  by_user TEXT NOT NULL DEFAULT '',
  updated INTEGER NOT NULL,     -- unix ms
  PRIMARY KEY (col, id)
);
CREATE INDEX IF NOT EXISTS records_rev ON records (rev);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  role TEXT NOT NULL,           -- admin | editor | viewer
  token_hash TEXT,              -- the phone's secret key (hashed); NULL until joined
  code_hash TEXT,               -- one-time join code (hashed); NULL once used
  code_expires INTEGER,
  removed INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL,
  last_seen INTEGER
);

CREATE TABLE IF NOT EXISTS meta (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
);
