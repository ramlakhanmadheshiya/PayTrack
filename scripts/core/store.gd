extends Node
## The app's data (autoload "DB"). Everything lives in one dictionary saved as
## JSON in user:// (IndexedDB in the browser). All changes go through methods
## here so balances and pay periods can never get out of step.

signal changed

const SAVE_PATH := "user://paytrack.json"
const PREV_PATH := "user://paytrack.previous.json"
const IMPORT_UNDO_PATH := "user://paytrack.before-import.json"
const FORMAT := 1
const POSTS := ["BM", "F", "H"]

var data: Dictionary = {}
var save_enabled := true


func _ready() -> void:
	load_data()
	Lang.set_lang(String(data.settings.get("lang", "en")), false)


# --------------------------------------------------------------------------
# Load / save
# --------------------------------------------------------------------------

static func empty_data() -> Dictionary:
	return {
		"format": FORMAT,
		"mills": [],
		"people": [],
		"khatas": [],
		"entries": [],
		"payments": [],
		"sheets": [],
		"log": [],
		"settings": {"lang": "en", "last_export": "", "text_size": 1.0},
		"meta": {"updated": 0, "created": int(Time.get_unix_time_from_system())},
	}


func load_data() -> void:
	data = empty_data()
	if not save_enabled:
		return
	for path in [SAVE_PATH, PREV_PATH]:
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and _looks_valid(parsed):
				data = normalize(parsed)
				return


func reset_for_tests() -> void:
	save_enabled = false
	data = empty_data()


func save() -> void:
	data.meta.updated = int(Time.get_unix_time_from_system())
	if save_enabled:
		_write_file(SAVE_PATH, JSON.stringify(data))
	changed.emit()


func _write_file(path: String, text: String) -> void:
	if FileAccess.file_exists(path) and path == SAVE_PATH:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(PREV_PATH))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot save " + path)
		return
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


static func _looks_valid(d: Dictionary) -> bool:
	for k in ["mills", "people", "khatas", "entries", "payments"]:
		if not (d.get(k) is Array):
			return false
	return true


static func normalize(d: Dictionary) -> Dictionary:
	## JSON gives every number back as float; money and days are ints.
	var out := empty_data()
	for k in ["mills", "people", "khatas", "entries", "payments"]:
		out[k] = d.get(k, [])
	for k in ["sheets", "log"]:
		if d.get(k) is Array:
			out[k] = d[k]
	for l in out.log:
		l.t = int(l.get("t", 0))
	if d.get("settings") is Dictionary:
		out.settings.merge(d.settings, true)
	if d.get("meta") is Dictionary:
		out.meta.merge(d.meta, true)
	out.meta.updated = int(out.meta.get("updated", 0))
	for m in out.mills:
		for r in m.get("rates", []):
			r.f = int(r.get("f", 0))
			r.h = int(r.get("h", 0))
	for p in out.people:
		for s in p.get("salaries", []):
			s.amount = int(s.get("amount", 0))
	for k in out.khatas:
		k.opening = int(k.get("opening", 0))
	for e in out.entries:
		e.amount = int(e.get("amount", 0))
		e.created = int(e.get("created", 0))
	for pay in out.payments:
		for key in ["earnings", "prev_balance", "kharchi", "advance", "payout", "received", "adjust", "due", "paid", "new_balance", "created", "count_kharchi"]:
			pay[key] = int(pay.get(key, 0))
		for r in pay.get("rows", []):
			r.rate = int(r.get("rate", 0))
			r.amount = int(r.get("amount", 0))
			r.days = int(r.get("days", 0))
			for mo in r.get("months", []):
				mo.days = int(mo.get("days", 0))
				mo.salary = int(mo.get("salary", 0))
				mo.amount = int(mo.get("amount", 0))
	return out


# --------------------------------------------------------------------------
# Ids and lookups
# --------------------------------------------------------------------------

func new_id(prefix: String) -> String:
	return "%s%d%04x" % [prefix, Time.get_unix_time_from_system(), randi() % 65536]


func _find(list: Array, id: String) -> Dictionary:
	for x in list:
		if x.get("id", "") == id:
			return x
	return {}


func mill(id: String) -> Dictionary:
	return _find(data.mills, id)


func person(id: String) -> Dictionary:
	return _find(data.people, id)


func khata(id: String) -> Dictionary:
	return _find(data.khatas, id)


func entry(id: String) -> Dictionary:
	return _find(data.entries, id)


func payment(id: String) -> Dictionary:
	return _find(data.payments, id)


func setting(key: String, default = null):
	return data.settings.get(key, default)


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save()


static func _norm_name(s: String) -> String:
	return " ".join(s.strip_edges().to_lower().split(" ", false))


static func _by_name(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0


# --------------------------------------------------------------------------
# Mills
# --------------------------------------------------------------------------

func mills_list(include_archived := false) -> Array:
	var out := []
	for m in data.mills:
		if include_archived or not m.get("archived", false):
			out.append(m)
	out.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)) if a.get("order", 0) != b.get("order", 0) else _by_name(a, b))
	return out


func mill_name_taken(name: String, except_id := "") -> bool:
	for m in data.mills:
		if m.id != except_id and _norm_name(m.name) == _norm_name(name):
			return true
	return false


func add_mill(name: String, f_rate: int, h_rate: int, from := "") -> Dictionary:
	var m := {
		"id": new_id("m"),
		"name": name.strip_edges(),
		"rates": [{"from": from if from != "" else "2000-01-01", "f": f_rate, "h": h_rate}],
		"archived": false,
		"order": data.mills.size(),
	}
	data.mills.append(m)
	log_event("mill_added", [m.name])
	save()
	return m


func rename_mill(id: String, name: String) -> void:
	var old: String = mill(id).name
	mill(id).name = name.strip_edges()
	if old != mill(id).name:
		log_event("mill_renamed", [old, mill(id).name])
	save()


func set_mill_archived(id: String, archived: bool) -> void:
	mill(id).archived = archived
	log_event("mill_hidden" if archived else "mill_shown", [mill(id).name])
	save()


func delete_mill(id: String) -> void:
	## Removes the mill and everyone's work there. Saved payments keep the
	## mill's name in their own rows, so old bills still read correctly.
	for i in data.mills.size():
		if data.mills[i].id == id:
			log_event("mill_deleted", [data.mills[i].name])
			data.mills.remove_at(i)
			break
	for sh in data.sheets:
		var keep_m := []
		for sm in sh.mills:
			if sm.mill_id != id:
				keep_m.append(sm)
		sh.mills = keep_m
	for p in data.people:
		var keep := []
		for po in p.posts:
			if po.mill_id != id:
				keep.append(po)
		p.posts = keep
	save()


func add_mill_rate(id: String, from: String, f_rate: int, h_rate: int) -> void:
	var m := mill(id)
	log_event("mill_rates", [m.name, f_rate, h_rate])
	var rates: Array = m.rates
	for r in rates:
		if r.from == from:
			r.f = f_rate
			r.h = h_rate
			save()
			return
	rates.append({"from": from, "f": f_rate, "h": h_rate})
	rates.sort_custom(func(a, b): return a.from < b.from)
	save()


func delete_mill_rate(id: String, from: String) -> void:
	var m := mill(id)
	if m.rates.size() <= 1:
		return
	for i in m.rates.size():
		if m.rates[i].from == from:
			m.rates.remove_at(i)
			break
	save()


func mill_used_in_payments(id: String) -> bool:
	for pay in data.payments:
		for r in pay.get("rows", []):
			if r.get("mill_id", "") == id:
				return true
	return false


func set_mill_rates(id: String, f_rate: int, h_rate: int) -> void:
	## From the mill's edit screen. Before any payment uses the mill the rate is
	## simply corrected; after that the new rate starts today, so saved bills
	## and older work keep the old rate.
	var m := mill(id)
	var today := Dates.today()
	if mill_rate(id, "F", today) == f_rate and mill_rate(id, "H", today) == h_rate:
		return
	if not mill_used_in_payments(id):
		m.rates = [{"from": "2000-01-01", "f": f_rate, "h": h_rate}]
		log_event("mill_rates", [m.name, f_rate, h_rate])
		save()
	else:
		add_mill_rate(id, today, f_rate, h_rate)


func mill_rate(id: String, post: String, date: String) -> int:
	var m := mill(id)
	if m.is_empty():
		return 0
	return Calc.value_on(m.rates, date, "f" if post == "F" else "h")


func mill_workers(id: String) -> Array:
	var out := []
	for p in people_list():
		for po in p.posts:
			if po.mill_id == id:
				out.append(p)
				break
	return out


# --------------------------------------------------------------------------
# People and khatas
# --------------------------------------------------------------------------

func people_list(include_archived := false) -> Array:
	var out := []
	for p in data.people:
		if include_archived or not p.get("archived", false):
			out.append(p)
	out.sort_custom(_by_name)
	return out


func find_person_by_name(name: String) -> Dictionary:
	for p in data.people:
		if _norm_name(p.name) == _norm_name(name):
			return p
	return {}


func person_name_taken(name: String, except_id := "") -> bool:
	var p := find_person_by_name(name)
	return not p.is_empty() and p.id != except_id


func add_person(name: String, posts: Array = [], salary := 0, salary_from := "") -> Dictionary:
	var p := {
		"id": new_id("p"),
		"name": name.strip_edges(),
		"khata_id": "",
		"posts": [],
		"salaries": [],
		"phone": "",
		"archived": false,
		"created": int(Time.get_unix_time_from_system()),
	}
	var k := {"id": new_id("k"), "payee_id": p.id, "members": [p.id], "opening": 0, "start": "", "paid_upto": "", "archived": false}
	p.khata_id = k.id
	for po in posts:
		p.posts.append({"mill_id": po.mill_id, "post": po.post})
	if salary > 0:
		p.salaries.append({"from": salary_from if salary_from != "" else "2000-01-01", "amount": salary})
	data.people.append(p)
	data.khatas.append(k)
	log_event("person_added", [p.name])
	save()
	return p


func rename_person(id: String, name: String) -> void:
	var old: String = person(id).name
	person(id).name = name.strip_edges()
	if old != person(id).name:
		log_event("person_renamed", [old, person(id).name])
	save()


func set_hindi_spelling(kind: String, id: String, spelling: String) -> void:
	## kind "person" or "mill". Empty = written from the English name.
	var rec := person(id) if kind == "person" else mill(id)
	if rec.is_empty():
		return
	spelling = spelling.strip_edges()
	if spelling == "":
		rec.erase("hi")
	else:
		rec.hi = spelling
	save()


func set_person_phone(id: String, phone: String) -> void:
	person(id).phone = phone.strip_edges()
	save()


func set_person_archived(id: String, archived: bool) -> void:
	person(id).archived = archived
	log_event("person_hidden" if archived else "person_shown", [person(id).name])
	save()


func has_post(pid: String, mill_id: String, post: String) -> bool:
	for po in person(pid).posts:
		if po.mill_id == mill_id and po.post == post:
			return true
	return false


func add_post(pid: String, mill_id: String, post: String) -> void:
	if has_post(pid, mill_id, post):
		return
	person(pid).posts.append({"mill_id": mill_id, "post": post})
	save()


func remove_post(pid: String, mill_id: String, post: String) -> void:
	var p := person(pid)
	for i in p.posts.size():
		if p.posts[i].mill_id == mill_id and p.posts[i].post == post:
			p.posts.remove_at(i)
			break
	save()


func sorted_posts(pid: String) -> Array:
	var p := person(pid)
	var out: Array = p.get("posts", []).duplicate()
	var order := {}
	var i := 0
	for m in mills_list(true):
		order[m.id] = i
		i += 1
	out.sort_custom(func(a, b):
		if a.mill_id != b.mill_id:
			return int(order.get(a.mill_id, 999)) < int(order.get(b.mill_id, 999))
		return POSTS.find(a.post) < POSTS.find(b.post))
	return out


func posts_at(pid: String, mill_id: String) -> Array:
	var out := []
	for post in POSTS:
		if has_post(pid, mill_id, post):
			out.append(post)
	return out


func set_posts_at(pid: String, mill_id: String, posts: Array) -> void:
	## Replaces what this person does at one mill (empty = not working there).
	var p := person(pid)
	var keep := []
	for po in p.posts:
		if po.mill_id != mill_id:
			keep.append(po)
	for post in POSTS:
		if post in posts:
			keep.append({"mill_id": mill_id, "post": post})
	p.posts = keep
	log_event("work_set" if not posts.is_empty() else "work_removed", [p.name, mill(mill_id).get("name", "?"), " ".join(posts)])
	save()


func mills_of(pid: String) -> Array:
	## Mill ids this person works at, in mill order.
	var out := []
	for po in sorted_posts(pid):
		if not po.mill_id in out:
			out.append(po.mill_id)
	return out


func can_delete_person(pid: String) -> bool:
	## Only someone added by mistake: no kharchi, no payments, not in a family.
	var k := khata_of(pid)
	if k.is_empty() or k.members.size() > 1:
		return false
	for e in data.entries:
		if e.person_id == pid or e.khata_id == k.id:
			return false
	return payments_of(k.id).is_empty()


func delete_person(pid: String) -> bool:
	if not can_delete_person(pid):
		return false
	var kid: String = person(pid).khata_id
	log_event("person_deleted", [person(pid).name])
	for sh in data.sheets:
		for sm in sh.mills:
			var keep := []
			for w in sm.workers:
				if w.person_id != pid:
					keep.append(w)
			sm.workers = keep
	for i in data.people.size():
		if data.people[i].id == pid:
			data.people.remove_at(i)
			break
	for i in data.khatas.size():
		if data.khatas[i].id == kid:
			data.khatas.remove_at(i)
			break
	save()
	return true


func family_khatas() -> Array:
	var out := []
	for k in active_khatas():
		if k.members.size() > 1:
			out.append(k)
	return out


func family_title(kid: String) -> String:
	return Lang.t("family_title", [khata_title(kid)]) if is_family(kid) else khata_title(kid)


func is_master(pid: String) -> bool:
	for po in person(pid).get("posts", []):
		if po.post == "BM":
			return true
	return false


func add_salary(pid: String, from: String, amount: int) -> void:
	var p := person(pid)
	log_event("salary_set", [p.name, amount])
	for s in p.salaries:
		if s.from == from:
			s.amount = amount
			save()
			return
	p.salaries.append({"from": from, "amount": amount})
	p.salaries.sort_custom(func(a, b): return a.from < b.from)
	save()


func delete_salary(pid: String, from: String) -> void:
	var p := person(pid)
	if p.salaries.size() <= 1:
		return
	for i in p.salaries.size():
		if p.salaries[i].from == from:
			p.salaries.remove_at(i)
			break
	save()


func salary_on(pid: String, date: String) -> int:
	return Calc.value_on(person(pid).get("salaries", []), date, "amount")


func khata_of(pid: String) -> Dictionary:
	return khata(person(pid).get("khata_id", ""))


func khata_members(kid: String) -> Array:
	## Payee first, then the other members by name.
	var k := khata(kid)
	var out := []
	var others := []
	for mid in k.get("members", []):
		var p := person(mid)
		if p.is_empty():
			continue
		if mid == k.payee_id:
			out.append(p)
		else:
			others.append(p)
	others.sort_custom(_by_name)
	return out + others


func is_family(kid: String) -> bool:
	return khata(kid).get("members", []).size() > 1


func khata_title(kid: String) -> String:
	var k := khata(kid)
	var payee := person(k.get("payee_id", ""))
	return String(payee.get("name", "?"))


func khata_subtitle(kid: String) -> String:
	var names := []
	for p in khata_members(kid):
		if p.id != khata(kid).payee_id:
			names.append(p.name)
	return ", ".join(names)


func active_khatas() -> Array:
	var out := []
	for k in data.khatas:
		if k.get("archived", false):
			continue
		var payee := person(k.payee_id)
		if payee.is_empty() or payee.get("archived", false):
			continue
		out.append(k)
	out.sort_custom(func(a, b): return khata_title(a.id).naturalnocasecmp_to(khata_title(b.id)) < 0)
	return out


func set_opening_balance(kid: String, amount: int, start := "") -> void:
	var k := khata(kid)
	k.opening = amount
	log_event("opening_set", [khata_title(kid), amount])
	if start != "":
		k.start = start
	save()


func set_khata_start(kid: String, start: String) -> void:
	khata(kid).start = start
	save()


func join_family(payee_id: String, member_id: String) -> String:
	## Moves member's own khata into the payee's khata. Returns "" or an error key.
	if payee_id == member_id:
		return "err_same_person"
	var fam := khata_of(payee_id)
	var own := khata_of(member_id)
	if fam.id == own.id:
		return "err_already_family"
	if own.members.size() > 1:
		return "err_member_has_family"
	# Open kharchi/advances move with the person; a settled balance (jama or
	# advance left) is carried into the family as one adjustment line.
	for e in data.entries:
		if e.khata_id == own.id and e.payment_id == "":
			e.khata_id = fam.id
	var carried_settled := settled_balance(own.id)
	if carried_settled != 0:
		data.entries.append(_new_entry(fam.id, member_id, "adjust", carried_settled, Dates.today(), "balance_from_member"))
	own.archived = true
	fam.members.append(member_id)
	person(member_id).khata_id = fam.id
	log_event("group_joined", [person(member_id).name, khata_title(fam.id)])
	save()
	return ""


func leave_family(member_id: String) -> String:
	var fam := khata_of(member_id)
	if fam.payee_id == member_id:
		return "err_payee_cannot_leave"
	fam.members.erase(member_id)
	var k := {"id": new_id("k"), "payee_id": member_id, "members": [member_id], "opening": 0, "start": "", "paid_upto": fam.get("paid_upto", ""), "archived": false}
	data.khatas.append(k)
	person(member_id).khata_id = k.id
	log_event("group_left", [person(member_id).name, khata_title(fam.id)])
	save()
	return ""


func set_payee(kid: String, pid: String) -> void:
	var k := khata(kid)
	if pid in k.members:
		k.payee_id = pid
		log_event("group_head", [person(pid).name])
		save()


# --------------------------------------------------------------------------
# Entries: kharchi, advance, jama payout, money received
# --------------------------------------------------------------------------

func _new_entry(kid: String, pid: String, type: String, amount: int, date: String, note := "", payment_id := "") -> Dictionary:
	return {
		"id": new_id("e"),
		"khata_id": kid,
		"person_id": pid,
		"type": type,
		"amount": amount,
		"date": date,
		"note": note,
		"created": int(Time.get_unix_time_from_system() * 1000) + randi() % 1000,
		"payment_id": payment_id,
	}


func add_entry(pid: String, type: String, amount: int, date: String, note := "") -> Dictionary:
	var e := _new_entry(person(pid).khata_id, pid, type, amount, date, note)
	data.entries.append(e)
	log_event("entry_added", [person(pid).name, amount], type)
	save()
	return e


func update_entry(id: String, type: String, amount: int, date: String, note: String) -> bool:
	var e := entry(id)
	if e.is_empty() or e.payment_id != "":
		return false
	e.type = type
	e.amount = amount
	e.date = date
	e.note = note
	log_event("entry_edited", [person(e.person_id).get("name", "?"), amount], type)
	save()
	return true


func delete_entry(id: String) -> bool:
	for i in data.entries.size():
		if data.entries[i].id == id:
			if data.entries[i].payment_id != "":
				return false
			var de: Dictionary = data.entries[i]
			log_event("entry_deleted", [person(de.person_id).get("name", "?"), de.amount], de.type)
			data.entries.remove_at(i)
			save()
			return true
	return false


func open_entries(kid: String, upto_date := "") -> Array:
	var out := []
	for e in data.entries:
		# Balance carry-overs ("adjust") always count, whatever their date.
		if e.khata_id == kid and e.payment_id == "" and (upto_date == "" or e.date <= upto_date or e.type == "adjust"):
			out.append(e)
	out.sort_custom(func(a, b): return a.date < b.date if a.date != b.date else a.created < b.created)
	return out


func entries_on(date: String) -> Array:
	var out := []
	for e in data.entries:
		if e.date == date and e.type != "adjust":
			out.append(e)
	out.sort_custom(func(a, b): return a.created > b.created)
	return out


func entries_of_khata(kid: String) -> Array:
	var out := []
	for e in data.entries:
		if e.khata_id == kid:
			out.append(e)
	return out


# --------------------------------------------------------------------------
# Balances
# --------------------------------------------------------------------------

func payments_of(kid: String) -> Array:
	var out := []
	for p in data.payments:
		if p.khata_id == kid:
			out.append(p)
	out.sort_custom(func(a, b): return a.created < b.created)
	return out


func last_payment(kid: String) -> Dictionary:
	var list := payments_of(kid)
	return {} if list.is_empty() else list[-1]


func settled_balance(kid: String) -> int:
	var last := last_payment(kid)
	if not last.is_empty():
		return int(last.new_balance)
	return int(khata(kid).get("opening", 0))


func live_balance(kid: String) -> int:
	## Settled balance plus everything taken / given since (positive = you owe them).
	var b := settled_balance(kid)
	for e in open_entries(kid):
		b += Calc.entry_effect(e)
	return b


func balance(kid: String) -> int:
	## The balance shown in the app: jama (+) or advance left (−).
	## Kharchi is not advance: it is kept apart and cut at the next payment.
	var b := settled_balance(kid)
	for e in open_entries(kid):
		if e.type != "kharchi":
			b += Calc.entry_effect(e)
	return b


func open_kharchi(kid: String) -> int:
	var t := 0
	for e in open_entries(kid):
		if e.type == "kharchi":
			t += int(e.amount)
	return t


func totals() -> Dictionary:
	var jama := 0
	var advance := 0
	for k in active_khatas():
		var b := balance(k.id)
		if b > 0:
			jama += b
		elif b < 0:
			advance += -b
	return {"jama": jama, "advance": advance}


# --------------------------------------------------------------------------
# Payments
# --------------------------------------------------------------------------

func next_work_from(kid: String) -> String:
	var k := khata(kid)
	if String(k.get("paid_upto", "")) != "":
		return Dates.add_days(k.paid_upto, 1)
	return String(k.get("start", ""))


func make_draft(kid: String, pay_date: String, upto := "", only_mill := "") -> Dictionary:
	## A fresh, unsaved payment for one khata, with one row per member / mill / post.
	var from := next_work_from(kid)
	if upto == "":
		upto = Calc.default_upto(pay_date, from)
	if from == "":
		from = Dates.first_of_month(upto)
	var d := {
		"khata_id": kid,
		"date": pay_date,
		"from": from,
		"upto": upto,
		"from_locked": String(khata(kid).get("paid_upto", "")) != "",
		"rows": [],
		"choice": "full",
		"custom": 0,
		"only_mill": only_mill,
	}
	rebuild_rows(d)
	return d


func rebuild_rows(d: Dictionary) -> void:
	## Recreates rows for the khata's current posts, keeping any typed numbers.
	var old := {}
	for r in d.get("rows", []):
		old[_row_key(r)] = r
	var rows := []
	for p in khata_members(d.khata_id):
		for po in sorted_posts(p.id):
			var r := _blank_row(p.id, po.mill_id, po.post, d)
			_fill_from_sheets(r, d)
			var key := _row_key(r)
			# Numbers typed on the payment page win over the sheet's.
			if old.has(key) and _row_typed(old[key]):
				var o: Dictionary = old[key]
				r.att = o.get("att", 0.0)
				r.hr = o.get("hr", 0.0)
				r.mode = o.get("mode", "normal")
				if o.get("rate_custom", false):
					r.rate = o.rate
					r.rate_custom = true
				if o.get("days_custom", false):
					r.days = o.days
					r.days_custom = true
				var old_months := {}
				for mo in o.get("months", []):
					old_months[mo.ym] = mo
				for mo in r.months:
					if old_months.has(mo.ym):
						mo.att = old_months[mo.ym].get("att", 0.0)
			r.amount = Calc.row_amount(r)
			rows.append(r)
	d.rows = rows


func _fill_from_sheets(r: Dictionary, d: Dictionary) -> void:
	## Attendance written ahead of time on the salary sheets.
	var sa := sheet_att_for(r.person_id, r.mill_id, r.post, d.from, d.upto)
	if sa.yms.is_empty():
		return
	r.att = sa.att
	r.hr = sa.hr if r.post != "BM" else 0.0
	for mo in r.months:
		if sa.months.has(mo.ym):
			mo.att = sa.months[mo.ym]
	# A master's pay over two months is worked out month by month.
	if r.post == "BM" and r.months.size() > 1:
		r.mode = "split"
	r.sheet_yms = sa.yms
	r.sheet_att = r.att
	r.sheet_hr = r.hr
	r.sheet_months = sa.months.duplicate()


func _row_typed(o: Dictionary) -> bool:
	## True when the row's numbers were changed on the payment page.
	if o.get("rate_custom", false) or o.get("days_custom", false):
		return true
	if not o.has("sheet_yms"):
		return Calc.row_has_work(o) or o.get("mode", "normal") != "normal"
	if float(o.get("att", 0.0)) != float(o.get("sheet_att", 0.0)) or float(o.get("hr", 0.0)) != float(o.get("sheet_hr", 0.0)):
		return true
	var sm: Dictionary = o.get("sheet_months", {})
	for mo in o.get("months", []):
		if float(mo.get("att", 0.0)) != float(sm.get(mo.ym, 0.0)):
			return true
	return false


func _row_key(r: Dictionary) -> String:
	return "%s|%s|%s" % [r.person_id, r.mill_id, r.post]


func _blank_row(pid: String, mill_id: String, post: String, d: Dictionary) -> Dictionary:
	var r := {
		"person_id": pid,
		"mill_id": mill_id,
		"post": post,
		"att": 0.0,
		"hr": 0.0,
		"rate": 0,
		"rate_custom": false,
		"mode": "normal",
		"days": Calc.default_bm_days(d.from, d.upto),
		"days_custom": false,
		"months": [],
		"amount": 0,
	}
	if post == "BM":
		r.rate = salary_on(pid, d.date)
		for mo in Dates.months_between(d.from, d.upto):
			r.months.append({"ym": mo.ym, "days": mo.days, "salary": salary_on(pid, mo.from), "att": 0.0, "amount": 0, "from": mo.from, "upto": mo.upto})
	else:
		r.rate = mill_rate(mill_id, post, d.date)
	return r


func draft_hisab(d: Dictionary) -> Dictionary:
	for r in d.rows:
		r.amount = Calc.row_amount(r)
		if r.post == "BM":
			var amounts := Calc.month_amounts(r.months)
			for i in r.months.size():
				r.months[i].amount = amounts[i]
	var h := Calc.hisab(settled_balance(d.khata_id), d.rows, open_entries(d.khata_id, d.date))
	h.paid = Calc.paid_for_choice(h.due, d.get("choice", "full"), int(d.get("custom", 0)))
	h.new_balance = h.due - h.paid
	return h


func validate_draft(d: Dictionary) -> String:
	if not Dates.valid(d.from) or not Dates.valid(d.upto) or not Dates.valid(d.date):
		return "err_bad_date"
	if d.upto < d.from:
		return "err_upto_before_from"
	if d.upto > d.date:
		return "err_upto_after_pay"
	var last := last_payment(d.khata_id)
	if not last.is_empty() and d.date < String(last.date):
		return "err_pay_before_last"
	return ""


func commit_payment(d: Dictionary) -> Dictionary:
	var err := validate_draft(d)
	if err != "":
		return {"error": err}
	var k := khata(d.khata_id)
	var h := draft_hisab(d)
	var entries := open_entries(d.khata_id, d.date)
	var rows := []
	for r in d.rows:
		if Calc.row_has_work(r):
			var saved: Dictionary = r.duplicate(true)
			saved.person_name = person(r.person_id).get("name", "")
			saved.mill_name = mill(r.mill_id).get("name", "")
			rows.append(saved)
	var members := []
	for p in khata_members(d.khata_id):
		members.append({"id": p.id, "name": p.name})
	var pay := {
		"id": new_id("pay"),
		"khata_id": d.khata_id,
		"date": d.date,
		"from": d.from,
		"upto": d.upto,
		"rows": rows,
		"members": members,
		"payee_name": khata_title(d.khata_id),
		"earnings": h.earnings,
		"prev_balance": h.prev_balance,
		"kharchi": h.kharchi,
		"count_kharchi": h.count_kharchi,
		"advance": h.advance,
		"payout": h.payout,
		"received": h.received,
		"adjust": h.adjust,
		"due": h.due,
		"paid": h.paid,
		"new_balance": h.new_balance,
		"choice": d.get("choice", "full"),
		"entry_ids": [],
		"prev_paid_upto": String(k.get("paid_upto", "")),
		"created": int(Time.get_unix_time_from_system() * 1000) + randi() % 1000,
	}
	# Never earlier than the newest payment of this khata, so ordering stays right.
	var last := last_payment(d.khata_id)
	if not last.is_empty() and pay.created <= int(last.created):
		pay.created = int(last.created) + 1
	for e in entries:
		e.payment_id = pay.id
		pay.entry_ids.append(e.id)
	k.paid_upto = d.upto
	data.payments.append(pay)
	log_event("payment_made", [pay.payee_name, pay.paid])
	save()
	return pay


func can_undo_payment(pay_id: String) -> bool:
	var pay := payment(pay_id)
	if pay.is_empty():
		return false
	var last := last_payment(pay.khata_id)
	return not last.is_empty() and last.id == pay_id and not khata(pay.khata_id).get("archived", false)


func undo_payment(pay_id: String) -> bool:
	if not can_undo_payment(pay_id):
		return false
	var pay := payment(pay_id)
	for e in data.entries:
		if e.payment_id == pay_id:
			e.payment_id = ""
	khata(pay.khata_id).paid_upto = pay.prev_paid_upto
	data.payments.erase(pay)
	log_event("payment_undone", [pay.payee_name, pay.paid])
	save()
	return true


func draft_from_payment(pay: Dictionary) -> Dictionary:
	## A draft with the same numbers as a saved payment (to correct it).
	var rows: Array = pay.get("rows", []).duplicate(true)
	for r in rows:
		r.rate_custom = true
		r.days_custom = true
	var d := {
		"khata_id": pay.khata_id,
		"date": pay.date,
		"from": pay.from,
		"upto": pay.upto,
		"from_locked": String(pay.get("prev_paid_upto", "")) != "",
		"upto_custom": true,
		"rows": rows,
		"choice": pay.get("choice", "full"),
		"custom": int(pay.get("paid", 0)),
		"choice_set": true,
		"only_mill": "",
	}
	rebuild_rows(d)
	return d


func payments_list() -> Array:
	var out: Array = data.payments.duplicate()
	out.sort_custom(func(a, b): return a.date > b.date if a.date != b.date else a.created > b.created)
	return out


func payment_entries(pay: Dictionary) -> Array:
	var out := []
	for e in data.entries:
		if e.payment_id == pay.id:
			out.append(e)
	out.sort_custom(func(a, b): return a.date < b.date if a.date != b.date else a.created < b.created)
	return out


# --------------------------------------------------------------------------
# Activity log: every step, newest last. Shown on the Activity page.
# --------------------------------------------------------------------------

const LOG_MAX := 5000


func log_event(kind: String, args: Array = [], type := "") -> void:
	var l := {"t": int(Time.get_unix_time_from_system()), "d": Dates.today(), "k": kind, "a": args}
	if type != "":
		l.ty = type
	data.log.append(l)
	if data.log.size() > LOG_MAX:
		data.log = data.log.slice(data.log.size() - LOG_MAX)


func log_list() -> Array:
	var out: Array = data.log.duplicate()
	out.reverse()
	return out


# --------------------------------------------------------------------------
# Salary sheets: one per month ("Oct 2026"). Each has the mills added to it
# and, per mill, the workers who worked there that month, in the order added.
# --------------------------------------------------------------------------

func sheet(id: String) -> Dictionary:
	return _find(data.sheets, id)


func sheets_list() -> Array:
	var out: Array = data.sheets.duplicate()
	out.sort_custom(func(a, b): return a.ym > b.ym)
	return out


func sheet_before(sid: String) -> Dictionary:
	## The latest earlier month's sheet that has mills (to repeat it).
	var ym: String = sheet(sid).get("ym", "")
	for sh in sheets_list():
		if sh.ym < ym and not sheet_mill_ids(sh.id).is_empty():
			return sh
	return {}


func sheet_repeat(sid: String, from_sid: String) -> Array:
	## Copies the mills and the worker lists (in order) from another month.
	## Only who works where: no attendance, no money. Hidden mills and people
	## are left out, and anything already on this sheet stays as it is.
	## Returns [mills added, workers added].
	var sh := sheet(sid)
	var src := sheet(from_sid)
	if sh.is_empty() or src.is_empty():
		return [0, 0]
	var n_mills := 0
	var n_workers := 0
	for sm in src.mills:
		var m := mill(sm.mill_id)
		if m.is_empty() or m.get("archived", false):
			continue
		var dst := _sheet_mill(sid, sm.mill_id)
		if dst.is_empty():
			dst = {"mill_id": sm.mill_id, "workers": []}
			sh.mills.append(dst)
			n_mills += 1
		var have := {}
		for w in dst.workers:
			have[w.person_id] = true
		for w in sm.workers:
			var p := person(w.person_id)
			if p.is_empty() or p.get("archived", false) or have.has(w.person_id):
				continue
			dst.workers.append({"person_id": w.person_id, "posts": w.posts.duplicate()})
			have[w.person_id] = true
			_remember_posts(w.person_id, sm.mill_id, w.posts)
			n_workers += 1
	if n_mills + n_workers > 0:
		log_event("sheet_repeated", [sh.ym, src.ym])
		save()
	return [n_mills, n_workers]


func sheet_counts(sid: String) -> Array:
	## [mills, workers] on a sheet (a worker at two mills counts twice).
	var ids := sheet_mill_ids(sid)
	var w := 0
	for mid in ids:
		w += sheet_workers(sid, mid).size()
	return [ids.size(), w]


func sheet_for(ym: String) -> Dictionary:
	for sh in data.sheets:
		if sh.ym == ym:
			return sh
	return {}


func add_sheet(ym: String) -> Dictionary:
	var have := sheet_for(ym)
	if not have.is_empty():
		return have
	var sh := {"id": new_id("s"), "ym": ym, "mills": [], "created": int(Time.get_unix_time_from_system())}
	data.sheets.append(sh)
	log_event("sheet_added", [ym])
	save()
	return sh


func delete_sheet(id: String) -> void:
	var sh := sheet(id)
	if sh.is_empty():
		return
	log_event("sheet_deleted", [sh.ym])
	data.sheets.erase(sh)
	save()


func _sheet_mill(sid: String, mid: String) -> Dictionary:
	for sm in sheet(sid).get("mills", []):
		if sm.mill_id == mid:
			return sm
	return {}


func sheet_mill_ids(sid: String) -> Array:
	var out := []
	for sm in sheet(sid).get("mills", []):
		if not mill(sm.mill_id).is_empty():
			out.append(sm.mill_id)
	return out


func sheet_add_mills(sid: String, mill_ids: Array) -> void:
	var sh := sheet(sid)
	if sh.is_empty():
		return
	for mid in mill_ids:
		if _sheet_mill(sid, mid).is_empty() and not mill(mid).is_empty():
			sh.mills.append({"mill_id": mid, "workers": []})
			log_event("sheet_mill_added", [sh.ym, mill(mid).name])
	save()


func sheet_remove_mill(sid: String, mid: String) -> void:
	var sh := sheet(sid)
	var sm := _sheet_mill(sid, mid)
	if sm.is_empty():
		return
	sh.mills.erase(sm)
	log_event("sheet_mill_removed", [sh.ym, mill(mid).get("name", "?")])
	save()


func sheet_workers(sid: String, mid: String) -> Array:
	## [{person_id, posts}] in the order they were added (people removed from
	## PayTrack are skipped).
	var out := []
	for w in _sheet_mill(sid, mid).get("workers", []):
		if not person(w.person_id).is_empty():
			out.append(w)
	return out


func sheet_worker_count(sid: String) -> int:
	var seen := {}
	for sm in sheet(sid).get("mills", []):
		for w in sm.workers:
			if not person(w.person_id).is_empty():
				seen[w.person_id] = true
	return seen.size()


func sheet_posts(sid: String, mid: String, pid: String) -> Array:
	for w in _sheet_mill(sid, mid).get("workers", []):
		if w.person_id == pid:
			return w.posts
	return []


func sheet_set_worker(sid: String, mid: String, pid: String, posts: Array) -> void:
	## Adds (at the end) or updates a worker on this month's mill list.
	## Empty posts removes them from the list. Their work at the mill is also
	## remembered on the person, so payments know which rows to show.
	var sm := _sheet_mill(sid, mid)
	if sm.is_empty():
		return
	var ym: String = sheet(sid).ym
	var ordered := []
	for post in POSTS:
		if post in posts:
			ordered.append(post)
	for i in sm.workers.size():
		if sm.workers[i].person_id == pid:
			if ordered.is_empty():
				sm.workers.remove_at(i)
				log_event("sheet_worker_removed", [ym, mill(mid).name, person(pid).name])
			else:
				sm.workers[i].posts = ordered
			_remember_posts(pid, mid, ordered)
			save()
			return
	if ordered.is_empty():
		return
	sm.workers.append({"person_id": pid, "posts": ordered})
	log_event("sheet_worker_added", [ym, mill(mid).name, person(pid).name, " ".join(ordered)])
	_remember_posts(pid, mid, ordered)
	save()


# Attendance written on the sheet ahead of payday. The payment page fills
# itself from it (and can still be changed there).

func _sheet_worker(sid: String, mid: String, pid: String) -> Dictionary:
	for w in _sheet_mill(sid, mid).get("workers", []):
		if w.person_id == pid:
			return w
	return {}


func sheet_att(sid: String, mid: String, pid: String, post: String) -> Dictionary:
	## {att, hr} for one worker's post that month (0 when nothing written yet).
	var w := _sheet_worker(sid, mid, pid)
	var a: Dictionary = w.get("att", {}).get(post, {})
	return {"att": float(a.get("att", 0.0)), "hr": float(a.get("hr", 0.0))}


func sheet_set_att(sid: String, mid: String, pid: String, post: String, key: String, value: float) -> void:
	var w := _sheet_worker(sid, mid, pid)
	if w.is_empty():
		return
	if not w.has("att"):
		w.att = {}
	if not w.att.has(post):
		w.att[post] = {"att": 0.0, "hr": 0.0}
	w.att[post][key] = maxf(value, 0.0)
	save()


func sheet_filled_count(sid: String, mid: String) -> int:
	## Workers on this mill's list with some attendance written.
	var n := 0
	for w in sheet_workers(sid, mid):
		for post in w.get("att", {}):
			var a: Dictionary = w.att[post]
			if float(a.get("att", 0.0)) > 0 or float(a.get("hr", 0.0)) > 0:
				n += 1
				break
	return n


func sheet_att_for(pid: String, mid: String, post: String, from: String, upto: String) -> Dictionary:
	## Attendance written on the salary sheets for the months in from..upto:
	## {att, hr, months: {ym: att}, yms: [ym...]} (yms empty = nothing written).
	var out := {"att": 0.0, "hr": 0.0, "months": {}, "yms": []}
	if from == "" or upto == "":
		return out
	var ym_from := from.substr(0, 7)
	var ym_upto := upto.substr(0, 7)
	for sh in data.get("sheets", []):
		if sh.ym < ym_from or sh.ym > ym_upto:
			continue
		var w := _sheet_worker(sh.id, mid, pid)
		if w.is_empty() or not w.get("att", {}).has(post):
			continue
		var a: Dictionary = w.att[post]
		var att := float(a.get("att", 0.0))
		var hr := float(a.get("hr", 0.0))
		if att <= 0 and hr <= 0:
			continue
		out.att += att
		out.hr += hr
		out.months[sh.ym] = float(out.months.get(sh.ym, 0.0)) + att
		out.yms.append(sh.ym)
	out.yms.sort()
	return out


func _remember_posts(pid: String, mid: String, posts: Array) -> void:
	for post in posts:
		if not has_post(pid, mid, post):
			person(pid).posts.append({"mill_id": mid, "post": post})


# --------------------------------------------------------------------------
# Clear money only (for testing): people, mills, groups, salary sheets and
# workers stay; kharchi, advances, jama, payments and starting balances go.
# --------------------------------------------------------------------------

func clear_money() -> void:
	data.entries = []
	data.payments = []
	for k in data.khatas:
		k.opening = 0
		k.paid_upto = ""
	log_event("money_cleared", [])
	save()


# --------------------------------------------------------------------------
# Export / import (one fixed file format)
# --------------------------------------------------------------------------

func export_text() -> String:
	var wrapper := {
		"app": "PayTrack",
		"format": FORMAT,
		"exported": Time.get_datetime_string_from_system(false, true),
		"data": data,
	}
	return JSON.stringify(wrapper)


func export_file_name() -> String:
	return "PayTrack-backup-%s.json" % Dates.today()


func mark_exported() -> void:
	data.settings.last_export = Dates.today()
	save()


func parse_import(text: String) -> Dictionary:
	## Returns {"data": ..., "summary": ...} or {"error": key}.
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or parsed.get("app", "") != "PayTrack" or not (parsed.get("data") is Dictionary):
		return {"error": "err_not_paytrack"}
	if int(parsed.get("format", 0)) > FORMAT:
		return {"error": "err_newer_format"}
	if not _looks_valid(parsed.data):
		return {"error": "err_not_paytrack"}
	var incoming := normalize(parsed.data)
	return {
		"data": incoming,
		"exported": parsed.get("exported", ""),
		"summary": {
			"mills": incoming.mills.size(),
			"people": incoming.people.size(),
			"entries": incoming.entries.size(),
			"payments": incoming.payments.size(),
			"sheets": incoming.sheets.size(),
		},
		"local_newer": int(data.meta.get("updated", 0)) > int(incoming.meta.get("updated", 0)) and has_any_data(),
	}


func has_any_data() -> bool:
	return not (data.mills.is_empty() and data.people.is_empty() and data.entries.is_empty() and data.sheets.is_empty())


func apply_import(incoming: Dictionary) -> void:
	if save_enabled:
		_write_file(IMPORT_UNDO_PATH, JSON.stringify(data))
	var keep_lang = data.settings.get("lang", "en")
	data = incoming
	data.settings.lang = keep_lang
	data.settings.last_export = Dates.today()
	log_event("imported", [])
	if save_enabled:
		_write_file(SAVE_PATH, JSON.stringify(data))
	changed.emit()


func can_undo_import() -> bool:
	return save_enabled and FileAccess.file_exists(IMPORT_UNDO_PATH)


func undo_import() -> bool:
	if not can_undo_import():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(IMPORT_UNDO_PATH))
	if not (parsed is Dictionary) or not _looks_valid(parsed):
		return false
	data = normalize(parsed)
	_write_file(SAVE_PATH, JSON.stringify(data))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IMPORT_UNDO_PATH))
	changed.emit()
	return true


func load_sample_data() -> void:
	## Made-up names only – for trying the app.
	data = empty_data()
	data.settings.lang = Lang.lang if Lang else "en"
	var today := Dates.today()
	var start := Dates.first_of_previous_month(today)
	var a := add_mill("Ganga Mill", 285, 420)
	var b := add_mill("Kaveri Mill", 300, 400)
	var m1 := add_person("Ramesh", [{"mill_id": a.id, "post": "BM"}], 32000)
	var w1 := add_person("Kishan", [{"mill_id": a.id, "post": "F"}, {"mill_id": a.id, "post": "H"}])
	var w2 := add_person("Mohan", [{"mill_id": a.id, "post": "F"}, {"mill_id": b.id, "post": "H"}])
	var w3 := add_person("Hari", [{"mill_id": a.id, "post": "H"}])
	var w4 := add_person("Sita", [{"mill_id": a.id, "post": "H"}])
	var w5 := add_person("Gita", [{"mill_id": b.id, "post": "H"}])
	var w6 := add_person("Raju", [{"mill_id": b.id, "post": "F"}, {"mill_id": b.id, "post": "H"}])
	join_family(w3.id, w4.id)
	for p in [m1, w1, w2, w3, w5, w6]:
		set_khata_start(p.khata_id, start)
	add_entry(w1.id, "kharchi", 500, Dates.add_days(today, -6))
	add_entry(w1.id, "kharchi", 300, Dates.add_days(today, -2))
	add_entry(w2.id, "advance", 20000, Dates.add_days(today, -10), "")
	add_entry(w3.id, "kharchi", 1000, Dates.add_days(today, -3))
	add_entry(w4.id, "kharchi", 400, today)
	set_opening_balance(w5.khata_id, 8000)
	# Last month's salary sheet with both mills.
	var sh := add_sheet(start.substr(0, 7))
	sheet_add_mills(sh.id, [a.id, b.id])
	for p in [w1, w3, w4, w2, m1]:
		sheet_set_worker(sh.id, a.id, p.id, posts_at(p.id, a.id))
	for p in [w6, w5, w2]:
		sheet_set_worker(sh.id, b.id, p.id, posts_at(p.id, b.id))
	save()
