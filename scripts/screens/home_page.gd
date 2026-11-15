class_name HomePage
extends Page
## Today: big Kharchi / Pay actions, balances at a glance, today's entries.


func _init() -> void:
	super._init()
	title = "PayTrack"


func title_accessory() -> Control:
	var seg := UI.segmented(["EN", "हिं"], 0 if Lang.lang == "en" else 1, func(i): Lang.set_lang("en" if i == 0 else "hi"))
	seg.custom_minimum_size = Vector2(108, 0)
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return seg


func build(b: VBoxContainer) -> void:
	title = Lang.t("app_name")
	var today := Dates.today()
	var wd := Lang.t("wdl_%d" % Dates.weekday(today))
	b.add_child(UI.margin(UI.label("%s, %s" % [wd, Lang.date_full(today)], UI.S_SUB, UI.TEXT2, 500), 16, 0, 16, 14))

	if not DB.has_any_data():
		_welcome(b)
		return

	_backup_banner(b)

	# Two big actions.
	var actions := UI.hbox(12)
	actions.add_child(_action_tile("kharchi", Lang.t("add_kharchi"), Lang.t("add_kharchi_sub"), UI.ACCENT, func(): Screens.open_entry_sheet()))
	actions.add_child(_action_tile("pay", Lang.t("pay"), Lang.t("pay_sub"), Color("#0F7B6C"), func(): Screens.start_pay_someone()))
	b.add_child(UI.margin(actions, 16, 0, 16, 0))

	# Balances at a glance.
	var t: Dictionary = DB.totals()
	var glance := UI.hbox(12)
	glance.add_child(_stat(Lang.t("jama_with_you"), t.jama, UI.GREEN, func(): _open_balances(0)))
	glance.add_child(_stat(Lang.t("advance_out"), t.advance, UI.RED, func(): _open_balances(1)))
	b.add_child(UI.margin(glance, 16, 12, 16, 0))

	# Today.
	var entries: Array = DB.entries_on(today)
	var total := 0
	for e in entries:
		total += int(e.amount) if Calc.entry_effect(e) < 0 else 0
	b.add_child(UI.section_title(Lang.t("today"), UI.label(Lang.t("given_total", [Money.group(total)]) if not entries.is_empty() else "", UI.S_CAP, UI.TEXT2, 600, true)))
	var c := UI.card()
	if entries.is_empty():
		var l := UI.wrapped(UI.label(Lang.t("no_entries_today"), UI.S_SUB, UI.TEXT2))
		UI.card_body(c).add_child(UI.margin(l, 16, 16, 16, 16))
	else:
		var rows := []
		for e in entries:
			var id: String = e.id
			rows.append(Screens.entry_row(e, true, func(): Screens.open_entry_sheet("", id)))
		UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))

	# Recent payments.
	var pays: Array = DB.payments_list()
	if not pays.is_empty():
		b.add_child(UI.section_title(Lang.t("recent_payments"), UI.link(Lang.t("see_all"), func(): UI.app.push(PaymentsPage.new()), UI.ACCENT, UI.S_SUB)))
		var pc := UI.card()
		var rows2 := []
		for i in mini(4, pays.size()):
			rows2.append(PaymentsPage.payment_row(pays[i]))
		UI.add_rows(pc, rows2)
		b.add_child(UI.margin(pc, 16, 0, 16, 0))


func _open_balances(filter: int) -> void:
	UI.app.switch_tab("balances")
	var p = UI.app.top_page()
	if p is BalancesPage:
		p.filter = filter
		p.refresh()


func _action_tile(icon: String, title_text: String, sub: String, col: Color, cb: Callable) -> Control:
	var t := Tap.new()
	var s := UI.pad(UI.box(col, 18), 16, 16)
	var sp := UI.pad(UI.box(col.darkened(0.15), 18), 16, 16)
	t.set_styles(s, sp, UI.pad(UI.box(col.darkened(0.06), 18), 16, 16))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.y = 118
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


func _stat(label_text: String, amount: int, col: Color, cb: Callable) -> Control:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(UI.CARD, 16), 16, 12), UI.pad(UI.box(UI.FILL_PRESSED, 16), 16, 12), UI.pad(UI.box(Color("#FAFAFC"), 16), 16, 12))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	v.add_child(UI.ellipsis(UI.label(label_text, UI.S_CAP, UI.TEXT2, 600)))
	v.add_child(UI.label(Money.rs(amount), UI.S_TITLE, col if amount != 0 else UI.TEXT3, 700, true))
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
	v.add_child(UI.button(Lang.t("add_first_mill"), "primary", func(): UI.app.switch_tab("mills"); MillEditSheet.open(""), "plus"))
	v.add_child(UI.button(Lang.t("import_backup"), "secondary", func(): Platform.import_backup(), "import"))
	v.add_child(UI.button(Lang.t("try_sample"), "plain", func(): UI.app.confirm(Lang.t("try_sample"), Lang.t("sample_body"), Lang.t("load_sample"), func(): DB.load_sample_data(); UI.app.toast(Lang.t("sample_loaded")))))
	b.add_child(UI.margin(c, 16, 0, 16, 0))
