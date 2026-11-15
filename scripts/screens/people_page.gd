class_name PeoplePage
extends Page
## Everyone, one row per khata: a family is one row ("Hari family"),
## tap it to see its members. Families are made from the Families filter.

var query := ""
var filter := 0  # 0 all, 1 masters, 2 families
var _list: VBoxContainer


func _init() -> void:
	super._init()


func nav_right() -> Control:
	return UI.icon_button("plus", func(): AddPersonSheet.open())


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_people")
	if DB.people_list(true).is_empty():
		b.add_child(UI.empty_state("people", Lang.t("no_people"), Lang.t("no_people_body"), UI.small_button(Lang.t("add_person"), "primary", func(): AddPersonSheet.open(), "plus")))
		return
	b.add_child(UI.margin(UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill()), 16, 4, 16, 10))
	b.add_child(UI.margin(UI.segmented([Lang.t("all"), Lang.t("masters"), Lang.t("families")], filter, func(i): filter = i; refresh()), 16, 0, 16, 6))
	_list = UI.vbox(0)
	b.add_child(_list)
	_fill()


func _matches(kid: String, q: String) -> bool:
	if q == "":
		return true
	for p in DB.khata_members(kid):
		if q in p.name.to_lower():
			return true
	return false


func _fill() -> void:
	UI.clear(_list)
	var q := query.strip_edges().to_lower()
	var rows := []
	if filter == 1:
		for p in DB.people_list():
			if DB.is_master(p.id) and (q == "" or q in p.name.to_lower()):
				var pid: String = p.id
				var sal := Lang.t("per_month", [Money.group(DB.salary_on(pid, Dates.today()))])
				rows.append(UI.row(p.name, sal + " · " + Screens.person_work_summary(pid), UI.balance_label(DB.live_balance(p.khata_id)), func(): Screens.open_person(pid), true, UI.avatar(p.name, 38)))
	else:
		var list: Array = DB.family_khatas() if filter == 2 else DB.active_khatas()
		for k in list:
			if not _matches(k.id, q):
				continue
			var kid: String = k.id
			if DB.is_family(kid):
				var names := []
				for p in DB.khata_members(kid):
					names.append(p.name)
				rows.append(UI.row(DB.family_title(kid), ", ".join(names), UI.balance_label(DB.live_balance(kid)), func(): Screens.open_family(kid), true, UI.avatar(DB.khata_title(kid), 38, UI.GREEN_SOFT, UI.GREEN)))
			else:
				var pid: String = k.payee_id
				var pn: String = DB.person(pid).name
				rows.append(UI.row(pn, Screens.person_work_summary(pid), UI.balance_label(DB.live_balance(kid)), func(): Screens.open_person(pid), true, UI.avatar(pn, 38)))
	if filter == 2:
		rows.append(UI.row(Lang.t("new_family"), Lang.t("new_family_help"), null, func(): NewFamilySheet.open(), false, Icons.make("plus", UI.ACCENT, 22)))
	if rows.is_empty():
		_list.add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_match"), UI.S_SUB, UI.TEXT2)), 16, 16, 16, 0))
	else:
		var count := rows.size() - (1 if filter == 2 else 0)
		_list.add_child(UI.margin(UI.label(Lang.t("n_families", [count]) if filter == 2 else Lang.t("n_rows", [count]), UI.S_CAP, UI.TEXT2, 600), 16, 10, 16, 8))
		var c := UI.card()
		UI.add_rows(c, rows)
		_list.add_child(UI.margin(c, 16, 0, 16, 0))
	var hidden := []
	for p in DB.people_list(true):
		if p.get("archived", false):
			hidden.append(p)
	if not hidden.is_empty() and q == "" and filter == 0:
		_list.add_child(UI.section_title(Lang.t("hidden_people", [hidden.size()])))
		var hc := UI.card()
		var hr := []
		for p in hidden:
			var id: String = p.id
			hr.append(UI.row(p.name, Lang.t("hidden"), null, func(): Screens.open_person(id)))
		UI.add_rows(hc, hr)
		_list.add_child(UI.margin(hc, 16, 0, 16, 0))
