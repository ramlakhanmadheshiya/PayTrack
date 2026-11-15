extends Node
## Drives real screens and sheets with made-up data; any script error is printed
## by Godot (look for "SCRIPT ERROR"), wrong results print "FAIL".
##   godot --path . tests/ui_flows.tscn

var app: Control
var fails := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func wait(frames := 4) -> void:
	for i in frames:
		await get_tree().process_frame


func _ready() -> void:
	OS.low_processor_usage_mode = false
	DB.save_enabled = false
	DB.data = DB.empty_data()
	Dates.fake_today = "2026-11-15"
	_run.call_deferred()


func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(app)
	await wait(6)

	# Add a mill through the sheet.
	MillEditSheet.open("")
	await wait()
	var ms: MillEditSheet = app.top_sheet()
	ms.name_box.text = "Mill One"
	ms.f_rate = 285
	ms.h_rate = 420
	ms._save()
	await wait(8)
	check(DB.mills_list().size() == 1, "mill added")
	var mid: String = DB.mills_list()[0].id
	check(app.top_page() is MillPage, "mill page opened")

	# Duplicate mill name is refused.
	MillEditSheet.open("")
	await wait()
	ms = app.top_sheet()
	ms.name_box.text = "mill one"
	ms.f_rate = 1
	ms.h_rate = 1
	ms._save()
	await wait()
	check(DB.mills_list().size() == 1, "duplicate mill refused")
	ms.close()
	await wait(10)

	# Add workers from the mill page (new names).
	for n in ["Worker A", "Worker B", "Head C", "Member D", "Master E"]:
		AddWorkSheet.open_for_mill(mid)
		await wait()
		var s: AddWorkSheet = app.top_sheet()
		s.new_name = n
		s._to_details()
		await wait()
		s.selected[mid] = ["BM"] if n.begins_with("Master") else ["F", "H"]
		s.salary = 22000
		s.build()
		s._save()
		await wait(10)
	check(DB.people_list().size() == 5, "five people")
	check(DB.is_master(DB.find_person_by_name("Master E").id), "master has BM")
	check(DB.salary_on(DB.find_person_by_name("Master E").id, "2026-11-15") == 22000, "salary saved")

	# Duplicate person name → question sheet, "No, add a tag".
	AddWorkSheet.open_new_person("worker a")
	await wait()
	var dup: AddWorkSheet = app.top_sheet()
	dup._save()
	await wait()
	check(app.top_sheet() != dup, "same-person question shown")
	app.top_sheet().close()
	dup.close()
	await wait(10)
	check(DB.people_list().size() == 5, "duplicate not added")

	# Family from the person page.
	var head := DB.find_person_by_name("Head C")
	var mem := DB.find_person_by_name("Member D")
	Screens.open_person(head.id)
	await wait(6)
	check(DB.join_family(head.id, mem.id) == "", "family join")
	await wait(6)
	check(DB.is_family(DB.khata_of(head.id).id), "family exists")

	# Kharchi through the entry sheet, then edit and delete.
	var a := DB.find_person_by_name("Worker A")
	Screens.open_entry_sheet(a.id)
	await wait()
	var es: EntrySheet = app.top_sheet()
	es.amount = 700
	es._save()
	await wait(10)
	var open_e := DB.open_entries(a.khata_id)
	check(open_e.size() == 1 and open_e[0].amount == 700, "kharchi saved")
	Screens.open_entry_sheet("", open_e[0].id)
	await wait()
	es = app.top_sheet()
	es.amount = 900
	es.type = "advance"
	es._save()
	await wait(10)
	check(DB.entry(open_e[0].id).amount == 900 and DB.entry(open_e[0].id).type == "advance", "entry edited")

	# Rates and salary sheets.
	RateSheet.open_mill(mid)
	await wait()
	var rs: RateSheet = app.top_sheet()
	rs.from = "2026-12-01"
	rs.f_rate = 300
	rs.h_rate = 450
	rs._save()
	await wait(10)
	check(DB.mill_rate(mid, "H", "2026-12-05") == 450 and DB.mill_rate(mid, "H", "2026-11-20") == 420, "rate change dated")
	RateSheet.open_salary(DB.find_person_by_name("Master E").id)
	await wait()
	rs = app.top_sheet()
	rs.salary = 25000
	rs._save()
	await wait(10)

	# Pay one person end to end through the flow page.
	app.go_tab_root("home")
	Screens.start_pay_khata(a.khata_id)
	await wait(6)
	var flow: PayFlow = app.top_page()
	check(flow.drafts.size() == 1, "draft made")
	for r in flow.drafts[0].rows:
		r.att = 10.0
	flow.refresh()
	await wait()
	flow._go_hisab()
	await wait()
	check(flow.step == 2, "hisab step")
	flow.drafts[0].choice = "keep"
	flow.refresh()
	await wait()
	flow._save_all()
	await wait(6)
	check(flow.step == 3 and flow.saved.size() == 1, "payment saved")
	var pid: String = flow.saved[0]
	check(DB.payment(pid).new_balance == 2850 + 4200 - 900, "keep jama balance")
	Screens.open_payment(pid)
	await wait(6)
	check(DB.can_undo_payment(pid), "undo allowed")
	DB.undo_payment(pid)
	await wait(6)
	check(DB.payment(pid).is_empty(), "undone")

	# Pay by mill with families and a master over two months.
	app.go_tab_root("mills")
	Screens.start_pay_mill(mid)
	await wait(6)
	flow = app.top_page()
	for k in flow.selected:
		flow.selected[k] = true
	flow.khata_ids = flow._selected_list()
	flow._make_drafts()
	flow.step = 1
	for d in flow.drafts:
		d.upto = "2026-11-15"
		d.upto_custom = true
		DB.rebuild_rows(d)
		for r in d.rows:
			r.att = 5.0
			if r.post == "BM":
				r.mode = "split"
				r.months[0].att = 31.0
				r.months[1].att = 15.0
	flow.refresh()
	await wait()
	flow._go_hisab()
	await wait()
	check(flow.step == 2, "mill hisab")
	flow._save_all()
	await wait(6)
	check(flow.saved.size() == 4, "four khatas paid (family counted once)")
	var master_pay := {}
	for id in flow.saved:
		var p := DB.payment(id)
		if p.payee_name == "Master E":
			master_pay = p
	check(not master_pay.is_empty() and master_pay.earnings == 22000 + 12500, "split master pay with raise from 15 Nov? (salary 25000 from Nov 1)")

	# Date sheet opens and picks.
	var picked := {"d": ""}
	DateSheet.open("Test", "2026-11-15", func(d): picked.d = d, [["Today", "2026-11-15"]])
	await wait()
	var dsh: DateSheet = app.top_sheet()
	dsh._pick("2026-11-10")
	await wait(10)
	check(picked.d == "2026-11-10", "date picked")

	# Every tab in Hindi, then back.
	Lang.set_lang("hi", false)
	for t in ["home", "mills", "people", "balances", "more"]:
		app.switch_tab(t)
		await wait(3)
	Lang.set_lang("en", false)
	app.set_text_size(1.3)
	await wait(4)
	app.set_text_size(1.0)
	await wait(4)

	# Export text round trip (no file written).
	var r := DB.parse_import(DB.export_text())
	check(not r.has("error") and r.summary.people == 5, "export parses")

	print("UI flows: %d checks, %d failed" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)
