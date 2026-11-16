// PayTrack sync server (Cloudflare Worker + D1).
//
// Every phone keeps its own copy of the data and works offline. When online it
// sends the records it changed (POST /sync) and fetches what others changed
// (GET /sync?since=N). Records are merged one by one, so two phones adding
// different things never overwrite each other.
//
// No passwords: the admin adds a user in the app, the app shows a one-time
// code, the user types it once (POST /join) and their phone gets its own
// secret key. Removing the user stops that key at once.
//
// Roles: admin (everything + users), editor (daily work; cannot delete mills,
// people or salary sheets), viewer (read only).

const COLLECTIONS = ["mills", "people", "khatas", "entries", "payments", "sheets", "log"];
const EDITOR_NO_DELETE = new Set(["mills", "people", "sheets"]);
const ROLES = new Set(["admin", "editor", "viewer"]);
const CODE_DAYS = 7;
const PAGE = 2000;
const MAX_RECORD = 256 * 1024;
const MAX_CHANGES = 5000;

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    try {
      return cors(await route(req, env));
    } catch (e) {
      if (e instanceof HttpError) return cors(json({ error: e.code }, e.status));
      console.error(e && e.stack ? e.stack : e);
      return cors(json({ error: "server_error" }, 500));
    }
  },
};

class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

async function route(req, env) {
  const url = new URL(req.url);
  const p = url.pathname.replace(/\/+$/, "") || "/";
  const db = env.DB;
  if (p === "/" && req.method === "GET") return json({ app: "PayTrack", ok: true });
  if (p === "/setup" && req.method === "POST") return setup(req, env);
  if (p === "/join" && req.method === "POST") return join(req, db);
  if (p === "/recover" && req.method === "POST") return recover(req, db);
  if (p === "/backup" && req.method === "GET") return backup(req, env);

  const user = await auth(req, db);
  if (p === "/me" && req.method === "GET") return json({ user: publicUser(user), users: await userNames(db), rev: await currentRev(db) });
  if (p === "/sync" && req.method === "GET") return pull(db, Number(url.searchParams.get("since") || 0), user);
  if (p === "/sync" && req.method === "POST") return push(req, db, user);
  if (p === "/users" && req.method === "GET") return listUsers(db, user);
  if (p === "/users" && req.method === "POST") return addUser(req, db, user);
  const m = p.match(/^\/users\/([A-Za-z0-9_-]+)$/);
  if (m && req.method === "POST") return changeUser(req, db, user, m[1]);
  throw new HttpError(404, "not_found");
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json; charset=utf-8" } });
}

function cors(res) {
  const h = new Headers(res.headers);
  h.set("access-control-allow-origin", "*");
  h.set("access-control-allow-headers", "authorization, content-type");
  h.set("access-control-allow-methods", "GET, POST, OPTIONS");
  h.set("access-control-max-age", "86400");
  h.set("cache-control", "no-store");
  return new Response(res.body, { status: res.status, headers: h });
}

async function body(req) {
  try {
    return await req.json();
  } catch {
    throw new HttpError(400, "bad_json");
  }
}

async function sha(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomToken() {
  const b = new Uint8Array(32);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}

// Easy to read aloud and type: no 0/O, 1/I/L.
const CODE_ABC = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
function randomCode() {
  const b = new Uint8Array(8);
  crypto.getRandomValues(b);
  const s = [...b].map((x) => CODE_ABC[x % CODE_ABC.length]).join("");
  return s.slice(0, 4) + "-" + s.slice(4);
}

function normCode(c) {
  return String(c || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function newId(prefix) {
  return prefix + Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36);
}

function safeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

function publicUser(u) {
  return { id: u.id, name: u.name, role: u.role, joined: !!u.token_hash, removed: !!u.removed, created: u.created, last_seen: u.last_seen };
}

async function userNames(db) {
  const r = await db.prepare("SELECT id, name, role, removed FROM users").all();
  return r.results.map((u) => ({ id: u.id, name: u.name, role: u.role, removed: !!u.removed }));
}

async function currentRev(db) {
  const r = await db.prepare("SELECT v FROM meta WHERE k = 'rev'").first();
  return r ? Number(r.v) : 0;
}

async function auth(req, db) {
  const h = req.headers.get("authorization") || "";
  const token = h.startsWith("Bearer ") ? h.slice(7).trim() : "";
  if (!token) throw new HttpError(401, "no_key");
  const u = await db.prepare("SELECT * FROM users WHERE token_hash = ?").bind(await sha(token)).first();
  if (!u) throw new HttpError(401, "unknown_key");
  if (u.removed) throw new HttpError(403, "removed");
  const now = Date.now();
  if (!u.last_seen || now - u.last_seen > 60000) {
    await db.prepare("UPDATE users SET last_seen = ? WHERE id = ?").bind(now, u.id).run();
  }
  return u;
}

function requireAdmin(u) {
  if (u.role !== "admin") throw new HttpError(403, "admin_only");
}

// ---------------------------------------------------------------------------
// Setup, joining, recovery
// ---------------------------------------------------------------------------

async function setup(req, env) {
  // One time only, with the secret set on the server: makes the admin user.
  const db = env.DB;
  const given = req.headers.get("x-setup-secret") || "";
  if (!env.SETUP_SECRET || !safeEqual(given, env.SETUP_SECRET)) throw new HttpError(403, "bad_secret");
  const n = await db.prepare("SELECT COUNT(*) AS n FROM users").first();
  if (n.n > 0) throw new HttpError(409, "already_set_up");
  const b = await body(req);
  const code = randomCode();
  const recovery = randomCode() + "-" + randomCode();
  const id = newId("u");
  const now = Date.now();
  await db.batch([
    db.prepare("INSERT INTO users (id, name, role, code_hash, code_expires, created) VALUES (?, ?, 'admin', ?, ?, ?)")
      .bind(id, String(b.name || "Admin").slice(0, 40), await sha(normCode(code)), now + 30 * 86400000, now),
    db.prepare("INSERT OR REPLACE INTO meta (k, v) VALUES ('recovery', ?)").bind(await sha(normCode(recovery))),
    db.prepare("INSERT OR IGNORE INTO meta (k, v) VALUES ('rev', '0')"),
  ]);
  return json({ admin_code: code, recovery_code: recovery });
}

async function join(req, db) {
  const b = await body(req);
  const h = await sha(normCode(b.code));
  const u = await db.prepare("SELECT * FROM users WHERE code_hash = ?").bind(h).first();
  if (!u || u.removed) throw new HttpError(404, "bad_code");
  if (u.code_expires && u.code_expires < Date.now()) throw new HttpError(410, "code_expired");
  const token = randomToken();
  await db.prepare("UPDATE users SET token_hash = ?, code_hash = NULL, code_expires = NULL, last_seen = ? WHERE id = ?")
    .bind(await sha(token), Date.now(), u.id).run();
  return json({ token, user: publicUser({ ...u, token_hash: "x" }), users: await userNames(db), rev: await currentRev(db) });
}

async function recover(req, db) {
  // Lost phone: the recovery code makes a new phone the admin; the old one stops.
  const b = await body(req);
  const want = await db.prepare("SELECT v FROM meta WHERE k = 'recovery'").first();
  if (!want || !safeEqual(await sha(normCode(b.code)), want.v)) throw new HttpError(404, "bad_code");
  const admin = await db.prepare("SELECT * FROM users WHERE role = 'admin' AND removed = 0 ORDER BY created LIMIT 1").first();
  if (!admin) throw new HttpError(404, "no_admin");
  const token = randomToken();
  await db.prepare("UPDATE users SET token_hash = ?, code_hash = NULL, last_seen = ? WHERE id = ?").bind(await sha(token), Date.now(), admin.id).run();
  return json({ token, user: publicUser({ ...admin, token_hash: "x" }), users: await userNames(db), rev: await currentRev(db) });
}

// ---------------------------------------------------------------------------
// Users (admin)
// ---------------------------------------------------------------------------

async function listUsers(db, me) {
  requireAdmin(me);
  const r = await db.prepare("SELECT * FROM users ORDER BY created").all();
  return json({ users: r.results.map(publicUser) });
}

async function addUser(req, db, me) {
  requireAdmin(me);
  const b = await body(req);
  const name = String(b.name || "").trim().slice(0, 40);
  const role = ROLES.has(b.role) && b.role !== "admin" ? b.role : "editor";
  if (!name) throw new HttpError(400, "no_name");
  const code = randomCode();
  const id = newId("u");
  const now = Date.now();
  await db.prepare("INSERT INTO users (id, name, role, code_hash, code_expires, created) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(id, name, role, await sha(normCode(code)), now + CODE_DAYS * 86400000, now).run();
  const u = await db.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
  return json({ user: publicUser(u), code });
}

async function changeUser(req, db, me, id) {
  requireAdmin(me);
  const b = await body(req);
  const u = await db.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
  if (!u) throw new HttpError(404, "no_user");
  if (u.id === me.id && (b.remove || (b.role && b.role !== "admin"))) throw new HttpError(400, "cannot_change_self");
  let code = null;
  if (b.remove) {
    await db.prepare("UPDATE users SET removed = 1, token_hash = NULL, code_hash = NULL WHERE id = ?").bind(id).run();
  } else {
    if (b.name) await db.prepare("UPDATE users SET name = ? WHERE id = ?").bind(String(b.name).trim().slice(0, 40), id).run();
    if (b.role && ROLES.has(b.role) && b.role !== "admin") await db.prepare("UPDATE users SET role = ? WHERE id = ?").bind(b.role, id).run();
    if (b.new_code) {
      // New phone for this user: the old phone stops, a new code is made.
      code = randomCode();
      await db.prepare("UPDATE users SET token_hash = NULL, removed = 0, code_hash = ?, code_expires = ? WHERE id = ?")
        .bind(await sha(normCode(code)), Date.now() + CODE_DAYS * 86400000, id).run();
    }
  }
  const nu = await db.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
  return json({ user: publicUser(nu), code });
}

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

async function pull(db, since, me) {
  const r = await db.prepare("SELECT col, id, data, deleted, rev, by_user FROM records WHERE rev > ? ORDER BY rev LIMIT ?")
    .bind(since || 0, PAGE + 1).all();
  const rows = r.results;
  const more = rows.length > PAGE;
  if (more) rows.length = PAGE;
  const rev = more ? rows[rows.length - 1].rev : await currentRev(db);
  return json({
    rev,
    more,
    me: publicUser(me),
    users: await userNames(db),
    records: rows.map((x) => ({ c: x.col, id: x.id, d: x.deleted ? null : JSON.parse(x.data), del: !!x.deleted, by: x.by_user })),
  });
}

function overlaps(a, b) {
  // Two work periods [from, upto] (YYYY-MM-DD) share a day.
  return String(a.from || "") <= String(b.upto || "") && String(b.from || "") <= String(a.upto || "");
}

async function push(req, db, user) {
  if (user.role === "viewer") throw new HttpError(403, "read_only");
  const b = await body(req);
  const changes = Array.isArray(b.changes) ? b.changes : [];
  if (changes.length > MAX_CHANGES) throw new HttpError(413, "too_many");
  const rejected = [];
  const accepted = [];

  // Validate shape and role.
  const clean = [];
  for (const ch of changes) {
    const c = String(ch.c || "");
    const id = String(ch.id || "");
    if (!COLLECTIONS.includes(c) || !id || id.length > 80) {
      rejected.push({ c, id, reason: "bad_record" });
      continue;
    }
    const del = !!ch.del;
    if (del && user.role !== "admin" && EDITOR_NO_DELETE.has(c)) {
      rejected.push({ c, id, reason: "admin_only" });
      continue;
    }
    const data = del ? "{}" : JSON.stringify(ch.d || {});
    if (data.length > MAX_RECORD) {
      rejected.push({ c, id, reason: "too_big" });
      continue;
    }
    clean.push({ c, id, del, data, d: ch.d || {} });
  }

  // Two phones paying the same person for the same days: the first payment
  // the server receives wins; the other is sent back to its phone.
  const newPays = clean.filter((x) => x.c === "payments" && !x.del);
  const blockedPays = new Set();
  const blockedKhatas = new Set();
  for (const np of newPays) {
    const have = await db.prepare("SELECT 1 FROM records WHERE col = 'payments' AND id = ?").bind(np.id).first();
    if (have) continue; // an edit of a payment already on the server
    const others = await db.prepare(
      "SELECT id, data, by_user FROM records WHERE col = 'payments' AND deleted = 0 AND json_extract(data, '$.khata_id') = ?"
    ).bind(String(np.d.khata_id || "")).all();
    const clash = others.results.find((o) => overlaps(JSON.parse(o.data), np.d));
    if (clash) {
      blockedPays.add(np.id);
      blockedKhatas.add(String(np.d.khata_id || ""));
      const cd = JSON.parse(clash.data);
      rejected.push({ c: "payments", id: np.id, reason: "already_paid", by: clash.by_user, date: cd.date, paid: cd.paid });
    }
  }
  const toWrite = [];
  for (const x of clean) {
    if (x.c === "payments" && blockedPays.has(x.id)) continue;
    // The khata's "paid up to" and the kharchi marked as paid by a refused payment stay as they are.
    if (x.c === "khatas" && blockedKhatas.has(x.id)) {
      rejected.push({ c: x.c, id: x.id, reason: "already_paid" });
      continue;
    }
    if (x.c === "entries" && blockedPays.has(String(x.d.payment_id || ""))) {
      rejected.push({ c: x.c, id: x.id, reason: "already_paid" });
      continue;
    }
    toWrite.push(x);
  }

  let rev = await currentRev(db);
  if (toWrite.length > 0) {
    // Reserve a block of revision numbers in one step (safe with several phones at once).
    const r = await db.prepare("UPDATE meta SET v = CAST(v AS INTEGER) + ? WHERE k = 'rev' RETURNING v").bind(toWrite.length).first();
    const top = Number(r.v);
    let next = top - toWrite.length + 1;
    const now = Date.now();
    const stmts = toWrite.map((x) =>
      db.prepare(
        "INSERT INTO records (col, id, data, deleted, rev, by_user, updated) VALUES (?, ?, ?, ?, ?, ?, ?) " +
          "ON CONFLICT (col, id) DO UPDATE SET data = excluded.data, deleted = excluded.deleted, rev = excluded.rev, by_user = excluded.by_user, updated = excluded.updated"
      ).bind(x.c, x.id, x.data, x.del ? 1 : 0, next++, user.name, now)
    );
    for (let i = 0; i < stmts.length; i += 50) await db.batch(stmts.slice(i, i + 50));
    for (const x of toWrite) accepted.push({ c: x.c, id: x.id });
    rev = top;
  }

  // Send back the server's copy of refused records so the phone can put them right.
  const server = [];
  for (const rj of rejected) {
    const row = await db.prepare("SELECT data, deleted, by_user FROM records WHERE col = ? AND id = ?").bind(rj.c, rj.id).first();
    server.push({ c: rj.c, id: rj.id, d: row && !row.deleted ? JSON.parse(row.data) : null, del: !row || !!row.deleted, by: row ? row.by_user : "" });
  }
  return json({ rev, accepted: accepted.length, rejected, server });
}

// ---------------------------------------------------------------------------
// Backup (GitHub fetches this at 7 p.m.; the file imports straight into the app)
// ---------------------------------------------------------------------------

async function backup(req, env) {
  const h = req.headers.get("authorization") || "";
  const given = h.startsWith("Bearer ") ? h.slice(7).trim() : "";
  if (!env.BACKUP_SECRET || !safeEqual(given, env.BACKUP_SECRET)) throw new HttpError(403, "bad_secret");
  const db = env.DB;
  const data = { format: 1, settings: { lang: "en", last_export: "", text_size: 1.0 }, meta: { updated: 0, created: 0 } };
  for (const c of COLLECTIONS) data[c] = [];
  const r = await db.prepare("SELECT col, data FROM records WHERE deleted = 0 ORDER BY rowid").all();
  for (const x of r.results) data[x.col].push(JSON.parse(x.data));
  data.log.sort((a, b) => (a.t || 0) - (b.t || 0));
  const rev = await currentRev(db);
  const last = await db.prepare("SELECT MAX(updated) AS u FROM records").first();
  data.meta.updated = Math.floor((last && last.u ? last.u : 0) / 1000);
  const users = await db.prepare("SELECT name, role, removed FROM users ORDER BY created").all();
  return json({
    app: "PayTrack",
    format: 1,
    exported: new Date().toISOString(),
    server_rev: rev,
    users: users.results,
    data,
  });
}
