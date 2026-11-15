class_name MillsPage
extends Page


func _init() -> void:
	super._init()


func nav_right() -> Control:
	return UI.icon_button("plus", func(): MillEditSheet.open(""))


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_mills")
	var mills: Array = DB.mills_list()
	if mills.is_empty():
		b.add_child(UI.empty_state("mill", Lang.t("no_mills"), Lang.t("no_mills_body"), UI.small_button(Lang.t("add_mill"), "primary", func(): MillEditSheet.open(""), "plus")))
		return
	b.add_child(UI.spacer(8))
	for m in mills:
		b.add_child(UI.margin(_mill_card(m), 16, 0, 16, 12))
	var hidden := DB.mills_list(true).size() - mills.size()
	if hidden > 0:
		b.add_child(UI.footnote(Lang.t("hidden_mills", [hidden])))
		var hc := UI.card()
		var rows := []
		for m in DB.mills_list(true):
			if m.get("archived", false):
				var id: String = m.id
				rows.append(UI.row(m.name, Lang.t("hidden"), null, func(): Screens.open_mill(id)))
		UI.add_rows(hc, rows)
		b.add_child(UI.margin(hc, 16, 8, 16, 0))


func _mill_card(m: Dictionary) -> Control:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(UI.CARD, 16), 16, 14), UI.pad(UI.box(UI.FILL_PRESSED, 16), 16, 14), UI.pad(UI.box(Color("#FAFAFC"), 16), 16, 14))
	var h := UI.hbox(14)
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", UI.box(UI.ACCENT_SOFT, 12))
	circle.custom_minimum_size = Vector2(46, 46)
	var cc := CenterContainer.new()
	cc.add_child(Icons.make("mill", UI.ACCENT, 24))
	circle.add_child(cc)
	h.add_child(circle)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.ellipsis(UI.label(m.name, UI.S_HEAD + 1, UI.TEXT, 600)))
	var today := Dates.today()
	var rates := "F ₹%s  ·  H ₹%s" % [Money.group(DB.mill_rate(m.id, "F", today)), Money.group(DB.mill_rate(m.id, "H", today))]
	v.add_child(UI.label(rates, UI.S_SUB, UI.TEXT2, 500, true))
	v.add_child(UI.label(Lang.t("n_workers", [DB.mill_workers(m.id).size()]), UI.S_CAP, UI.TEXT3, 500))
	h.add_child(v)
	h.add_child(Icons.make("chevron", UI.TEXT3, 16))
	t.add_child_ignoring(h)
	var id: String = m.id
	t.tapped.connect(func(): Screens.open_mill(id))
	return t
