extends Node
## Walks through the main screens with made-up data and saves screenshots.
##   godot --path . tests/screenshots.tscn -- <out_dir> [phone|ipad] [en|hi]
## Never touches real saved data (saving is switched off).

var out := "user://shots"
var mode := "phone"
var lang := "en"
var app: Control
var db: Node
var n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		mode = args[1]
	if args.size() > 2:
		lang = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode = false  # keep drawing so screenshots never wait
	db = DB
	db.save_enabled = false
	db.data = db.empty_data()
	Dates.fake_today = "2026-11-15"
	var size := Vector2i(390, 844) if mode == "phone" else Vector2i(1180, 820)
	var scale := DisplayServer.screen_get_scale()
	DisplayServer.window_set_size(Vector2i(size * scale))
	Lang.set_lang(lang, false)
	_run.call_deferred()


func wait(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


func shot(name: String) -> void:
	await wait(24)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	img.save_png("%s/%02d-%s-%s-%s.png" % [out, n, mode, lang, name])
	print("shot ", name, " ", Time.get_ticks_msec())


func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(app)
	await wait(10)
	await shot("welcome")
	_sample()
	await wait()
	await shot("home")
	# Kharchi sheet.
	Screens.open_entry_sheet()
	await shot("kharchi-pick")
	var sheet: Sheet = app.top_sheet()
	sheet.person_id = db.find_person_by_name("Kishan").id
	sheet._rebuild()
	await wait()
	sheet._amount_field.set_value(500)
	sheet.amount = 500
	sheet._update_save()
	app.numpad_open(sheet._amount_field)
	await shot("kharchi-amount")
	app.numpad_close()
	sheet.close()
	await wait(20)
	# Mills.
	app.switch_tab("mills")
	await shot("mills")
	var first_mill: Dictionary = db.mills_list()[0]
	Screens.open_mill(first_mill.id)
	await shot("mill")
	app.top_page()._menu()
	await shot("mill-menu")
	app.top_sheet().close()
	await wait(20)
	MillEditSheet.open(first_mill.id)
	await wait(6)
	await shot("keyboard")
	app.numpad_close()
	app.top_sheet().close()
	await wait(20)
	# Pay by mill.
	Screens.start_pay_mill(first_mill.id)
	await shot("pay-choose")
	var flow: PayFlow = app.top_page()
	for k in flow.selected:
		flow.selected[k] = true
	flow.khata_ids = flow._selected_list()
	flow._make_drafts()
	flow.step = 1
	var values := {"F": [68.0, 8.0], "H": [29.0, 0.0], "BM": [32.0, 0.0]}
	for d in flow.drafts:
		for r in d.rows:
			r.att = values[r.post][0]
			r.hr = values[r.post][1]
	flow.refresh()
	await shot("pay-attendance")
	flow.scroll.scroll_vertical = 700
	await shot("pay-attendance-2")
	# Master over two months: split.
	var master_k: String = db.find_person_by_name("Ramesh").khata_id
	for d in flow.drafts:
		if d.khata_id == master_k:
			d.upto = "2026-11-15"
			d.upto_custom = true
			db.rebuild_rows(d)
			d.rows[0].mode = "split"
			d.rows[0].months[0].att = 31.0
			d.rows[0].months[1].att = 12.0
	flow.refresh()
	flow.scroll.scroll_vertical = 0
	await shot("pay-split")
	flow._go_hisab()
	await shot("hisab")
	flow.scroll.scroll_vertical = 600
	await shot("hisab-2")
	flow._save_all()
	await shot("done")
	var first_pay: String = flow.saved[0]
	Screens.open_payment(first_pay)
	await shot("bill")
	var flow_master: String = ""
	for id in flow.saved:
		if db.payment(id).payee_name == "Ramesh":
			flow_master = id
	Screens.open_payment(flow_master)
	await shot("bill-master")
	app.pop_to_root()
	# People.
	app.switch_tab("people")
	await shot("people")
	Screens.open_person(db.find_person_by_name("Kishan").id)
	await shot("person")
	Screens.open_family(db.find_person_by_name("Hari").khata_id)
	await shot("family")
	WorkSheet.open(db.find_person_by_name("Kishan").id, first_mill.id)
	await shot("work-sheet")
	app.top_sheet().close()
	await wait(20)
	app.switch_tab("balances")
	await shot("balances")
	app.switch_tab("more")
	await shot("more")
	app.switch_tab("home")
	await shot("home-after")
	get_tree().quit()


func _sample() -> void:
	db.load_sample_data()
