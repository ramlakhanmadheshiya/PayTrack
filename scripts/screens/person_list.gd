class_name PersonList
extends VBoxContainer
## Search box + filtered list of people. Calls on_pick(person_id).

var on_pick: Callable
var query := ""
var exclude: Array = []
var show_recent := true
var allow_add := false     # offer "Add <name> as new person"
var on_add: Callable       # on_add(name)
var _results: VBoxContainer
var search: LineEdit


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	search = UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill())
	add_child(search)
	if show_recent:
		var recent := _recent_people()
		if not recent.is_empty():
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			for pid in recent:
				var id: String = pid
				flow.add_child(UI.small_button(DB.person(pid).name, "secondary", func(): on_pick.call(id)))
			add_child(UI.label(Lang.t("recent"), UI.S_CAP, UI.TEXT2, 600))
			add_child(flow)
	_results = UI.vbox(0)
	add_child(_results)
	_fill()
	if not DisplayServer.is_touchscreen_available():
		search.grab_focus.call_deferred()


func _recent_people() -> Array:
	var list: Array = DB.data.entries.duplicate()
	list.sort_custom(func(a, b): return a.created > b.created)
	var out := []
	for e in list:
		var pid: String = e.person_id
		var p := DB.person(pid)
		if p.is_empty() or p.get("archived", false) or pid in out or pid in exclude:
			continue
		out.append(pid)
		if out.size() >= 6:
			break
	return out


func _fill() -> void:
	UI.clear(_results)
	var q := query.strip_edges().to_lower()
	var matches := []
	var starts := []
	for p in DB.people_list():
		if p.id in exclude:
			continue
		var n: String = p.name.to_lower()
		if q == "" or n.begins_with(q):
			starts.append(p)
		elif q in n:
			matches.append(p)
	var all: Array = starts + matches
	var c := UI.card()
	var rows := []
	for i in mini(all.size(), 60):
		var p: Dictionary = all[i]
		var id: String = p.id
		var sub := Screens.person_work_summary(id)
		var k := DB.khata_of(id)
		if DB.is_family(k.id) and k.payee_id != id:
			sub = Lang.t("in_family_of", [DB.khata_title(k.id)])
		rows.append(UI.row(p.name, sub, UI.balance_label(DB.live_balance(k.id)), func(): on_pick.call(id), false, UI.avatar(p.name, 36)))
	if allow_add and q != "" and DB.find_person_by_name(query).is_empty():
		var nm := query.strip_edges()
		rows.append(UI.row(Lang.t("add_new_person", [nm]), "", null, func(): on_add.call(nm), false, UI.avatar("+", 36, UI.ACCENT, Color.WHITE)))
	if rows.is_empty():
		var l := UI.wrapped(UI.label(Lang.t("no_match") if q != "" else Lang.t("no_people_yet"), UI.S_SUB, UI.TEXT2))
		UI.card_body(c).add_child(UI.margin(l, 16, 14, 16, 14))
	else:
		UI.add_rows(c, rows)
	_results.add_child(c)
