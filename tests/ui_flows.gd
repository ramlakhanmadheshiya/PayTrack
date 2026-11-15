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

	# In-app keyboards: type a rate on the number pad, then the name with the
	# letter keyboard — letters must go to the name, never to the rate.
	MillEditSheet.open("")
	await wait()
	ms = app.top_sheet()
	var rate_field: NumField = null
	for n in ms.find_children("*", "", true, false):
		if n is NumField:
			rate_field = n
			break
	app.numpad_open(rate_field)
	await wait()
	app.numpad.press("2")
	app.numpad.press("0")
	app.numpad_open(ms.name_box)
	await wait()
	check(not app.numpad.visible and app.textpad.visible, "letter keyboard replaced number pad")
	for k in ["t", "e", "m", "p"]:
		app.textpad.press(k)
	check(ms.name_box.text == "Temp", "letters typed into name (auto capital)")
	check(int(rate_field.value) == 20, "rate kept 20")
	app.numpad_close()
	ms.close()
	await wait(10)

	# Delete a wrong mill.
	var wrong: Dictionary = DB.add_mill("Wrong Mill", 1, 1)
	Screens.open_mill(wrong.id)
	await wait(6)
	DB.delete_mill(wrong.id)
	app.pop()
	await wait(6)
	check(DB.mills_list().size() == 1, "wrong mill deleted")

	# Add people with only a name; work is set from the mill.
	for n in ["Worker A", "Worker B", "Head C", "Member D", "Master E"]:
		AddWorkerSheet.open(mid)
		await wait()
		var aw: AddWorkerSheet = app.top_sheet()
		var pl: PersonList = null
		for c in aw.body.get_children():
			if c is PersonList:
				pl = c
		pl.on_add.call(n)
		await wait(4)
		var ws: WorkSheet = app.top_sheet()
		check(ws is WorkSheet and ws.mill_id == mid, "work sheet for the mill")
		ws.posts = ["BM"] if n.begins_with("Master") else ["F", "H"]
		ws.salary = 22000
		ws.build()
		ws._save()
		await wait(10)
	check(DB.people_list().size() == 5, "five people")
	check(DB.is_master(DB.find_person_by_name("Master E").id), "master has BM")
	check(DB.salary_on(DB.find_person_by_name("Master E").id, "2026-11-15") == 22000, "salary saved")
	# Edit one person's work at the mill (only F now).
	var wb := DB.find_person_by_name("Worker B")
	WorkSheet.open(wb.id, mid)
	await wait()
	var wsb: WorkSheet = app.top_sheet()
	wsb.posts = ["F"]
	wsb._save()
	await wait(8)
	check(DB.posts_at(wb.id, mid) == ["F"], "posts at mill edited")

	# New person sheet asks only name + starting balance; duplicate asks "same person?".
	AddPersonSheet.open("Worker A")
	await wait()
	var aps: AddPersonSheet = app.top_sheet()
	aps._save()
	await wait()
	check(app.top_sheet() is SamePersonSheet, "same-person question shown")
	app.top_sheet().close()
	aps.close()
	await wait(10)
	check(DB.people_list().size() == 5, "duplicate not added")
	AddPersonSheet.open("Temp Person")
	await wait()
	aps = app.top_sheet()
	aps.opening_kind = 1
	aps.opening_amount = 500
	aps._save()
	await wait(10)
	var tp := DB.find_person_by_name("Temp Person")
	check(DB.live_balance(tp.khata_id) == 500, "starting jama saved")
	check(DB.can_delete_person(tp.id), "new person can be deleted")
	check(DB.delete_person(tp.id), "person deleted")
	app.go_tab_root("people")
	await wait(4)

	# Family made from People › Families.
	var head := DB.find_person_by_name("Head C")
	var mem := DB.find_person_by_name("Member D")
	NewFamilySheet.open()
	await wait()
	var nf: NewFamilySheet = app.top_sheet()
	nf.head_id = head.id
	nf.members = [mem.id]
	nf._save()
	await wait(8)
	check(DB.is_family(DB.khata_of(head.id).id), "family exists")
	check(app.top_page() is FamilyPage, "family page opened")
	app.go_tab_root("people")
	var pp: PeoplePage = app.top_page()
	pp.filter = 0
	pp.refresh()
	await wait(4)

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
	# Correct the payment: reopens with the same numbers; leaving keeps the old one.
	Screens.correct_payment(pid)
	await wait()
	var confirm_btn: Tap = null
	for n in app.top_sheet().body.find_children("*", "", true, false):
		if n is Tap:
			confirm_btn = n
	confirm_btn.tapped.emit()
	await wait(8)
	var cf: PayFlow = app.top_page()
	check(cf.correcting.size() == 1 and DB.payment(pid).is_empty(), "payment reopened for correction")
	check(cf.drafts[0].rows[0].att == 10.0, "same attendance prefilled")
	for d in cf.correcting:
		DB.commit_payment(d)
	cf.correcting.clear()
	app.pop()
	await wait(6)
	var again: Dictionary = DB.last_payment(a.khata_id)
	check(again.new_balance == 2850 + 4200 - 900, "old payment put back exactly")
	pid = again.id
	# Bill shows exact dates.
	check(Lang.period("2026-10-01", "2026-11-15") == "1 Oct – 15 Nov 2026", "exact period text")
	check(Lang.period("2026-10-01", "2026-10-31") == "1 – 31 Oct 2026", "exact month text")
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
	var wb_pay: Dictionary = {}
	for id in flow.saved:
		if DB.payment(id).payee_name == "Worker B":
			wb_pay = DB.payment(id)
	check(wb_pay.rows.size() == 1 and wb_pay.rows[0].post == "F", "edited work used in pay")
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
	# Every new screen opens without errors.
	Screens.open_family(DB.khata_of(head.id).id)
	await wait(4)
	Screens.open_person(mem.id)
	await wait(4)
	Screens.open_person(a.id)
	await wait(4)
	app.top_page()._menu()
	await wait(4)
	app.top_sheet().close()
	await wait(10)

	print("UI flows: %d checks, %d failed" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)
