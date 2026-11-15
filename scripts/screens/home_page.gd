class_name HomePage
extends Page
## Home: Kharchi / Advance / Jama / Pay, then every transaction, newest first.

var shown := 60
var _list: VBoxContainer


func _init() -> void:
	super._init()
	title = "PayTrack"


func title_accessory() -> Control:
	var seg := UI.segmented(["EN", "हिं"], 0 if Lang.lang == "en" else 1, func(i): Lang.set_lang("en" if i == 0 else "hi"))
	seg.custom_minimum_size = Vector2(108, 0)
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return seg


func nav_right() -> Control:
	return UI.icon_button("history", func(): UI.app.push(ActivityPage.new()))


func build(b: VBoxContainer) -> void:
	title = Lang.t("app_name")
	var today := Dates.today()
	var wd := Lang.t("wdl_%d" % Dates.weekday(today))
	b.add_child(UI.margin(UI.label("%s, %s" % [wd, Lang.date_full(today)], UI.S_SUB, UI.TEXT2, 500), 16, 0, 16, 14))

	if not DB.has_any_data():
		_welcome(b)
		return

	_backup_banner(b)

	# Four actions: give kharchi, give advance, take jama, pay.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.add_child(_action_tile("kharchi", Lang.t("add_kharchi"), Lang.t("add_kharchi_sub"), UI.ACCENT, func(): Screens.open_entry_sheet("", "", "kharchi")))
	grid.add_child(_action_tile("rupee", Lang.t("add_advance"), Lang.t("add_advance_sub"), Color("#C2410C"), func(): Screens.open_entry_sheet("", "", "advance")))
	grid.add_child(_action_tile("import", Lang.t("add_jama"), Lang.t("add_jama_sub"), Color("#15803D"), func(): Screens.open_entry_sheet("", "", "received")))
	grid.add_child(_action_tile("pay", Lang.t("pay"), Lang.t("pay_sub"), Color("#0F7B6C"), func(): Screens.start_pay_someone()))
	b.add_child(UI.margin(grid, 16, 0, 16, 0))

	# Every transaction, newest first, a day at a time.
	_list = UI.vbox(0)
	b.add_child(_list)
	_fill_history()


func _fill_history() -> void:
	UI.clear(_list)
	var items := []
	for e in DB.data.entries:
		if e.type != "adjust":
			items.append({"date": e.date, "created": int(e.created), "e": e})
	for p in DB.data.payments:
		items.append({"date": p.date, "created": int(p.created), "p": p})
	items.sort_custom(func(a, c): return a.date > c.date if a.date != c.date else a.created > c.created)
	if items.is_empty():
		_list.add_child(UI.section_title(Lang.t("transactions")))
		var c := UI.card()
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_transactions"), UI.S_SUB, UI.TEXT2)), 16, 16, 16, 16))
		_list.add_child(UI.margin(c, 16, 0, 16, 0))
		return
	var n := mini(shown, items.size())
	var i := 0
	while i < n:
		var d: String = items[i].date
		var rows := []
		var given := 0
		while i < n and items[i].date == d:
			var it: Dictionary = items[i]
			if it.has("e"):
				var e: Dictionary = it.e
				var id: String = e.id
				if Calc.entry_effect(e) < 0:
					given += int(e.amount)
				rows.append(Screens.entry_row(e, true, func(): Screens.open_entry_sheet("", id)))
			else:
				given += int(it.p.paid)
				rows.append(PaymentsPage.payment_row(it.p))
			i += 1
		_list.add_child(UI.section_title(Lang.day_label(d), UI.label(Lang.t("given_total", [Money.group(given)]) if given > 0 else "", UI.S_CAP, UI.TEXT2, 600, true)))
		var c := UI.card()
		UI.add_rows(c, rows)
		_list.add_child(UI.margin(c, 16, 0, 16, 0))
	if items.size() > shown:
		_list.add_child(UI.margin(UI.button(Lang.t("show_more"), "secondary", func(): shown += 60; _fill_history()), 16, 14, 16, 0))


func _action_tile(icon: String, title_text: String, sub: String, col: Color, cb: Callable) -> Control:
	var t := Tap.new()
	var s := UI.pad(UI.box(col, 18), 16, 16)
	var sp := UI.pad(UI.box(col.darkened(0.15), 18), 16, 16)
	t.set_styles(s, sp, UI.pad(UI.box(col.darkened(0.06), 18), 16, 16))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.y = 96
	var v := UI.vbox(4)
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.2), 20))
	circle.custom_minimum_size = Vector2(40, 40)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var cc := CenterContainer.new()
	cc.add_child(Icons.make(icon, Color.WHITE, 22))
	circle.add_child(cc)
	v.add_child(circle)
	v.add_child(UI.flex())
	v.get_child(1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title_text, UI.S_TITLE - 2, Color.WHITE, 700))
	v.add_child(UI.ellipsis(UI.label(sub, UI.S_CAP, Color(1, 1, 1, 0.85), 500)))
	t.add_child_ignoring(v)
	t.tapped.connect(cb)
	return t


func _backup_banner(b: VBoxContainer) -> void:
	var last: String = DB.setting("last_export", "")
	var days := 999 if last == "" else Dates.diff_days(last, Dates.today())
	if days < 7:
		return
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(UI.ORANGE_SOFT, 14), 14, 12), UI.pad(UI.box(UI.ORANGE_SOFT.darkened(0.05), 14), 14, 12))
	var h := UI.hbox(12)
	h.add_child(Icons.make("export", UI.ORANGE, 22))
	var v := UI.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(Lang.t("backup_reminder_title"), UI.S_SUB, UI.TEXT, 600))
	var msg := Lang.t("backup_never") if last == "" else Lang.t("backup_days", [days])
	v.add_child(UI.wrapped(UI.label(msg, UI.S_CAP, UI.TEXT2)))
	h.add_child(v)
	h.add_child(Icons.make("chevron", UI.TEXT3, 14))
	t.add_child_ignoring(h)
	t.tapped.connect(func(): Platform.export_backup())
	b.add_child(UI.margin(t, 16, 0, 16, 12))


func _welcome(b: VBoxContainer) -> void:
	var c := UI.card(20)
	var v := UI.card_body(c)
	v.add_theme_constant_override("separation", 10)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(64, 64)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(logo)
	v.add_child(UI.label(Lang.t("welcome_title"), UI.S_TITLE, UI.TEXT, 700))
	v.add_child(UI.wrapped(UI.label(Lang.t("welcome_body"), UI.S_SUB, UI.TEXT2)))
	var steps := [["mill", Lang.t("welcome_step1")], ["people", Lang.t("welcome_step2")], ["kharchi", Lang.t("welcome_step3")], ["pay", Lang.t("welcome_step4")]]
	for s in steps:
		var h := UI.hbox(12)
		h.add_child(Icons.make(s[0], UI.ACCENT, 22))
		h.add_child(UI.wrapped(UI.label(s[1], UI.S_SUB, UI.TEXT)))
		v.add_child(h)
	v.add_child(UI.spacer(6))
	v.add_child(UI.button(Lang.t("add_first_mill"), "primary", func(): UI.app.switch_tab("people"); MillEditSheet.open(""), "plus"))
	v.add_child(UI.button(Lang.t("import_backup"), "secondary", func(): Platform.import_backup(), "import"))
	v.add_child(UI.button(Lang.t("try_sample"), "plain", func(): UI.app.confirm(Lang.t("try_sample"), Lang.t("sample_body"), Lang.t("load_sample"), func(): DB.load_sample_data(); UI.app.toast(Lang.t("sample_loaded")))))
	b.add_child(UI.margin(c, 16, 0, 16, 0))
