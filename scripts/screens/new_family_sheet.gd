class_name NewFamilySheet
extends Sheet
## Make a family: choose who receives the pay, then tick the members.

var head_id := ""
var members: Array = []
var query := ""
var _list: VBoxContainer


static func open() -> void:
	var s := NewFamilySheet.new(Lang.t("new_family"), Lang.t("save"))
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	if head_id == "":
		set_action_enabled(false)
		body.add_child(UI.wrapped(UI.label(Lang.t("family_pick_head"), UI.S_SUB, UI.TEXT2)))
		var l := PersonList.new()
		l.show_recent = false
		l.exclude = _in_families()
		l.on_pick = func(pid):
			head_id = pid
			build()
		body.add_child(l)
		return
	set_action_enabled(not members.is_empty())
	var hc := UI.card()
	var hn: String = DB.person(head_id).name
	UI.add_rows(hc, [UI.row(hn, Lang.t("payee"), Lang.t("change"), func(): head_id = ""; members.clear(); build(), false, UI.avatar(hn, 38, UI.ACCENT_SOFT, UI.ACCENT))])
	body.add_child(hc)
	body.add_child(UI.label(Lang.t("family_pick_members"), UI.S_CAP, UI.TEXT2, 600))
	body.add_child(UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill()))
	_list = UI.vbox(0)
	body.add_child(_list)
	_fill()


func _in_families() -> Array:
	var out := []
	for p in DB.people_list(true):
		if DB.is_family(DB.khata_of(p.id).id):
			out.append(p.id)
	return out


func _fill() -> void:
	UI.clear(_list)
	var skip := _in_families()
	var q := query.strip_edges().to_lower()
	var c := UI.card()
	var rows := []
	for p in DB.people_list():
		if p.id == head_id or p.id in skip:
			continue
		if q != "" and not q in p.name.to_lower() and not p.id in members:
			continue
		var on: bool = p.id in members
		var pid: String = p.id
		rows.append(UI.row(p.name, Screens.person_work_summary(pid), null, func():
			if pid in members:
				members.erase(pid)
			else:
				members.append(pid)
			set_action_enabled(not members.is_empty())
			_fill(), false, Icons.make("check_circle" if on else "circle", UI.ACCENT if on else UI.TEXT3, 26)))
		if rows.size() >= 80:
			break
	if rows.is_empty():
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_match"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
	else:
		UI.add_rows(c, rows)
	_list.add_child(c)


func _save() -> void:
	UI.app.numpad_close()
	if head_id == "" or members.is_empty():
		return
	for m in members:
		DB.join_family(head_id, m)
	var kid: String = DB.person(head_id).khata_id
	close()
	UI.app.toast(Lang.t("family_made", [DB.person(head_id).name]))
	Screens.open_family(kid)
