class_name PeoplePage
extends Page

var query := ""
var filter := 0  # 0 all, 1 masters, 2 families
var _list: VBoxContainer


func _init() -> void:
	super._init()


func nav_right() -> Control:
	return UI.icon_button("plus", func(): AddWorkSheet.open_new_person())


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_people")
	if DB.people_list(true).is_empty():
		b.add_child(UI.empty_state("people", Lang.t("no_people"), Lang.t("no_people_body"), UI.small_button(Lang.t("add_person"), "primary", func(): AddWorkSheet.open_new_person(), "plus")))
		return
	var s := UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill())
	b.add_child(UI.margin(s, 16, 4, 16, 10))
	b.add_child(UI.margin(UI.segmented([Lang.t("all"), Lang.t("masters"), Lang.t("families")], filter, func(i): filter = i; refresh()), 16, 0, 16, 6))
	_list = UI.vbox(0)
	b.add_child(_list)
	_fill()


func _fill() -> void:
	UI.clear(_list)
	var q := query.strip_edges().to_lower()
	var people: Array = DB.people_list()
	var rows := []
	for p in people:
		if q != "" and not q in p.name.to_lower():
			continue
		if filter == 1 and not DB.is_master(p.id):
			continue
		var k := DB.khata_of(p.id)
		if filter == 2 and not DB.is_family(k.id):
			continue
		var id: String = p.id
		var sub := Screens.person_work_summary(id)
		var right: Control
		if DB.is_family(k.id) and k.payee_id != id:
			sub = Lang.t("in_family_of", [DB.khata_title(k.id)]) + " · " + sub
			right = UI.label("", UI.S_SUB)
		else:
			right = UI.balance_label(DB.live_balance(k.id))
		rows.append(UI.row(p.name, sub, right, func(): Screens.open_person(id), true, UI.avatar(p.name, 38)))
	if rows.is_empty():
		_list.add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_match"), UI.S_SUB, UI.TEXT2)), 16, 16, 16, 0))
	else:
		_list.add_child(UI.margin(UI.label(Lang.t("n_people", [rows.size()]), UI.S_CAP, UI.TEXT2, 600), 16, 10, 16, 8))
		var c := UI.card()
		UI.add_rows(c, rows)
		_list.add_child(UI.margin(c, 16, 0, 16, 0))
	var hidden := 0
	for p in DB.people_list(true):
		if p.get("archived", false):
			hidden += 1
	if hidden > 0 and q == "":
		_list.add_child(UI.section_title(Lang.t("hidden_people", [hidden])))
		var hc := UI.card()
		var hr := []
		for p in DB.people_list(true):
			if p.get("archived", false):
				var id: String = p.id
				hr.append(UI.row(p.name, Lang.t("hidden"), null, func(): Screens.open_person(id)))
		UI.add_rows(hc, hr)
		_list.add_child(UI.margin(hc, 16, 0, 16, 0))
