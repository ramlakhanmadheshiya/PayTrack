class_name BalancesPage
extends Page
## Who has jama with you, who still owes advance.

var filter := 0  # 0 jama, 1 advance, 2 all


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_balances")
	var t: Dictionary = DB.totals()
	var tiles := UI.hbox(12)
	tiles.add_child(_tile(Lang.t("jama_with_you"), Lang.t("jama_with_you_sub"), t.jama, UI.GREEN, UI.GREEN_SOFT))
	tiles.add_child(_tile(Lang.t("advance_out"), Lang.t("advance_out_sub"), t.advance, UI.RED, UI.RED_SOFT))
	b.add_child(UI.margin(tiles, 16, 4, 16, 14))
	b.add_child(UI.margin(UI.segmented([Lang.t("jama"), Lang.t("advance"), Lang.t("all")], filter, func(i): filter = i; refresh()), 16, 0, 16, 10))
	var list := []
	for k in DB.active_khatas():
		var bal := DB.balance(k.id)
		if filter == 0 and bal <= 0:
			continue
		if filter == 1 and bal >= 0:
			continue
		list.append([k.id, bal])
	list.sort_custom(func(a, c): return absi(a[1]) > absi(c[1]))
	if list.is_empty():
		b.add_child(UI.empty_state("balance", Lang.t("nothing_here"), Lang.t("no_jama") if filter == 0 else (Lang.t("no_advance") if filter == 1 else Lang.t("no_people_body"))))
		return
	var c := UI.card()
	var rows := []
	for item in list:
		var kid: String = item[0]
		rows.append(Screens.khata_row(kid, func(): Screens.open_khata(kid)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))


func _tile(cap: String, sub: String, amount: int, col: Color, soft: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.pad(UI.box(soft if amount > 0 else UI.CARD, 16), 14, 12))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	v.add_child(UI.ellipsis(UI.label(cap, UI.S_CAP, col if amount > 0 else UI.TEXT2, 700)))
	v.add_child(UI.label(Money.rs(amount), UI.S_TITLE, col if amount > 0 else UI.TEXT3, 700, true))
	v.add_child(UI.wrapped(UI.label(sub, 12, UI.TEXT2)))
	p.add_child(v)
	return p
