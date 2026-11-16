extends Node
## Two (three) phones sharing through a LOCAL copy of the server.
##   cd server && rm -rf .wrangler && npx wrangler@4 d1 execute paytrack --local --file schema.sql
##   npx wrangler@4 dev --local --port 8787      (uses server/.dev.vars)
##   godot --headless --path . tests/sync_flow.tscn
## Phones are simulated by swapping the app's data and sharing state.

const BASE := "http://localhost:8787"

var checks := 0
var fails := 0
var notices: Array = []


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	DB.reset_for_tests()
	Dates.fake_today = "2026-11-16"
	Sync.save_state_enabled = false
	Sync.url = BASE
	Sync.load_state()
	# Only the test decides when to sync (the app's timers would sync the wrong phone).
	Sync._debounce.wait_time = 9999.0
	Sync._poll.wait_time = 9999.0
	Sync.notice.connect(func(t, m): notices.append(t))
	_run.call_deferred()
	get_tree().create_timer(90.0).timeout.connect(func():
		print("Sync flows: timed out")
		get_tree().quit(1))


func phone() -> Dictionary:
	return {"data": DB.data.duplicate(true), "sync": Sync.export_state()}


func use(p: Dictionary) -> void:
	Sync._local_dirty = true
	Sync._applying = true
	DB.data = p.data.duplicate(true)
	Sync._applying = false
	Sync.import_state(p.sync)


func blank_phone() -> void:
	Sync._applying = true
	DB.data = DB.empty_data()
	Sync._applying = false
	Sync.import_state({"token": "", "me": {}, "users": [], "rev": 0, "hashes": {}, "last_ok": 0, "status": "off"})
	Sync._snapshot = {}


func counts() -> Array:
	return [DB.data.mills.size(), DB.data.people.size(), DB.data.khatas.size(), DB.data.entries.size(), DB.data.payments.size(), DB.data.sheets.size()]


func setup_server() -> Dictionary:
	var h := HTTPRequest.new()
	add_child(h)
	h.request(BASE + "/setup", ["Content-Type: application/json", "X-Setup-Secret: testsetup"], HTTPClient.METHOD_POST, JSON.stringify({"name": "Owner"}))
	var res: Array = await h.request_completed
	h.queue_free()
	var j = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return j if j is Dictionary else {}


func pay(kid: String) -> Dictionary:
	var d := DB.make_draft(kid, "2026-11-16", "2026-10-31")
	for r in d.rows:
		r.att = 20.0
	d.choice = "full"
	return DB.commit_payment(d)


func _run() -> void:
	var s := await setup_server()
	check(s.has("admin_code"), "server set up (start with a fresh local database)")
	if not s.has("admin_code"):
		_finish()
		return

	# Phone A: the admin, with data already on the phone.
	DB.load_sample_data()
	DB.save_enabled = false
	var before := counts()
	var e := await Sync.join(s.admin_code)
	check(e == "" and Sync.role() == "admin", "admin joins (%s)" % e)
	check(counts() == before, "admin keeps own data and uploads it")
	check(Sync._diff().is_empty() and Sync.status == "ok", "everything uploaded")
	var add: Dictionary = await Sync.add_user("Bhai", "editor")
	check(add.has("code"), "admin adds Bhai")
	var addv: Dictionary = await Sync.add_user("Papa", "viewer")
	var A := phone()

	# Phone B: Bhai's phone, empty, joins and gets everything.
	blank_phone()
	e = await Sync.join(add.code)
	check(e == "" and Sync.role() == "editor", "Bhai joins as editor (%s)" % e)
	check(counts() == before, "Bhai sees the same data %s vs %s" % [counts(), before])
	check(Sync._diff().is_empty(), "nothing to send after joining")
	var mohan := DB.find_person_by_name("Mohan")
	DB.add_entry(mohan.id, "kharchi", 700, "2026-11-16")
	await Sync.sync_now()
	check(Sync._diff().is_empty(), "Bhai's kharchi sent")
	var B := phone()

	# Back on A: Bhai's kharchi arrives, with his name in the activity list.
	use(A)
	await Sync.sync_now()
	var found := false
	for x in DB.data.entries:
		if int(x.amount) == 700 and x.person_id == mohan.id:
			found = true
	check(found, "admin gets Bhai's kharchi")
	var by_bhai := false
	for l in DB.data.log:
		if String(l.get("by", "")) == "Bhai":
			by_bhai = true
	check(by_bhai, "activity says Bhai did it")
	A = phone()

	# Both phones pay Mohan for October while offline; A reaches the server first.
	use(A)
	var pa := pay(mohan.khata_id)
	check(not pa.has("error"), "A pays Mohan")
	A = phone()
	use(B)
	await Sync.sync_now()   # B gets up to date first (still before A's payment)
	B = phone()
	use(A)
	await Sync.sync_now()
	A = phone()
	use(B)
	var pb := pay(mohan.khata_id)
	check(not pb.has("error"), "B also pays Mohan (offline)")
	notices.clear()
	await Sync.sync_now()
	var b_pays := []
	for x in DB.data.payments:
		if x.khata_id == mohan.khata_id:
			b_pays.append(x.id)
	check(b_pays == [pa.id], "B ends with A's payment only (got %s)" % [b_pays])
	check(Lang.t("already_paid_title") in notices, "B is told Mohan was already paid")
	check(String(DB.khata(mohan.khata_id).paid_upto) == "2026-10-31", "Mohan paid up to 31 Oct on B")
	var kh_paid := 0
	for x in DB.data.entries:
		if x.khata_id == mohan.khata_id and x.get("payment_id", "") == pa.id:
			kh_paid += 1
	check(kh_paid > 0, "Mohan's kharchi is marked as paid by A's payment")
	check(Sync._diff().is_empty(), "nothing left to send on B")

	# Editor cannot delete a mill: it comes back.
	var mill_count: int = DB.data.mills.size()
	notices.clear()
	DB.delete_mill(DB.data.mills[0].id)
	await Sync.sync_now()
	check(DB.data.mills.size() == mill_count, "mill put back for the editor")
	check(Lang.t("admin_only_title") in notices, "editor told only admin can delete")
	B = phone()

	# Phone C: Papa, view only. Changes are put back at once.
	blank_phone()
	e = await Sync.join(addv.code)
	check(e == "" and Sync.read_only(), "Papa joins view only")
	var n_entries: int = DB.data.entries.size()
	notices.clear()
	DB.add_entry(mohan.id, "advance", 100, "2026-11-16")
	check(DB.data.entries.size() == n_entries and Lang.t("view_only_title") in notices, "view only: change put back")

	# Admin removes Bhai: his phone stops.
	use(A)
	var list: Dictionary = await Sync.list_users()
	var bhai_id := ""
	for u in list.get("users", []):
		if u.name == "Bhai":
			bhai_id = u.id
	var rm: Dictionary = await Sync.change_user(bhai_id, {"remove": true})
	check(not rm.has("error"), "admin removes Bhai")
	A = phone()
	use(B)
	notices.clear()
	await Sync.sync_now()
	check(not Sync.enabled() and Sync.status == "removed" and Lang.t("removed_title") in notices, "Bhai's phone stops sharing")

	# Lost admin phone: recovery code on a new phone.
	blank_phone()
	e = await Sync.join(s.recovery_code, true)
	check(e == "" and Sync.role() == "admin" and DB.data.payments.size() > 0, "recovery makes a new admin phone with all data")
	use(A)
	await Sync.sync_now()
	check(not Sync.enabled(), "old admin phone stops after recovery")
	_finish()


func _finish() -> void:
	print("Sync flows: %d checks, %d failed" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)
