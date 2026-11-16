extends SceneTree
## Core payroll tests. Run:  godot --headless --path . --script tests/test_core.gd
## Uses only made-up names.

var passed := 0
var failed := 0
var db: Node


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", label)


func eq(a, b, label: String) -> void:
	check(a == b, "%s  (got %s, expected %s)" % [label, str(a), str(b)])


func _initialize() -> void:
	db = root.get_node("DB")
	db.reset_for_tests()
	test_dates()
	test_money()
	test_translit()
	test_sheet_rows()
	test_master_pay()
	test_cases()
	test_period_chain()
	test_family()
	test_rates_effective()
	test_undo_and_edit_rules()
	test_export_import()
	print("\nCore tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_translit() -> void:
	eq(Translit.to_hi("Kishan"), "किशन", "Kishan")
	eq(Translit.to_hi("Ganga Mill"), "गंगा मिल", "mill name")
	eq(Translit.to_hi("Raamu"), "रामू", "long vowels")
	eq(Translit.to_hi("Suneel"), "सुनील", "ee")
	eq(Translit.to_hi("Shyam"), "श्याम", "common name")
	eq(Translit.to_hi("PinTu"), "पिंटू", "capital T gives ट")
	eq(Translit.to_hi("Mill 2"), "मिल 2", "numbers stay English")


func test_dates() -> void:
	eq(Dates.days_in_month(2026, 2), 28, "Feb 2026")
	eq(Dates.days_in_month(2028, 2), 29, "Feb 2028 leap")
	eq(Dates.add_days("2026-10-31", 1), "2026-11-01", "add day over month")
	eq(Dates.add_days("2026-12-31", 1), "2027-01-01", "add day over year")
	eq(Dates.last_of_previous_month("2026-08-20"), "2026-07-31", "prev month end")
	eq(Dates.last_of_previous_month("2026-03-20"), "2026-02-28", "prev month end Feb")
	eq(Dates.add_months("2026-01-31", 1), "2026-02-28", "add month clamps")
	var ms := Dates.months_between("2026-11-08", "2026-12-31")
	eq(ms.size(), 2, "two months")
	eq(ms[0].days, 30, "Nov days")
	eq(ms[0].from, "2026-11-08", "Nov from")
	eq(ms[1].days, 31, "Dec days")
	check(Dates.valid("2026-02-28") and not Dates.valid("2026-02-30"), "valid dates")


func test_money() -> void:
	eq(Money.round_half_up(253.3333), 253, "253.33 down")
	eq(Money.round_half_up(266.6667), 267, "266.67 up")
	eq(Money.round_half_up(10.5), 11, ".5 up")
	eq(Money.round_half_up(10.49), 10, ".49 down")
	eq(Money.round_half_up(-10.5), -11, "negative mirrors")
	eq(Money.group(184300), "1,84,300", "indian grouping")
	eq(Money.group(12345678), "1,23,45,678", "crore grouping")
	eq(Money.group(950), "950", "small")
	eq(Money.rs(-2500), "−₹2,500", "negative rupees")
	eq(Money.num(31.5), "31.5", "half att")
	eq(Money.num(31.0), "31", "whole att")


func test_sheet_rows() -> void:
	# [rate, attendance, hours, sheet's raw "Total Rupee"] – every F/H row of the
	# owner's workbook (names removed). Each row must equal the sheet, rounded half up.
	var rows := [
		[285, 68, 8, 19570], [420, 29, 0, 12180], [420, 31, 0, 13020], [420, 31, 6, 13230],
		[285, 70, 4, 20045], [420, 29, 0, 12180], [420, 22, 0, 9240], [420, 34, 0, 14280],
		[420, 27, 0, 11340], [420, 26, 0, 10920], [420, 29, 0, 12180], [420, 26, 0, 10920],
		[285, 50, 8, 14440], [420, 21, 0, 8820], [420, 21, 0, 8820], [285, 29, 0, 8265],
		[420, 1, 0, 420],
		[300, 50, 6, 15150], [380, 39, 8, 15073.33333], [300, 48, 0, 14400], [380, 39, 8, 15073.33333],
		[300, 41, 6, 12450], [380, 36, 0, 13680], [300, 37, 0, 11100], [380, 35, 0, 13300],
		[380, 43, 0, 16340], [380, 30, 0, 11400], [380, 10, 8, 4053.333333],
		[300, 35, 0, 10500], [400, 8, 0, 3200], [400, 31, 8, 12666.66667], [300, 49, 0, 14700],
		[400, 36, 8, 14666.66667], [300, 31, 4, 9400], [400, 30, 8, 12266.66667], [400, 31, 0, 12400],
		[400, 30, 0, 12000], [300, 35, 6, 10650], [400, 33, 0, 13200],
		[270, 45, 4, 12240], [380, 49, 0, 18620], [270, 35, 2, 9495], [380, 28, 0, 10640],
		[270, 43, 2, 11655], [380, 48, 0, 18240], [380, 31, 0, 11780], [380, 30, 0, 11400],
		[270, 40, 0, 10800], [380, 28, 0, 10640], [270, 44, 4, 11970], [380, 33, 0, 12540],
		[380, 32, 0, 12160], [380, 31, 0, 11780], [380, 30, 0, 11400], [270, 26, 4, 7110],
		[270, 11, 2, 3015], [380, 21, 0, 7980], [380, 8, 0, 3040],
	]
	var ok := 0
	for r in rows:
		var got := Calc.fh_amount(r[0], r[1], r[2])
		if got == Money.round_half_up(float(r[3])):
			ok += 1
		else:
			check(false, "sheet row %s → %d" % [str(r), got])
	eq(ok, rows.size(), "all %d sheet rows match" % rows.size())
	# The examples from the discussion.
	eq(Calc.fh_amount(285, 68, 8) + Calc.fh_amount(420, 29, 0), 31750, "F+H example total 31,750")
	eq(Calc.fh_amount(285, 50, 8) + Calc.fh_amount(420, 21, 0), 23260, "F+H example total 23,260")


func test_master_pay() -> void:
	eq(Calc.bm_amount(32000, 32, 31), 33032, "32,000 × 32 ÷ 31")
	eq(Calc.bm_amount(33000, 31, 31), 33000, "full month = salary")
	eq(Calc.bm_amount(33000, 35, 31), 37258, "extra attendance paid extra")
	eq(Calc.bm_amount(22000, 28, 28), 22000, "Feb full")
	eq(Calc.default_bm_days("2026-10-01", "2026-11-07"), 31, "normal uses first month")
	var normal := {"post": "BM", "mode": "normal", "rate": 22000, "att": 38.0, "days": 31}
	eq(Calc.row_amount(normal), 26968, "normal 22,000 × 38 ÷ 31")
	var split := {"post": "BM", "mode": "split", "months": [
		{"salary": 22000, "att": 31.0, "days": 31}, {"salary": 22000, "att": 7.0, "days": 30}]}
	eq(Calc.row_amount(split), 27133, "split 22,000 + 5,133")
	# Through the store: draft for a master over Oct 1 – Nov 7.
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var p: Dictionary = db.add_person("Master One", [{"mill_id": m.id, "post": "BM"}], 22000, "2026-01-01")
	db.set_khata_start(p.khata_id, "2026-10-01")
	var d: Dictionary = db.make_draft(p.khata_id, "2026-11-07", "2026-11-07")
	eq(d.from, "2026-10-01", "draft from")
	eq(d.rows.size(), 1, "one BM row")
	eq(d.rows[0].days, 31, "draft days = Oct")
	eq(d.rows[0].months.size(), 2, "two months available for split")
	d.rows[0].att = 38.0
	eq(db.draft_hisab(d).earnings, 26968, "draft normal")
	d.rows[0].mode = "split"
	d.rows[0].months[0].att = 31.0
	d.rows[0].months[1].att = 7.0
	eq(db.draft_hisab(d).earnings, 27133, "draft split")
	# Salary raised from November: split uses each month's own salary.
	db.add_salary(p.id, "2026-11-01", 30000)
	db.rebuild_rows(d)
	eq(d.rows[0].months[1].salary, 30000, "Nov salary after raise")
	eq(d.rows[0].months[0].salary, 22000, "Oct salary before raise")
	eq(db.draft_hisab(d).earnings, 22000 + 7000, "split with raise")


func _pay(kid: String, date: String, upto: String, att_by_post: Dictionary, choice := "full", custom := 0) -> Dictionary:
	var d: Dictionary = db.make_draft(kid, date, upto)
	for r in d.rows:
		var key: String = r.post
		if att_by_post.has(key):
			r.att = float(att_by_post[key][0])
			r.hr = float(att_by_post[key][1])
	d.choice = choice
	d.custom = custom
	return db.commit_payment(d)


func test_cases() -> void:
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var fh := [{"mill_id": m.id, "post": "F"}, {"mill_id": m.id, "post": "H"}]
	# Normal: earnings − kharchi, pay full.
	var a: Dictionary = db.add_person("Worker A", fh)
	db.set_khata_start(a.khata_id, "2026-07-01")
	db.add_entry(a.id, "kharchi", 500, "2026-07-25")
	db.add_entry(a.id, "kharchi", 1000, "2026-08-10")  # in the hold days – still deducted
	var pay := _pay(a.khata_id, "2026-08-20", "", {"F": [68, 8], "H": [29, 0]})
	eq(pay.upto, "2026-07-31", "default upto = end of previous month")
	eq(pay.earnings, 31750, "normal earnings")
	eq(pay.kharchi, 1500, "kharchi incl. hold days")
	eq(pay.due, 30250, "due")
	eq(pay.paid, 30250, "pay full")
	eq(db.live_balance(a.khata_id), 0, "balance 0")
	eq(db.open_entries(a.khata_id).size(), 0, "kharchi settled")
	# Kharchi after the payment date stays open for next time.
	db.add_entry(a.id, "kharchi", 200, "2026-08-21")
	eq(db.live_balance(a.khata_id), -200, "new kharchi open")

	# Advance not covered → carried forward, cut next time.
	var g: Dictionary = db.add_person("Worker G", fh)
	db.set_khata_start(g.khata_id, "2026-07-01")
	db.add_entry(g.id, "advance", 50000, "2026-08-01")
	db.add_entry(g.id, "kharchi", 2000, "2026-08-05")
	pay = _pay(g.khata_id, "2026-08-20", "", {"F": [70, 4], "H": [29, 0]})
	eq(pay.earnings, 32225, "G earnings")
	eq(pay.due, 32225 - 52000, "G due negative")
	eq(pay.paid, 0, "nothing paid when negative")
	eq(pay.new_balance, -19775, "advance left")
	pay = _pay(g.khata_id, "2026-09-20", "", {"F": [70, 4], "H": [29, 0]})
	eq(pay.from, "2026-08-01", "next period starts after last")
	eq(pay.prev_balance, -19775, "previous advance carried")
	eq(pay.due, 32225 - 19775, "advance recovered, extra positive")
	eq(pay.paid, 12450, "extra paid")
	eq(db.live_balance(g.khata_id), 0, "G clear")

	# Jama: keep with me, grows, then partial payout.
	var n: Dictionary = db.add_person("Worker N", fh)
	db.set_khata_start(n.khata_id, "2026-07-01")
	db.add_entry(n.id, "kharchi", 3260, "2026-08-02")
	pay = _pay(n.khata_id, "2026-08-20", "", {"F": [50, 8], "H": [21, 0]}, "keep")
	eq(pay.paid, 0, "keep jama pays 0")
	eq(pay.new_balance, 20000, "jama 20,000")
	pay = _pay(n.khata_id, "2026-09-20", "", {"F": [50, 8], "H": [21, 0]}, "keep")
	eq(pay.new_balance, 43260, "jama grows")
	pay = _pay(n.khata_id, "2026-10-20", "", {}, "custom", 40000)
	eq(pay.earnings, 0, "no work rows")
	eq(pay.paid, 40000, "custom payout")
	eq(pay.new_balance, 3260, "jama left")
	# Jama paid out on a normal day (not a payment).
	db.add_entry(n.id, "payout", 1000, "2026-10-25")
	eq(db.live_balance(n.khata_id), 2260, "mid-month jama payout")
	# Money received back.
	db.add_entry(g.id, "received", 500, "2026-10-01")
	eq(db.live_balance(g.khata_id), 500, "received adds")
	var t: Dictionary = db.totals()
	check(t.jama >= 2260, "totals jama")
	# Entries dated after the payment date are not included.
	db.add_entry(a.id, "kharchi", 999, "2026-12-01")
	var d: Dictionary = db.make_draft(a.khata_id, "2026-09-20")
	eq(db.draft_hisab(d).kharchi, 200, "future-dated kharchi excluded")


func test_period_chain() -> void:
	# The owner's own example of payment dates and work periods.
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var fh := [{"mill_id": m.id, "post": "H"}]
	var a: Dictionary = db.add_person("Group A one", fh)   # paid 7 Nov, then 17 Nov
	var a2: Dictionary = db.add_person("Group A two", fh)  # paid 7 Nov, not on 17 Nov
	var b: Dictionary = db.add_person("Group B", fh)       # paid 17 Nov
	for p in [a, a2, b]:
		db.set_khata_start(p.khata_id, "2026-07-01")
		eq(_pay(p.khata_id, "2026-08-20", "", {"H": [31, 0]}).upto, "2026-07-31", "Aug 20 pays July")
		eq(_pay(p.khata_id, "2026-09-20", "", {"H": [31, 0]}).from, "2026-08-01", "Sep 20 from Aug 1")
		eq(_pay(p.khata_id, "2026-10-20", "", {"H": [30, 0]}).upto, "2026-09-30", "Oct 20 pays Sep")
	var p1 := _pay(a.khata_id, "2026-11-07", "2026-11-07", {"H": [38, 0]})
	eq([p1.from, p1.upto], ["2026-10-01", "2026-11-07"], "Diwali 7 Nov: 1 Oct – 7 Nov")
	_pay(a2.khata_id, "2026-11-07", "2026-11-07", {"H": [38, 0]})
	var p2 := _pay(b.khata_id, "2026-11-17", "2026-11-17", {"H": [48, 0]})
	eq([p2.from, p2.upto], ["2026-10-01", "2026-11-17"], "17 Nov group B: 1 Oct – 17 Nov")
	var p3 := _pay(a.khata_id, "2026-11-17", "2026-11-17", {"H": [10, 0]})
	eq([p3.from, p3.upto], ["2026-11-08", "2026-11-17"], "17 Nov again: 8 – 17 Nov")
	var d: Dictionary = db.make_draft(a2.khata_id, "2027-01-20")
	eq([d.from, d.upto], ["2026-11-08", "2026-12-31"], "20 Jan for 7-Nov people: 8 Nov – 31 Dec")
	d = db.make_draft(b.khata_id, "2027-01-20")
	eq([d.from, d.upto], ["2026-11-18", "2026-12-31"], "20 Jan for 17-Nov people: 18 Nov – 31 Dec")
	_pay(b.khata_id, "2027-01-20", "", {"H": [40, 0]})
	d = db.make_draft(b.khata_id, "2027-02-20")
	eq([d.from, d.upto], ["2027-01-01", "2027-01-31"], "20 Feb pays January")
	# Default upto never falls before from.
	d = db.make_draft(a.khata_id, "2026-11-25")
	eq([d.from, d.upto], ["2026-11-18", "2026-11-25"], "upto falls back to pay date")
	# Validation.
	d = db.make_draft(a.khata_id, "2026-11-25", "2026-11-30")
	eq(db.validate_draft(d), "err_upto_after_pay", "upto after pay date rejected")


func test_family() -> void:
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var m2: Dictionary = db.add_mill("Mill B", 300, 400)
	var dad: Dictionary = db.add_person("Dad", [{"mill_id": m.id, "post": "H"}])
	var mom: Dictionary = db.add_person("Mom", [{"mill_id": m.id, "post": "H"}])
	var kid: Dictionary = db.add_person("Daughter", [{"mill_id": m2.id, "post": "H"}])
	db.set_opening_balance(mom.khata_id, 5000)
	db.add_entry(mom.id, "kharchi", 300, "2026-08-02")
	eq(db.join_family(dad.id, mom.id), "", "join mom")
	eq(db.join_family(dad.id, kid.id), "", "join daughter")
	eq(db.join_family(dad.id, dad.id), "err_same_person", "cannot join self")
	var k: Dictionary = db.khata_of(dad.id)
	eq(db.khata_of(mom.id).id, k.id, "same khata")
	eq(db.khata_members(k.id).size(), 3, "three members")
	eq(db.khata_members(k.id)[0].id, dad.id, "payee first")
	eq(db.live_balance(k.id), 5000 - 300, "mom's jama and kharchi carried")
	db.set_khata_start(k.id, "2026-07-01")
	db.add_entry(dad.id, "kharchi", 2000, "2026-08-05")
	db.add_entry(dad.id, "advance", 60000, "2026-08-06")
	var d: Dictionary = db.make_draft(k.id, "2026-08-20")
	eq(d.rows.size(), 3, "a row per member")
	var att := {dad.id: 27, mom.id: 31, kid.id: 31}
	for r in d.rows:
		r.att = float(att[r.person_id])
	var h: Dictionary = db.draft_hisab(d)
	eq(h.earnings, 11340 + 13020 + 12400, "family earnings (two mills)")
	eq(h.due, 5000 + 36760 - 300 - 2000 - 60000, "family due")
	var pay: Dictionary = db.commit_payment(d)
	eq(pay.new_balance, -20540, "family advance left")
	eq(db.leave_family(dad.id), "err_payee_cannot_leave", "payee cannot leave")
	eq(db.leave_family(kid.id), "", "daughter leaves")
	eq(db.khata_members(k.id).size(), 2, "two left")
	eq(db.next_work_from(db.khata_of(kid.id).id), "2026-08-01", "leaver keeps pay period")


func test_rates_effective() -> void:
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	db.add_mill_rate(m.id, "2026-11-01", 300, 450)
	eq(db.mill_rate(m.id, "F", "2026-10-20"), 285, "old F rate before change")
	eq(db.mill_rate(m.id, "H", "2026-11-20"), 450, "new H rate after change")
	var p: Dictionary = db.add_person("Rate Test", [{"mill_id": m.id, "post": "H"}])
	db.set_khata_start(p.khata_id, "2026-09-01")
	var pay := _pay(p.khata_id, "2026-10-20", "", {"H": [10, 0]})
	eq(pay.rows[0].rate, 420, "payment keeps its own rate")
	db.add_mill_rate(m.id, "2026-10-01", 1, 1)
	eq(int(db.payment(pay.id).rows[0].rate), 420, "saved payment not changed by later edits")
	# Custom rate on one row.
	var d: Dictionary = db.make_draft(p.khata_id, "2026-11-20")
	d.rows[0].rate = 500
	d.rows[0].rate_custom = true
	d.rows[0].att = 2.0
	db.rebuild_rows(d)
	eq(db.draft_hisab(d).earnings, 1000, "custom row rate kept")


func test_undo_and_edit_rules() -> void:
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var p: Dictionary = db.add_person("Undo Test", [{"mill_id": m.id, "post": "H"}])
	db.set_khata_start(p.khata_id, "2026-07-01")
	var e: Dictionary = db.add_entry(p.id, "kharchi", 700, "2026-08-01")
	var p1 := _pay(p.khata_id, "2026-08-20", "", {"H": [10, 0]})
	check(not db.delete_entry(e.id), "settled kharchi cannot be deleted")
	var p2 := _pay(p.khata_id, "2026-09-20", "", {"H": [10, 0]}, "keep")
	check(not db.can_undo_payment(p1.id), "only the latest payment can be undone")
	check(db.undo_payment(p2.id), "undo latest")
	check(db.undo_payment(p1.id), "then undo the earlier one")
	eq(db.next_work_from(p.khata_id), "2026-07-01", "period restored")
	eq(db.open_entries(p.khata_id).size(), 1, "kharchi open again")
	check(db.delete_entry(e.id), "open kharchi can be deleted")
	eq(db.live_balance(p.khata_id), 0, "clean after undo")
	# Payment date before the previous payment is rejected.
	_pay(p.khata_id, "2026-08-20", "", {"H": [10, 0]})
	var d: Dictionary = db.make_draft(p.khata_id, "2026-08-10", "2026-08-10")
	check(db.validate_draft(d) != "", "earlier payment date rejected")


func test_export_import() -> void:
	db.reset_for_tests()
	var m: Dictionary = db.add_mill("Mill A", 285, 420)
	var p: Dictionary = db.add_person("Export Test", [{"mill_id": m.id, "post": "H"}])
	db.set_khata_start(p.khata_id, "2026-07-01")
	db.add_entry(p.id, "kharchi", 700, "2026-08-01")
	_pay(p.khata_id, "2026-08-20", "", {"H": [10.5, 0]}, "keep")
	var before: int = db.live_balance(p.khata_id)
	var text: String = db.export_text()
	db.reset_for_tests()
	eq(db.live_balance(p.khata_id), 0, "wiped")
	var r: Dictionary = db.parse_import(text)
	check(not r.has("error"), "import parses")
	eq(r.summary.people, 1, "summary people")
	db.apply_import(r.data)
	eq(db.live_balance(p.khata_id), before, "balance survives export/import")
	check(db.live_balance(p.khata_id) is int, "balance is int after JSON")
	eq(db.parse_import("{\"hello\":1}").get("error", ""), "err_not_paytrack", "rejects other files")
	eq(db.parse_import("not json").get("error", ""), "err_not_paytrack", "rejects junk")
