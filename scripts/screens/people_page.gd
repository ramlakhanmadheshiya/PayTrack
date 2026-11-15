class_name PeoplePage
extends Page
## "Mills & People" tab. A main toggle at the top:
##   Mills  – the mills made once and used every month; tap one to edit its
##            name and F/H rates, hide it or delete it.
##   People – everyone, one row per khata (a group is one row), with
##            All / Masters / Groups. Each list has its own + next to its label.

var mode := 1     # 0 mills, 1 people
var query := ""
var filter := 0   # 0 all, 1 masters, 2 groups
var _list: VBoxContainer


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_people")
	b.add_child(UI.margin(UI.segmented([Lang.t("tab_mills"), Lang.t("people")], mode, func(i): mode = i; query = ""; refresh()), 16, 4, 16, 10))
	if mode == 0:
		_build_mills(b)
	else:
		_build_people(b)


# ---------------------------------------------------------------------------
# Mills
# ---------------------------------------------------------------------------

func _build_mills(b: VBoxContainer) -> void:
	var mills: Array = DB.mills_list()
	b.add_child(UI.section_title(Lang.t("mills_n", [mills.size()]), UI.small_button(Lang.t("add_mill"), "tinted", func(): MillEditSheet.open(""), "plus")))
	var c := UI.card()
	var rows := []
	var today := Dates.today()
	for m in mills:
		var id: String = m.id
		var rates := "F ₹%s  ·  H ₹%s" % [Money.group(DB.mill_rate(id, "F", today)), Money.group(DB.mill_rate(id, "H", today))]
		rows.append(UI.row(m.name, rates, null, func(): MillEditSheet.open(id), true, Icons.make("mill", UI.ACCENT, 22)))
	if rows.is_empty():
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_mills_body"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
	else:
		UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	var hidden := []
	for m in DB.mills_list(true):
		if m.get("archived", false):
			hidden.append(m)
	if not hidden.is_empty():
		b.add_child(UI.section_title(Lang.t("hidden_mills_title", [hidden.size()])))
		var hc := UI.card()
		var hr := []
		for m in hidden:
			var id: String = m.id
			hr.append(UI.row(m.name, Lang.t("hidden"), null, func(): MillEditSheet.open(id), true, Icons.make("mill", UI.TEXT3, 22)))
		UI.add_rows(hc, hr)
		b.add_child(UI.margin(hc, 16, 0, 16, 0))


# ---------------------------------------------------------------------------
# People
# ---------------------------------------------------------------------------

func _build_people(b: VBoxContainer) -> void:
	if DB.people_list(true).is_empty():
		b.add_child(UI.empty_state("people", Lang.t("no_people"), Lang.t("no_people_body"), UI.small_button(Lang.t("add_person"), "primary", func(): AddPersonSheet.open(), "plus")))
		return
	b.add_child(UI.margin(UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill()), 16, 0, 16, 10))
	b.add_child(UI.margin(UI.segmented([Lang.t("all"), Lang.t("masters"), Lang.t("families")], filter, func(i): filter = i; refresh()), 16, 0, 16, 0))
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


func _add_master() -> void:
	## New person, then which mill they are master at (and their salary).
	AddPersonSheet.open("", func(pid: String):
		WorkSheet.open(pid, "", func(): Screens.open_person(pid), ["BM"]))


func _fill() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	UI.clear(_list)
	var q := query.strip_edges().to_lower()
	var rows := []
	if filter == 1:
		for p in DB.people_list():
			if DB.is_master(p.id) and (q == "" or q in p.name.to_lower()):
				var pid: String = p.id
				var sal := Lang.t("per_month", [Money.group(DB.salary_on(pid, Dates.today()))])
				rows.append(UI.row(p.name, sal + " · " + Screens.person_work_summary(pid), UI.balance_label(DB.balance(p.khata_id)), func(): Screens.open_person(pid), true, UI.avatar(p.name, 38)))
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
				rows.append(UI.row(DB.family_title(kid), ", ".join(names), UI.balance_label(DB.balance(kid)), func(): Screens.open_family(kid), true, UI.avatar(DB.khata_title(kid), 38, UI.GREEN_SOFT, UI.GREEN)))
			else:
				var pid: String = k.payee_id
				var pn: String = DB.person(pid).name
				rows.append(UI.row(pn, Screens.person_work_summary(pid), UI.balance_label(DB.balance(kid)), func(): Screens.open_person(pid), true, UI.avatar(pn, 38)))
	# The label of each list carries its own + button.
	var head := ""
	var add: Tap
	match filter:
		1:
			head = Lang.t("masters_n", [rows.size()])
			add = UI.small_button(Lang.t("add_master"), "tinted", _add_master, "plus")
		2:
			head = Lang.t("groups_n", [rows.size()])
			add = UI.small_button(Lang.t("new_family"), "tinted", func(): NewFamilySheet.open(), "plus")
		_:
			head = Lang.t("everyone_n", [rows.size()])
			add = UI.small_button(Lang.t("add_person"), "tinted", func(): AddPersonSheet.open(), "plus")
	_list.add_child(UI.section_title(head, add))
	if rows.is_empty():
		_list.add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_match") if q != "" else Lang.t("nothing_here"), UI.S_SUB, UI.TEXT2)), 20, 4, 16, 0))
	else:
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
