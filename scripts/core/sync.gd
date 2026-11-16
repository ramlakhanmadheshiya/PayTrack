extends Node
## Sharing between phones (autoload "Sync").
##
## Every phone keeps its own full copy and works offline. When online it sends
## the records it changed to paytrack.theramlakhan.com and fetches what other
## phones changed. Records (a worker, a kharchi, a payment…) are merged one by
## one, so two phones adding different things never overwrite each other.
##
## How changes are found: for every record we remember a fingerprint of what
## the server has. A record whose fingerprint differs was changed on this
## phone; a remembered record that is gone was deleted on this phone.

signal status_changed
signal notice(title: String, message: String)

const URL := "https://paytrack.theramlakhan.com"
const COLS := ["mills", "people", "khatas", "entries", "payments", "sheets", "log"]
const STATE_PATH := "user://sync.json"
const BEFORE_JOIN_PATH := "user://paytrack.before-sharing.json"
const POLL_SECONDS := 30.0
const PUSH_CHUNK := 400

var url := URL
var state_path := STATE_PATH
var save_state_enabled := true

# Saved state.
var token := ""
var me := {}          # {id, name, role}
var users: Array = [] # [{id, name, role, removed}]
var rev := 0
var hashes := {}      # col -> {id -> fingerprint of the server's copy}
var last_ok := 0      # unix time of the last good sync

# Live status: "off" | "syncing" | "ok" | "offline" | "removed"
var status := "off"
var _busy := false
var _again := false
var _applying := false
var _debounce: Timer
var _poll: Timer
var _snapshot := {}   # viewers: the data as the server has it
var replaced_local := false   # the last join put this phone's own data aside
var _local_dirty := true      # something changed on this phone since the last send
var _state_dirty := false     # the state file needs writing
var _foreground := true


func _ready() -> void:
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 1.5
	_debounce.timeout.connect(sync_now)
	add_child(_debounce)
	_poll = Timer.new()
	_poll.wait_time = POLL_SECONDS
	_poll.timeout.connect(sync_now)
	add_child(_poll)
	load_state()
	DB.changed.connect(_on_db_changed)
	if enabled():
		status = "offline"
		_poll.start()
		sync_now.call_deferred()


# ---------------------------------------------------------------------------
# Who am I
# ---------------------------------------------------------------------------

func enabled() -> bool:
	return token != ""


func role() -> String:
	return String(me.get("role", "")) if enabled() else ""


func is_admin() -> bool:
	## Not sharing = this phone is its own admin.
	return not enabled() or role() == "admin"


func read_only() -> bool:
	return enabled() and role() == "viewer"


func my_name() -> String:
	return String(me.get("name", "")) if enabled() else ""


func role_name(r: String) -> String:
	return Lang.t("role_" + r)


# ---------------------------------------------------------------------------
# State file (kept apart from the data, so a backup file never holds the key)
# ---------------------------------------------------------------------------

func load_state() -> void:
	token = ""
	me = {}
	users = []
	rev = 0
	hashes = {}
	last_ok = 0
	if not save_state_enabled or not FileAccess.file_exists(state_path):
		return
	var p = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	if not (p is Dictionary):
		return
	token = String(p.get("token", ""))
	me = p.get("me", {})
	users = p.get("users", [])
	rev = int(p.get("rev", 0))
	hashes = p.get("hashes", {})
	last_ok = int(p.get("last_ok", 0))


func save_state() -> void:
	_state_dirty = false
	if not save_state_enabled:
		return
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"token": token, "me": me, "users": users, "rev": rev, "hashes": hashes, "last_ok": last_ok}))
		f.close()


func export_state() -> Dictionary:
	## For tests (two phones in one run).
	return {"token": token, "me": me.duplicate(true), "users": users.duplicate(true), "rev": rev, "hashes": hashes.duplicate(true), "last_ok": last_ok, "status": status}


func import_state(s: Dictionary) -> void:
	token = s.token
	me = s.me
	users = s.users
	rev = s.rev
	hashes = s.hashes
	last_ok = s.last_ok
	status = s.status


func _set_status(s: String) -> void:
	if s != status:
		status = s
		status_changed.emit()


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

func _http(method: int, path: String, body = null, auth := true) -> Dictionary:
	## {code, json}. code 0 = no internet / server not reached.
	var h := HTTPRequest.new()
	h.timeout = 30.0
	add_child(h)
	var headers := ["Content-Type: application/json"]
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var payload := "" if body == null else JSON.stringify(body)
	var err := h.request(url + path, headers, method, payload)
	if err != OK:
		h.queue_free()
		return {"code": 0, "json": {}}
	var res: Array = await h.request_completed
	h.queue_free()
	var code: int = res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0
	var j = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if code > 0 else null
	return {"code": code, "json": j if j is Dictionary else {}}


# ---------------------------------------------------------------------------
# Joining, recovery, leaving
# ---------------------------------------------------------------------------

func join(code: String, recovery := false) -> String:
	## Returns "" when joined, or an error key.
	var r := await _http(HTTPClient.METHOD_POST, "/recover" if recovery else "/join", {"code": code}, false)
	if r.code == 0:
		return "err_offline"
	if r.code != 200:
		var e := String(r.json.get("error", ""))
		return "err_code_expired" if e == "code_expired" else "err_bad_code"
	token = String(r.json.token)
	me = r.json.user
	users = r.json.get("users", [])
	var server_rev := int(r.json.get("rev", 0))
	hashes = {}
	rev = 0
	replaced_local = false
	# The admin's first phone fills the empty server with its data. Every
	# other phone takes the shared data; its own data is kept in a file.
	if not (server_rev == 0 and role() == "admin"):
		replaced_local = DB.has_any_data()
		if DB.has_any_data() and DB.save_enabled:
			var f := FileAccess.open(BEFORE_JOIN_PATH, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(DB.data))
				f.close()
		_applying = true
		var keep_settings: Dictionary = DB.data.settings.duplicate(true)
		DB.data = DB.empty_data()
		DB.data.settings = keep_settings
		DB.save()
		_applying = false
	_local_dirty = true
	save_state()
	_poll.start()
	await sync_now(true)
	return ""


func leave(erase := true) -> void:
	## Stop sharing on this phone. The shared data is erased from the phone at
	## once (it belongs to the admin, not to this phone).
	token = ""
	me = {}
	users = []
	rev = 0
	hashes = {}
	last_ok = 0
	_poll.stop()
	save_state()
	if erase:
		erase_device()
	_set_status("off")


func erase_device() -> void:
	## Every trace of PayTrack data on this phone: the data, its safety
	## copies, the import-undo copy, the copy kept when joining, shared files.
	_applying = true
	var lang := Lang.lang
	DB.data = DB.empty_data()
	DB.data.settings.lang = lang
	if DB.save_enabled:
		for path in [DB.PREV_PATH, DB.IMPORT_UNDO_PATH, BEFORE_JOIN_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var share := DirAccess.open("user://share")
		if share:
			for f in share.get_files():
				share.remove(f)
	DB.save()
	if FileAccess.file_exists(DB.PREV_PATH) and DB.save_enabled:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DB.PREV_PATH))
	_snapshot = {}
	_applying = false


# ---------------------------------------------------------------------------
# Users (admin)
# ---------------------------------------------------------------------------

func list_users() -> Dictionary:
	var r := await _http(HTTPClient.METHOD_GET, "/users")
	if r.code != 200:
		return {"error": "err_offline" if r.code == 0 else "err_server"}
	return {"users": r.json.get("users", [])}


func add_user(name: String, r: String) -> Dictionary:
	var res := await _http(HTTPClient.METHOD_POST, "/users", {"name": name, "role": r})
	if res.code != 200:
		return {"error": "err_offline" if res.code == 0 else "err_server"}
	return res.json


func change_user(id: String, change: Dictionary) -> Dictionary:
	var res := await _http(HTTPClient.METHOD_POST, "/users/" + id, change)
	if res.code != 200:
		return {"error": "err_offline" if res.code == 0 else "err_server"}
	if id == String(me.get("id", "")) and res.json.has("user"):
		me.name = res.json.user.name
		save_state()
	return res.json


# ---------------------------------------------------------------------------
# Syncing
# ---------------------------------------------------------------------------

func _on_db_changed() -> void:
	if _applying or not enabled():
		return
	if read_only():
		_undo_viewer_change()
		return
	_local_dirty = true
	_debounce.start()


func set_foreground(on: bool) -> void:
	## No checking while the app is in the background (saves battery).
	_foreground = on
	if not enabled():
		return
	if on:
		_poll.start()
		sync_now()
	else:
		_poll.stop()
		if _state_dirty:
			save_state()


func sync_now(manual := false) -> void:
	## A quiet check (every 30 s) changes nothing on screen unless something
	## arrived. "manual" (tapping the status row) shows "Syncing…".
	if not enabled():
		return
	if _busy:
		_again = true
		return
	_busy = true
	if manual:
		_set_status("syncing")
	var ok := await _push()
	if ok and enabled():
		ok = await _pull()
	_busy = false
	if not enabled():
		return
	if ok:
		last_ok = int(Time.get_unix_time_from_system())
		if _state_dirty:
			save_state()
		_set_status("ok")
	elif status != "removed":
		_set_status("offline")
	if _again:
		_again = false
		sync_now.call_deferred()


static func fingerprint(rec) -> String:
	return JSON.stringify(rec).md5_text()


func _diff() -> Array:
	var out := []
	for c in COLS:
		var known: Dictionary = hashes.get(c, {})
		var seen := {}
		for rec in DB.data.get(c, []):
			if not rec.has("id"):
				rec.id = DB.new_id("l" if c == "log" else "x")
			var id := String(rec.id)
			seen[id] = true
			var fp := fingerprint(rec)
			if known.get(id, "") != fp:
				out.append({"c": c, "id": id, "d": rec, "fp": fp})
		# The activity list is trimmed on each phone; trimming is not a deletion.
		if c != "log":
			for id in known:
				if not seen.has(id):
					out.append({"c": c, "id": id, "del": true})
	return out


func _push() -> bool:
	if read_only() or not _local_dirty:
		return true
	_local_dirty = false
	var changes := _diff()
	var i := 0
	while i < changes.size():
		var chunk := changes.slice(i, i + PUSH_CHUNK)
		var send := []
		for ch in chunk:
			send.append({"c": ch.c, "id": ch.id, "d": ch.get("d"), "del": ch.get("del", false)})
		var r := await _http(HTTPClient.METHOD_POST, "/sync", {"changes": send})
		if r.code != 200:
			_local_dirty = true   # try again next time
			_check_access(r.code, r.json)
			return false
		var refused := {}
		for rj in r.json.get("rejected", []):
			refused[String(rj.c) + "|" + String(rj.id)] = rj
		for ch in chunk:
			if refused.has(ch.c + "|" + ch.id):
				continue
			if not hashes.has(ch.c):
				hashes[ch.c] = {}
			if ch.get("del", false):
				hashes[ch.c].erase(ch.id)
			else:
				hashes[ch.c][ch.id] = ch.fp
		if not refused.is_empty():
			_apply_refused(r.json.get("rejected", []), r.json.get("server", []))
		_state_dirty = true
		i += PUSH_CHUNK
	return true


func _apply_refused(rejected: Array, server: Array) -> void:
	## Put refused records back as the server has them, and say why.
	_applying = true
	for s in server:
		_apply_one(String(s.c), String(s.id), s.get("d"), bool(s.get("del", false)), true)
	DB.save()
	_applying = false
	for rj in rejected:
		if rj.c == "payments" and rj.reason == "already_paid":
			notice.emit(Lang.t("already_paid_title"), Lang.t("already_paid_body", [String(rj.get("by", "")), Lang.date_full(String(rj.get("date", ""))), Money.group(int(rj.get("paid", 0)))]))
		elif rj.reason == "admin_only":
			notice.emit(Lang.t("admin_only_title"), Lang.t("admin_only_body"))


func _pull() -> bool:
	var got_any := false
	var guard := 0
	while guard < 1000:
		guard += 1
		var r := await _http(HTTPClient.METHOD_GET, "/sync?since=%d" % rev)
		if r.code == 0:
			return false
		if _check_access(r.code, r.json):
			return false
		if r.code != 200:
			return false
		if r.json.has("me"):
			var was := role()
			var was_name := my_name()
			me = r.json.me
			if role() != was or my_name() != was_name:
				_state_dirty = true
				status_changed.emit()
		if r.json.has("users") and JSON.stringify(r.json.users) != JSON.stringify(users):
			users = r.json.users
			_state_dirty = true
		var recs: Array = r.json.get("records", [])
		if not recs.is_empty():
			_applying = true
			var any := false
			var log_added := false
			for x in recs:
				if _apply_one(String(x.c), String(x.id), x.get("d"), bool(x.get("del", false)), false):
					any = true
					if x.c == "log":
						log_added = true
			if log_added:
				DB.data.log.sort_custom(func(a, b): return int(a.get("t", 0)) < int(b.get("t", 0)))
				if DB.data.log.size() > DB.LOG_MAX:
					DB.data.log = DB.data.log.slice(DB.data.log.size() - DB.LOG_MAX)
			if any:
				DB.save()
				got_any = true
			_applying = false
		var new_rev := int(r.json.get("rev", rev))
		if new_rev != rev:
			rev = new_rev
			_state_dirty = true
		if not r.json.get("more", false):
			break
	if read_only() and (got_any or _snapshot.is_empty()):
		_snapshot = _collections_copy()
	return true


func _apply_one(c: String, id: String, d, del: bool, force: bool) -> bool:
	## Puts one record from the server into the data. A record changed on this
	## phone and not yet sent is left alone (it is sent next), unless force.
	if not c in COLS:
		return false
	var list: Array = DB.data[c]
	var idx := -1
	for k in list.size():
		if String(list[k].get("id", "")) == id:
			idx = k
			break
	if not hashes.has(c):
		hashes[c] = {}
	var known: Dictionary = hashes[c]
	if not force:
		var pending := false
		if idx >= 0:
			pending = fingerprint(list[idx]) != known.get(id, "")
		elif known.has(id):
			pending = true   # deleted here, not yet sent
		if pending and not (idx >= 0 and d != null and fingerprint(list[idx]) == fingerprint(DB.normalize_record(c, d))):
			return false
	if del or d == null:
		if idx >= 0:
			list.remove_at(idx)
		known.erase(id)
		return idx >= 0
	var rec := DB.normalize_record(c, d)
	var fp := fingerprint(rec)
	if idx >= 0 and fingerprint(list[idx]) == fp:
		known[id] = fp
		return false   # already the same here (e.g. our own change coming back)
	if idx >= 0:
		list[idx] = rec
	else:
		list.append(rec)
	known[id] = fp
	return true


func _check_access(code: int, j: Dictionary) -> bool:
	## True when this phone may no longer share (removed by the admin, or the
	## user's key was replaced by a new phone).
	if code == 401 or (code == 403 and String(j.get("error", "")) == "removed"):
		var who := my_name()
		leave()
		status = "removed"
		status_changed.emit()
		notice.emit(Lang.t("removed_title"), Lang.t("removed_body", [who]))
		return true
	return false


# ---------------------------------------------------------------------------
# Viewers: changes are put back at once
# ---------------------------------------------------------------------------

func _collections_copy() -> Dictionary:
	var out := {}
	for c in COLS:
		out[c] = DB.data[c].duplicate(true)
	return out


func _undo_viewer_change() -> void:
	if _snapshot.is_empty():
		_snapshot = _collections_copy()
		return
	var same := true
	for c in COLS:
		if JSON.stringify(DB.data[c]) != JSON.stringify(_snapshot[c]):
			same = false
			break
	if same:
		return
	_applying = true
	for c in COLS:
		DB.data[c] = _snapshot[c].duplicate(true)
	DB.save()
	_applying = false
	notice.emit(Lang.t("view_only_title"), Lang.t("view_only_body"))
