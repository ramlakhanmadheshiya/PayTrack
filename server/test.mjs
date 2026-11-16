// Server tests against a local copy:  npx wrangler@4 dev --local  then  node test.mjs
// (uses .dev.vars: SETUP_SECRET=testsetup BACKUP_SECRET=testbackup, and a fresh local database)
const BASE = process.env.BASE || "http://localhost:8787";
let fails = 0, checks = 0;
function check(cond, label) {
  checks++;
  if (!cond) { fails++; console.log("FAIL:", label); }
}
async function call(path, { method = "GET", token, body, headers = {} } = {}) {
  const h = { "content-type": "application/json", ...headers };
  if (token) h.authorization = "Bearer " + token;
  const r = await fetch(BASE + path, { method, headers: h, body: body ? JSON.stringify(body) : undefined });
  let j = null;
  try { j = await r.json(); } catch {}
  return { status: r.status, j };
}

const s = await call("/setup", { method: "POST", headers: { "x-setup-secret": "testsetup" }, body: { name: "Owner" } });
check(s.status === 200 && s.j.admin_code && s.j.recovery_code, "setup gives admin and recovery codes");
check((await call("/setup", { method: "POST", headers: { "x-setup-secret": "testsetup" } })).status === 409, "setup only once");
check((await call("/setup", { method: "POST", headers: { "x-setup-secret": "wrong" } })).status === 403, "setup needs the secret");

const a = await call("/join", { method: "POST", body: { code: s.j.admin_code.toLowerCase().replace("-", " ") } });
check(a.status === 200 && a.j.user.role === "admin", "admin joins with the code (any case/spacing)");
const admin = a.j.token;
check((await call("/join", { method: "POST", body: { code: s.j.admin_code } })).status === 404, "code works only once");

const add = await call("/users", { method: "POST", token: admin, body: { name: "Bhai", role: "editor" } });
check(add.status === 200 && add.j.code, "admin adds a user");
const add2 = await call("/users", { method: "POST", token: admin, body: { name: "Viewer", role: "viewer" } });
const ed = (await call("/join", { method: "POST", body: { code: add.j.code } })).j.token;
const vw = (await call("/join", { method: "POST", body: { code: add2.j.code } })).j.token;
check(!!ed && !!vw, "users join");
check((await call("/users", { token: ed })).status === 403, "only admin sees users");

// Admin uploads data.
const up = await call("/sync", { method: "POST", token: admin, body: { changes: [
  { c: "mills", id: "m1", d: { id: "m1", name: "Ganga Mill" } },
  { c: "people", id: "p1", d: { id: "p1", name: "Ramesh", khata_id: "k1" } },
  { c: "khatas", id: "k1", d: { id: "k1", payee_id: "p1", paid_upto: "" } },
  { c: "entries", id: "e1", d: { id: "e1", khata_id: "k1", type: "kharchi", amount: 500, payment_id: "" } },
] } });
check(up.status === 200 && up.j.accepted === 4 && up.j.rev === 4, "admin uploads 4 records");
const pl = await call("/sync?since=0", { token: ed });
check(pl.j.records.length === 4 && pl.j.records[0].by === "Owner", "editor gets them with who made them");
check(pl.j.me.role === "editor" && pl.j.users.length === 3, "pull says who I am and lists users");
check((await call("/sync?since=4", { token: ed })).j.records.length === 0, "nothing new since rev 4");

// Roles.
check((await call("/sync", { method: "POST", token: vw, body: { changes: [{ c: "mills", id: "m2", d: {} }] } })).status === 403, "viewer cannot change");
const edDel = await call("/sync", { method: "POST", token: ed, body: { changes: [{ c: "mills", id: "m1", del: true }, { c: "entries", id: "e2", d: { id: "e2", khata_id: "k1", type: "advance", amount: 100 } }] } });
check(edDel.j.accepted === 1 && edDel.j.rejected[0].reason === "admin_only" && edDel.j.server[0].d.name === "Ganga Mill", "editor cannot delete a mill but can add advance");

// Double payment: two phones pay Ramesh for October.
const pay = (id, by) => ({ c: "payments", id, d: { id, khata_id: "k1", from: "2026-10-01", upto: "2026-10-31", date: "2026-11-16", paid: 9000 } });
const p1 = await call("/sync", { method: "POST", token: ed, body: { changes: [pay("pay1"), { c: "khatas", id: "k1", d: { id: "k1", payee_id: "p1", paid_upto: "2026-10-31" } }, { c: "entries", id: "e1", d: { id: "e1", khata_id: "k1", type: "kharchi", amount: 500, payment_id: "pay1" } }] } });
check(p1.j.accepted === 3 && p1.j.rejected.length === 0, "first payment accepted");
const p2 = await call("/sync", { method: "POST", token: admin, body: { changes: [pay("pay2"), { c: "khatas", id: "k1", d: { id: "k1", payee_id: "p1", paid_upto: "2026-10-31" } }, { c: "entries", id: "e1", d: { id: "e1", khata_id: "k1", type: "kharchi", amount: 500, payment_id: "pay2" } }] } });
const rj = p2.j.rejected.find((x) => x.c === "payments");
check(p2.j.accepted === 0 && rj && rj.reason === "already_paid" && rj.by === "Bhai" && rj.paid === 9000, "second payment for the same days refused, says who paid");
check(p2.j.server.find((x) => x.c === "entries").d.payment_id === "pay1", "refused phone gets the server's kharchi back");
const p3 = await call("/sync", { method: "POST", token: admin, body: { changes: [{ c: "payments", id: "pay3", d: { id: "pay3", khata_id: "k1", from: "2026-11-01", upto: "2026-11-30", paid: 1 } }] } });
check(p3.j.accepted === 1, "next month's payment is fine");
const und = await call("/sync", { method: "POST", token: ed, body: { changes: [{ c: "payments", id: "pay3", del: true }] } });
check(und.j.accepted === 1, "editor can undo a payment");

// Users: remove, new code.
const lst = (await call("/users", { token: admin })).j.users;
const bhai = lst.find((u) => u.name === "Bhai");
const nc = await call("/users/" + bhai.id, { method: "POST", token: admin, body: { new_code: true } });
check(nc.j.code && (await call("/me", { token: ed })).status === 401, "new code for a new phone stops the old phone");
const ed2 = (await call("/join", { method: "POST", body: { code: nc.j.code } })).j.token;
check((await call("/me", { token: ed2 })).status === 200, "new phone works");
await call("/users/" + bhai.id, { method: "POST", token: admin, body: { remove: true } });
check((await call("/me", { token: ed2 })).status === 401, "removed user stops at once");
const meAdmin = (await call("/me", { token: admin })).j.user;
check((await call("/users/" + meAdmin.id, { method: "POST", token: admin, body: { remove: true } })).status === 400, "admin cannot remove themself");

// Recovery.
const rc = await call("/recover", { method: "POST", body: { code: s.j.recovery_code } });
check(rc.status === 200 && rc.j.user.role === "admin", "recovery code makes a new admin phone");
check((await call("/me", { token: admin })).status === 401, "old admin phone stops after recovery");
check((await call("/recover", { method: "POST", body: { code: "AAAA-BBBB-CCCC-DDDD" } })).status === 404, "wrong recovery code refused");

// Backup.
check((await call("/backup")).status === 403, "backup needs the secret");
const bk = await call("/backup", { headers: { authorization: "Bearer testbackup" } });
check(bk.j.app === "PayTrack" && bk.j.data.mills.length === 1 && bk.j.data.payments.length === 1 && bk.j.data.entries.length === 2, "backup has the data in import format");
check(bk.j.data.payments[0].id === "pay1", "backup keeps the accepted payment");

console.log(`Server tests: ${checks} checks, ${fails} failed`);
process.exit(fails ? 1 : 0);
