class_name PayrollService
extends RefCounted
const P = preload("res://scripts/domain/payroll.gd")
var repo
var error = ""
func _init(repository):
	repo = repository

func fail(message: String) -> bool:
	error = message
	return false

func audit(action: String, detail: Variant) -> void:
	repo.data.audit.append({"at": Time.get_datetime_string_from_system(true), "action": action, "detail": detail})

func person(name: String, start: String) -> bool:
	var clean = " ".join(name.replace("\t"," ").replace("\n"," ").split(" ", false)).strip_edges()
	if clean.is_empty() or not P.valid_date(start):
		return fail("Enter a name and valid payroll start date.")
	for row in repo.data.persons:
		if row.name.to_lower() == clean.to_lower():
			return fail("That name already exists. Add a distinguishing suffix.")
	repo.data.persons.append({"id": repo.id("P"), "name": clean, "active": true, "payroll_start_date": start, "paid_up_to": "", "family_id": ""})
	return true

func search(query: String) -> Array:
	var results = []
	for row in repo.data.persons:
		if query.is_empty() or query.to_lower() in row.name.to_lower() or query.to_lower() in row.id.to_lower() or (query.is_valid_int() and int(query) == int(row.id.split("-")[1])):
			results.append(row)
	return results

func mill(name: String) -> bool:
	if name.strip_edges().is_empty():
		return fail("A mill needs a name.")
	for row in repo.data.mills:
		if row.name.to_lower() == name.strip_edges().to_lower():
			return fail("Mill name already exists.")
	repo.data.mills.append({"id": repo.id("M"), "name": name.strip_edges(), "active": true})
	return true

func effective(collection: String, field: String, key: String, date: String, role: String = "") -> Dictionary:
	var chosen = {}
	for row in repo.data[collection]:
		if row[field] == key and row.effective_from <= date and (role.is_empty() or row.role == role):
			if chosen.is_empty() or chosen.effective_from <= row.effective_from:
				chosen = row
	return chosen

func rate(mill_id: String, role: String, amount: int, date: String, reason: String = "") -> bool:
	if repo.find("mills", mill_id).is_empty() or role not in ["F", "H"] or amount < 0 or amount > P.MAX_VALUE or not P.valid_date(date):
		return fail("Invalid mill, role, whole-rupee rate or effective date.")
	var old = effective("rates", "mill_id", mill_id, date, role)
	repo.data.rates.append({"id": repo.id("R"), "mill_id": mill_id, "role": role, "amount": amount, "effective_from": date, "old": old.get("amount", 0), "reason": reason, "at": Time.get_datetime_string_from_system(true)})
	return true

func salary(person_id: String, amount: int, date: String, reason: String = "") -> bool:
	if repo.find("persons", person_id).is_empty() or amount < 0 or amount > P.MAX_VALUE or not P.valid_date(date):
		return fail("Invalid salary or effective date. Zero disables BM eligibility.")
	var old = effective("salaries", "person_id", person_id, date)
	repo.data.salaries.append({"id": repo.id("S"), "person_id": person_id, "amount": amount, "effective_from": date, "old": old.get("amount", 0), "reason": reason, "at": Time.get_datetime_string_from_system(true)})
	return true

func attendance(person_id: String, mill_id: String, role: String, start: String, end: String, half_units: int, minutes: int, overlap_confirmed: bool = false) -> bool:
	var who = repo.find("persons", person_id)
	if who.is_empty() or not who.active or repo.find("mills", mill_id).is_empty() or not repo.find("mills", mill_id).active:
		return fail("Select an active person and mill.")
	if not P.valid_date(start) or not P.valid_date(end) or start > end or start < who.payroll_start_date or (not who.paid_up_to.is_empty() and start <= who.paid_up_to):
		return fail("Invalid range, before payroll start, or already paid period.")
	if role not in ["BM", "F", "H"] or half_units < 0 or half_units > P.MAX_VALUE or minutes < 0 or minutes > P.MAX_VALUE or minutes % 15 != 0 or (role == "BM" and minutes != 0):
		return fail("Use half attendances and quarter hours; BM has no extra hours.")
	for required_role in ["F","H"]:
		if effective("rates","mill_id",mill_id,start,required_role).is_empty(): return fail("Set both F and H mill rates before entering work.")
	var snapshot = 0
	if role == "BM":
		if effective("salaries", "person_id", person_id, start).get("amount", 0) <= 0:
			return fail("Enable a BM salary before adding BM attendance.")
	else:
		var setting = effective("rates", "mill_id", mill_id, start, role)
		if setting.is_empty():
			return fail("Set this mill's rate first.")
		snapshot = int(setting.amount)
		for row in repo.data.rates:
			if row.mill_id == mill_id and row.role == role and row.effective_from > start and row.effective_from <= end:
				return fail("Rate changes within this range. Split it at the change date.")
	for row in repo.data.attendance:
		if row.person_id == person_id and row.mill_id == mill_id and row.role == role:
			if row.start == start and row.end == end and int(row.half_units) == half_units and int(row.minutes) == minutes:
				return fail("Exact duplicate attendance.")
			if row.start <= end and row.end >= start and not overlap_confirmed:
				return fail("Overlapping attendance: review and explicitly confirm overlap.")
	repo.data.attendance.append({"id": repo.id("A"), "person_id": person_id, "mill_id": mill_id, "role": role, "start": start, "end": end, "half_units": half_units, "minutes": minutes, "rate": snapshot, "settlement_id": "", "created_at": Time.get_datetime_string_from_system(true)})
	return true

func split(entry_id: String, through: String, first_half: int, first_minutes: int) -> bool:
	var row = repo.find("attendance", entry_id)
	if row.is_empty() or not row.settlement_id.is_empty() or not P.valid_date(through) or through < row.start or through >= row.end or first_half < 0 or first_half > row.half_units or first_minutes < 0 or first_minutes > row.minutes or first_minutes % 15 != 0:
		return fail("Invalid split. Only unpaid rows may be split; totals must be conserved.")
	var split_adjustment = int(row.get("split_adjustment",0))
	var first_adjustment = 0
	if row.role != "BM":
		var old_pay = P.worker(int(row.rate),int(row.half_units),int(row.minutes))
		var first_pay = P.worker(int(row.rate),first_half,first_minutes)
		var second_pay = P.worker(int(row.rate),int(row.half_units)-first_half,int(row.minutes)-first_minutes)
		split_adjustment += int(old_pay.total) - int(first_pay.total) - int(second_pay.total)
		if int(second_pay.total) + split_adjustment < 0:
			first_adjustment = split_adjustment
			split_adjustment = 0
	var second = row.duplicate(true)
	second.id = repo.id("A")
	second.split_adjustment = split_adjustment
	second.split_source = row.get("split_source",row.id)
	second.start = P.date_from_day(P.day(through) + 1)
	second.half_units = int(row.half_units) - first_half
	second.minutes = int(row.minutes) - first_minutes
	audit("split", row.duplicate(true))
	row.split_adjustment = first_adjustment
	row.split_source = second.split_source
	row.end = through
	row.half_units = first_half
	row.minutes = first_minutes
	repo.data.attendance.append(second)
	return true

func reprice_preview(mill_id: String, role: String, date: String, amount: int) -> Dictionary:
	var rows = []
	var old_total = 0
	var new_total = 0
	for row in repo.data.attendance:
		if row.mill_id == mill_id and row.role == role and row.settlement_id.is_empty() and row.end >= date:
			if row.start < date:
				return {"error": "Split crossing row " + row.id + " first."}
			rows.append(row.id)
			old_total += P.worker(int(row.rate), int(row.half_units), int(row.minutes)).total + int(row.get("split_adjustment",0))
			new_total += P.worker(amount, int(row.half_units), int(row.minutes)).total + int(row.get("split_adjustment",0))
	return {"rows": rows, "old": old_total, "new": new_total, "amount": amount}

func reprice(preview: Dictionary, reason: String) -> bool:
	if preview.has("error") or reason.strip_edges().is_empty():
		return fail("Review repricing and provide an edit reason.")
	for key in preview.rows:
		var row = repo.find("attendance", key)
		if row.is_empty() or not row.settlement_id.is_empty():
			return fail("Preview is stale. Preview again.")
	for key in preview.rows:
		var row = repo.find("attendance", key)
		audit("rate correction", {"entry": key, "old": row.rate, "new": preview.amount, "reason": reason})
		row.rate = preview.amount
	return true

func ledger(person_id: String, kind: String, amount: int, date: String, installment: int = 0) -> bool:
	if repo.find("persons", person_id).is_empty() or kind not in ["jama", "kharchi", "advance"] or amount <= 0 or amount > P.MAX_VALUE or installment < 0 or installment > amount or not P.valid_date(date):
		return fail("Invalid money entry.")
	repo.data.ledger.append({"id": repo.id("L"), "person_id": person_id, "kind": kind, "amount": amount, "date": date, "installment": installment, "recovered": 0, "settlement_id": ""})
	return true

func bulk_kharchi(people: Array, start: String, end: String, daily: int) -> bool:
	if not P.valid_date(start) or not P.valid_date(end) or start > end or P.day(end) - P.day(start) > 366 or daily <= 0:
		return fail("Choose a valid range up to one year and daily amount.")
	for key in people:
		if repo.find("persons", key).is_empty():
			return fail("Unknown person.")
	for key in people:
		for d in range(P.day(start), P.day(end) + 1):
			ledger(key, "kharchi", daily, P.date_from_day(d))
	return true

func preview(person_id: String, end: String, recovery: int = -1, cash: int = -1, family_context: bool = false) -> Dictionary:
	var who = repo.find("persons", person_id)
	if who.is_empty() or not P.valid_date(end):
		return {"error": "Select a person and valid up-to date."}
	if not who.family_id.is_empty() and not family_context:
		return {"error": "Pay this person's family together: " + who.family_id}
	var start: String = who.payroll_start_date if who.paid_up_to.is_empty() else P.date_from_day(P.day(who.paid_up_to) + 1)
	if end < start:
		return {"error": "Already paid through this date, or before payroll start."}
	var rows = []
	var earnings = 0
	var bm_half = 0
	for row in repo.data.attendance:
		if row.person_id != person_id or not row.settlement_id.is_empty() or row.start > end:
			continue
		if row.end > end:
			return {"error": "Manually split attendance " + row.id + " at " + end + " before payment."}
		if row.role == "BM":
			bm_half += int(row.half_units)
		else:
			earnings += P.worker(int(row.rate), int(row.half_units), int(row.minutes)).total + int(row.get("split_adjustment",0))
		var snapshot = row.duplicate(true)
		snapshot.mill_name = repo.find("mills",row.mill_id).get("name",row.mill_id)
		rows.append(snapshot)
	var bm = {}
	var chosen = effective("salaries", "person_id", person_id, end)
	if chosen.get("amount", 0) > 0:
		var bm_start = start
		var first_salary = end
		for setting in repo.data.salaries:
			if setting.person_id == person_id and setting.amount > 0 and setting.effective_from < first_salary:
				first_salary = setting.effective_from
		if first_salary > bm_start:
			bm_start = first_salary
		bm = P.master(int(chosen.amount), bm_start, end, bm_half)
		earnings += bm.total
	var jama = 0
	var kharchi = 0
	var outstanding = 0
	var preferred = 0
	var events = []
	for event in repo.data.ledger:
		if event.person_id != person_id or event.date > end:
			continue
		if event.kind == "advance":
			var remaining = int(event.amount) - int(event.recovered)
			outstanding += remaining
			preferred += mini(int(event.installment), remaining)
		elif event.settlement_id.is_empty():
			if event.kind == "jama":
				jama += int(event.amount)
			else:
				kharchi += int(event.amount)
			events.append(event.id)
	if recovery < 0:
		recovery = mini(preferred, outstanding)
	if recovery < 0 or recovery > outstanding:
		return {"error": "Recovery exceeds outstanding advance."}
	var totals = P.net(earnings, jama, kharchi, recovery, cash)
	if totals.cash > maxi(0, totals.net):
		return {"error": "Cash exceeds net payable. Use a separate advance entry."}
	return {"person_id": person_id, "name": who.name, "start": start, "end": end, "payroll_start_date": who.payroll_start_date, "attendance": rows, "ledger_ids": events, "bm": bm, "totals": totals, "outstanding": outstanding, "remaining_advance": outstanding - recovery + totals.shortfall}

func record(person_id: String, end: String, paid_date: String, recovery: int = -1, cash: int = -1, confirm_negative: bool = false) -> bool:
	var slip = preview(person_id, end, recovery, cash)
	if slip.has("error"):
		return fail(slip.error)
	return record_slips([slip], "", paid_date, confirm_negative)

func record_slips(slips: Array, family_id: String, paid_date: String, confirm_negative: bool) -> bool:
	if not P.valid_date(paid_date) or slips.is_empty():
		return fail("Invalid actual cash payment date or empty payment.")
	var seen = {}
	for slip in slips:
		if seen.has(slip.person_id): return fail("Duplicate member allocation.")
		seen[slip.person_id] = true
		var fresh = preview(slip.person_id,slip.end,int(slip.totals.recovery),int(slip.totals.cash),not family_id.is_empty())
		if fresh.has("error") or JSON.stringify(fresh) != JSON.stringify(slip):
			return fail("Stale payment preview. Preview again.")
	if not family_id.is_empty():
		var group = repo.find("families",family_id)
		if group.is_empty() or not group.active or group.members.size() != slips.size(): return fail("Family membership changed.")
		for member in group.members:
			if not seen.has(member): return fail("All family members must be included.")
		var family_net = 0
		var family_cash = 0
		for slip in slips:
			family_net += int(slip.totals.net)
			family_cash += int(slip.totals.cash)
		if family_cash > maxi(0,family_net): return fail("Combined cash exceeds the family's net payable.")
	for slip in slips:
		if slip.totals.shortfall > 0 and not confirm_negative:
			return fail("Confirm negative net: shortfall becomes a carry-forward advance.")
	var before = repo.data.duplicate(true)
	for previous in before.settlements:
		previous.erase("before")
	var payment_id = repo.id("PAY")
	var cash_total = 0
	for slip in slips:
		cash_total += int(slip.totals.cash)
		for row in slip.attendance:
			repo.find("attendance", row.id).settlement_id = payment_id
		for key in slip.ledger_ids:
			repo.find("ledger", key).settlement_id = payment_id
		var recovery = int(slip.totals.recovery)
		for event in repo.data.ledger:
			if event.person_id == slip.person_id and event.kind == "advance" and event.date <= slip.end:
				var part = mini(recovery, int(event.amount) - int(event.recovered))
				event.recovered = int(event.recovered) + part
				recovery -= part
		if slip.totals.new_jama > 0:
			ledger(slip.person_id, "jama", slip.totals.new_jama, slip.end)
		if slip.totals.shortfall > 0:
			ledger(slip.person_id, "advance", slip.totals.shortfall, slip.end)
		repo.find("persons", slip.person_id).paid_up_to = slip.end
	repo.data.settlements.append({"id": payment_id, "family_id": family_id, "family_name": repo.find("families", family_id).get("name", ""), "paid_date": paid_date, "slips": slips.duplicate(true), "cash": cash_total, "cancelled": false, "before": before})
	audit("payment", payment_id)
	if not repo.save():
		repo.data = before
		return fail(repo.error)
	return true

func cancel_latest(payment_id: String, confirmed: bool) -> bool:
	if not confirmed or repo.data.settlements.is_empty():
		return fail("Confirm cancellation of the latest payment.")
	var payment = repo.data.settlements.back()
	if payment.id != payment_id or payment.cancelled:
		return fail("Only the latest active payment can be cancelled.")
	# Conservative reversal: refuse all subsequent account edits, not only known dependencies.
	if repo.data.audit.is_empty() or repo.data.audit.back().get("detail") != payment_id:
		return fail("Later changes make reversal unsafe.")
	var before = payment.before.duplicate(true)
	var expected = repo.data.duplicate(true)
	# No new IDs may have been issued since settlement completion.
	var maximum = int(payment.id.split("-")[1])
	for event in repo.data.ledger:
		maximum = maxi(maximum, int(event.id.split("-")[1]))
	if int(repo.data.next_id) != maximum + 1:
		return fail("Later account actions prevent cancellation.")
	repo.data = before
	repo.data.next_id = expected.next_id
	var receipt = payment.duplicate(true)
	receipt.erase("before")
	receipt.cancelled = true
	repo.data.settlements.append(receipt)
	audit("cancel payment", payment_id)
	if not repo.save():
		repo.data = expected
		return false
	return true

func family(name: String, member_ids: Array) -> bool:
	if name.strip_edges().is_empty() or member_ids.size() < 2:
		return fail("A family needs a name and at least two members.")
	var aligned = "?"
	var seen = {}
	for key in member_ids:
		var who = repo.find("persons", key)
		if seen.has(key) or who.is_empty() or not who.family_id.is_empty():
			return fail("Each member must be distinct and outside other families.")
		seen[key] = true
		var boundary = who.paid_up_to if not who.paid_up_to.is_empty() else P.date_from_day(P.day(who.payroll_start_date) - 1)
		if aligned != "?" and aligned != boundary:
			return fail("Member paid-up-to dates must align.")
		aligned = boundary
		var current_date = Time.get_date_string_from_system()
		if boundary < current_date and effective("salaries","person_id",key,current_date).get("amount",0) > 0:
			return fail("Settle accrued BM fixed salary before family changes.")
		for row in repo.data.attendance:
			if row.person_id == key and row.settlement_id.is_empty():
				return fail("Settle pending attendance before family changes.")
		for event in repo.data.ledger:
			if event.person_id == key and ((event.kind == "advance" and event.amount > event.recovered) or (event.kind != "advance" and event.settlement_id.is_empty())):
				return fail("Resolve jama, kharchi and advance before family changes.")
	var key = repo.id("FAM")
	repo.data.families.append({"id": key, "name": name.strip_edges(), "members": member_ids.duplicate(), "active": true})
	for member in member_ids:
		repo.find("persons", member).family_id = key
	audit("family created", key)
	return true

func family_preview(key: String, end: String, overrides: Dictionary = {}) -> Dictionary:
	var group = repo.find("families", key)
	if group.is_empty() or not group.active:
		return {"error": "Select an active family."}
	var slips = []
	var net_total = 0
	for member in group.members:
		var allocation: Dictionary = overrides.get(member,{})
		var slip = preview(member,end,int(allocation.get("recovery",-1)),-1,true)
		if slip.has("error"): return slip
		slips.append(slip)
		net_total += int(slip.totals.net)
	var available_cash = maxi(0,net_total)
	var cash_total = 0
	# Explicit overrides reserve cash first; defaults allocate the remaining group net.
	for slip in slips:
		var allocation: Dictionary = overrides.get(slip.person_id,{})
		var explicit_cash = int(allocation.get("cash",-1))
		if explicit_cash >= 0:
			if explicit_cash > maxi(0,int(slip.totals.net)): return {"error":"Member cash exceeds individual net."}
			available_cash -= explicit_cash
	if available_cash < 0: return {"error":"Family cash exceeds combined net payable."}
	for index in slips.size():
		var slip = slips[index]
		var allocation: Dictionary = overrides.get(slip.person_id,{})
		var paid = int(allocation.get("cash",-1))
		if paid < 0:
			paid = mini(available_cash,maxi(0,int(slip.totals.net)))
			available_cash -= paid
		slips[index] = preview(slip.person_id,end,int(slip.totals.recovery),paid,true)
		cash_total += paid
	return {"slips":slips,"cash":cash_total,"net":net_total,"family_id":key}

func family_change(key: String, name: String, members: Array) -> bool:
	var group = repo.find("families",key)
	if group.is_empty() or not group.active or name.strip_edges().is_empty() or (members.size() == 1):
		return fail("Select an active family; keep at least two members, or dissolve with none.")
	var affected = group.members.duplicate()
	for member in members:
		if member not in affected: affected.append(member)
	var boundary = "?"
	var seen = {}
	for member in members:
		if seen.has(member): return fail("Duplicate family member.")
		seen[member] = true
	for member in affected:
		var who = repo.find("persons",member)
		if who.is_empty() or (not who.family_id.is_empty() and who.family_id != key):
			return fail("Member belongs to another family or does not exist.")
		var end = who.paid_up_to if not who.paid_up_to.is_empty() else P.date_from_day(P.day(who.payroll_start_date)-1)
		if boundary != "?" and boundary != end: return fail("All affected paid-up-to dates must align.")
		boundary = end
		var current_date = Time.get_date_string_from_system()
		if end < current_date and effective("salaries","person_id",member,current_date).get("amount",0) > 0:
			return fail("Settle accrued BM fixed salary for " + who.name)
		for row in repo.data.attendance:
			if row.person_id == member and row.settlement_id.is_empty(): return fail("Settle pending attendance for " + who.name)
		for event in repo.data.ledger:
			if event.person_id == member and ((event.kind == "advance" and event.amount > event.recovered) or (event.kind != "advance" and event.settlement_id.is_empty())):
				return fail("Resolve balances for " + who.name)
	audit("family changed",group.duplicate(true))
	for member in affected:
		repo.find("persons",member).family_id = key if member in members else ""
	group.name = name.strip_edges()
	group.members = members.duplicate()
	group.active = not members.is_empty()
	return true

func correct_rate(entry_id: String, amount: int, reason: String) -> bool:
	var row = repo.find("attendance",entry_id)
	if row.is_empty() or row.role == "BM" or not row.settlement_id.is_empty() or amount < 0 or amount > P.MAX_VALUE or reason.strip_edges().is_empty():
		return fail("Choose an unpaid F/H row, valid rate and edit reason.")
	audit("manual rate",{"id":entry_id,"old":row.rate,"new":amount,"reason":reason})
	row.rate = amount
	return true

func edit_attendance(entry_id: String, start: String, end: String, halves: int, minutes: int, reason: String, overlap_confirmed: bool = false) -> bool:
	var row = repo.find("attendance",entry_id)
	if row.is_empty() or not row.settlement_id.is_empty() or reason.strip_edges().is_empty():
		return fail("Only unpaid attendance can be edited; a reason is required.")
	var before = repo.data.duplicate(true)
	var old = row.duplicate(true)
	repo.data.attendance.erase(row)
	if not attendance(old.person_id,old.mill_id,old.role,start,end,halves,minutes,overlap_confirmed):
		repo.data = before
		return false
	var replacement = repo.data.attendance.back()
	replacement.id = old.id
	replacement.created_at = old.created_at
	replacement.rate = old.rate
	audit("attendance edited",{"old":old,"new":replacement.duplicate(true),"reason":reason})
	return true

func edit_ledger(entry_id: String, amount: int, date: String, installment: int, reason: String) -> bool:
	var row = repo.find("ledger",entry_id)
	if row.is_empty() or not row.settlement_id.is_empty() or row.recovered > 0 or reason.strip_edges().is_empty() or amount <= 0 or amount > P.MAX_VALUE or not P.valid_date(date) or installment < 0 or installment > amount:
		return fail("Only unallocated money can be corrected; enter a reason and valid amount/date.")
	audit("money corrected",{"old":row.duplicate(true),"reason":reason})
	row.amount = amount
	row.date = date
	row.installment = installment
	return true

func salary_comparison(person_id: String, amount: int, date: String, end: String) -> Dictionary:
	var before = repo.data.duplicate(true)
	var old = preview(person_id,end,-1,-1,true)
	if not salary(person_id,amount,date,"comparison only"):
		return {"error":error}
	var updated = preview(person_id,end,-1,-1,true)
	repo.data.salaries.pop_back()
	repo.data.next_id = before.next_id
	if old.has("error") or updated.has("error"):
		return {"old":0,"new":0,"note":"No payable period through " + end + "; history entry only."}
	return {"old":old.totals.earnings,"new":updated.totals.earnings,"note":"Unpaid period " + updated.start + " → " + end}
