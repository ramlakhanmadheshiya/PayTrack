class_name PayrollRepository
extends RefCounted

var path = "user://paytrack.json"
var data: Dictionary
var error = ""
var needs_recovery = false

func _init(save_path: String = "user://paytrack.json") -> void:
	path = save_path
	data = empty()

static func empty() -> Dictionary:
	return {"schema_version": 1, "settings": {"last_backup_at": ""}, "next_id": 1, "persons": [], "mills": [], "rates": [], "salaries": [], "attendance": [], "ledger": [], "settlements": [], "families": [], "audit": []}

func id(prefix: String) -> String:
	var value = "%s-%04d" % [prefix, int(data.next_id)]
	data.next_id = int(data.next_id) + 1
	return value

func find(collection: String, key: String) -> Dictionary:
	for row in data[collection]:
		if row.id == key:
			return row
	return {}

func save() -> bool:
	if needs_recovery:
		error = "Invalid local save preserved. Restore a validated backup before editing."
		return false
	var text = JSON.stringify(data)
	if not validate(JSON.parse_string(text)):
		return false
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Could not write local storage. Export a backup."
		return false
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "Could not finish save; previous copy preserved."
		return false
	return true

func load_data() -> bool:
	if not FileAccess.file_exists(path):
		return true
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not validate(value):
		needs_recovery = true
		error = "Local save is invalid. Working file preserved; restore a backup."
		return false
	data = value
	return true

func validate(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema_version") != 1:
		error = "Unsupported or corrupt data schema."
		return false
	for key in ["persons", "mills", "rates", "salaries", "attendance", "ledger", "settlements", "families", "audit"]:
		if not value.get(key) is Array:
			error = "Missing collection: " + key
			return false
	if not value.get("settings") is Dictionary or not value.get("next_id") is float and not value.get("next_id") is int:
		return false
	var ids = {}
	for key in ["persons", "mills", "rates", "salaries", "attendance", "ledger", "settlements", "families"]:
		for row in value[key]:
			if not row is Dictionary or not row.get("id") is String or ids.has(row.id):
				return false
			ids[row.id] = key
	for key in ["salaries", "attendance", "ledger"]:
		for row in value[key]:
			if ids.get(row.get("person_id")) != "persons":
				return false
	var p = preload("res://scripts/domain/payroll.gd")
	var names = {}
	var maximum = 0
	for key in ids:
		var suffix = str(key).split("-")
		if suffix.size() != 2 or not suffix[1].is_valid_int(): return false
		maximum = maxi(maximum,int(suffix[1]))
	if not integer(value.next_id,1,9000000000000000) or int(value.next_id) <= maximum: return false
	for row in value.persons:
		for field in ["name","payroll_start_date","paid_up_to","family_id"]:
			if not row.get(field) is String: return false
		if not row.get("active") is bool or row.name.strip_edges().is_empty() or names.has(row.name.to_lower()): return false
		names[row.name.to_lower()] = true
		if not p.valid_date(row.payroll_start_date) or (not row.paid_up_to.is_empty() and not p.valid_date(row.paid_up_to)): return false
		if not row.family_id.is_empty() and ids.get(row.family_id) != "families": return false
	for row in value.mills:
		if not row.get("name") is String or not row.get("active") is bool: return false
	for key in ["rates","salaries"]:
		for row in value[key]:
			if not integer(row.get("amount"),0,1000000000) or not row.get("effective_from") is String or not p.valid_date(row.effective_from): return false
			if not row.get("reason") is String or not row.get("at") is String or not integer(row.get("old"),0,1000000000): return false
			if key == "rates" and (ids.get(row.get("mill_id")) != "mills" or row.get("role") not in ["F","H"]): return false
	for row in value.attendance:
		if ids.get(row.get("mill_id")) != "mills" or row.get("role") not in ["BM","F","H"]: return false
		if not row.get("start") is String or not row.get("end") is String or not p.valid_date(row.start) or not p.valid_date(row.end) or row.start > row.end: return false
		for field in ["half_units","minutes","rate"]:
			if not integer(row.get(field),0,1000000000): return false
		if not integer(row.get("split_adjustment",0),-1000000000,1000000000): return false
		if int(row.minutes) % 15 != 0 or (row.role == "BM" and (row.minutes != 0 or row.rate != 0)): return false
		if not row.get("settlement_id") is String or (not row.settlement_id.is_empty() and ids.get(row.settlement_id) != "settlements"): return false
	for event in value.ledger:
		if event.get("kind") not in ["jama","kharchi","advance"] or not integer(event.get("amount"),1,1000000000): return false
		if not event.get("date") is String or not p.valid_date(event.date): return false
		if not integer(event.get("installment"),0,int(event.amount)) or not integer(event.get("recovered"),0,int(event.amount)): return false
		if not event.get("settlement_id") is String or (not event.settlement_id.is_empty() and ids.get(event.settlement_id) != "settlements"): return false
	for group in value.families:
		if not group.get("name") is String or not group.get("active") is bool or not group.get("members") is Array: return false
		if group.active and group.members.size() < 2: return false
		var seen = {}
		for member in group.members:
			if ids.get(member) != "persons" or seen.has(member): return false
			seen[member] = true
			for who in value.persons:
				if who.id == member and who.family_id != group.id: return false
	for payment in value.settlements:
		if not payment.get("slips") is Array or not payment.get("cancelled") is bool or not integer(payment.get("cash"),0,9000000000000000): return false
		if not payment.get("paid_date") is String or not p.valid_date(payment.paid_date): return false
		if payment.has("before") and not validate(payment.before): return false
		var sum_cash = 0
		for slip in payment.slips:
			if not slip is Dictionary or ids.get(slip.get("person_id")) != "persons" or not slip.get("totals") is Dictionary: return false
			if not slip.get("attendance") is Array or not slip.get("ledger_ids") is Array or not slip.get("bm") is Dictionary: return false
			if not slip.get("name") is String or not slip.get("start") is String or not slip.get("end") is String or not p.valid_date(slip.start) or not p.valid_date(slip.end) or slip.start > slip.end: return false
			var total = slip.totals
			for field in ["earnings","jama","kharchi","recovery","net","cash","new_jama","shortfall"]:
				if not integer(total.get(field),-9000000000000000 if field == "net" else 0,9000000000000000): return false
			var expected = p.net(int(total.earnings),int(total.jama),int(total.kharchi),int(total.recovery),int(total.cash))
			if total.cash > maxi(0,int(total.net)): return false
			for field in expected:
				if int(total[field]) != expected[field]: return false
			sum_cash += int(total.cash)
		if sum_cash != int(payment.cash): return false
	return true

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value == int(value) and value >= low and value <= high

func backup() -> String:
	var payload = JSON.stringify(data)
	return JSON.stringify({"schema_version": 1, "created_at": Time.get_datetime_string_from_system(true), "sha256": payload.sha256_text(), "payload": payload})

func inspect_backup(text: String) -> Dictionary:
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return {"error": "Malformed backup JSON."}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {"error": "Invalid backup envelope."}
	if envelope.payload.sha256_text() != envelope.get("sha256"):
		return {"error": "Backup integrity check failed."}
	var candidate = JSON.parse_string(envelope.payload)
	if not validate(candidate):
		return {"error": "Invalid backup data."}
	return {"data": candidate, "people": candidate.persons.size(), "payments": candidate.settlements.size()}

func restore(text: String) -> bool:
	var checked = inspect_backup(text)
	if checked.has("error"):
		error = checked.error
		return false
	var previous = data.duplicate(true)
	var was_recovery = needs_recovery
	needs_recovery = false
	data = checked.data
	if not save():
		data = previous
		needs_recovery = was_recovery
		return false
	return true
