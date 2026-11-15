class_name AddMillsSheet
extends Sheet
## Tick the mills for a month's sheet (several at once). Hidden mills are not offered.

var sheet_id := ""
var picked: Array = []


static func open(sid: String) -> void:
	var s := AddMillsSheet.new(Lang.t("add_mills"))
	s.sheet_id = sid
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	UI.clear(footer)
	body.add_theme_constant_override("separation", 10)
	var have: Array = DB.sheet_mill_ids(sheet_id)
	var avail := []
	for m in DB.mills_list():
		if not m.id in have:
			avail.append(m)
	if DB.mills_list().is_empty():
		body.add_child(UI.wrapped(UI.label(Lang.t("no_mills_body"), UI.S_SUB, UI.TEXT2)))
		body.add_child(UI.button(Lang.t("add_mill"), "primary", func(): close(); MillEditSheet.open(""), "plus"))
		return
	if avail.is_empty():
		body.add_child(UI.wrapped(UI.label(Lang.t("all_mills_added"), UI.S_SUB, UI.TEXT2)))
		return
	body.add_child(UI.wrapped(UI.label(Lang.t("add_mills_help"), UI.S_SUB, UI.TEXT2)))
	var c := UI.card()
	var rows := []
	for m in avail:
		var id: String = m.id
		var on: bool = id in picked
		var mark := Icons.make("check" if on else "circle", UI.ACCENT if on else UI.TEXT3, 22)
		rows.append(UI.row(m.name, "", mark, func():
			if id in picked:
				picked.erase(id)
			else:
				picked.append(id)
			build(), false, Icons.make("mill", UI.ACCENT, 22)))
	UI.add_rows(c, rows)
	body.add_child(c)
	var btn := UI.button(Lang.t("add_n_mills", [picked.size()]), "primary", _save, "plus")
	btn.enabled = not picked.is_empty()
	footer.add_child(UI.margin(btn, 16, 10, 16, 10))


func _save() -> void:
	if picked.is_empty():
		return
	DB.sheet_add_mills(sheet_id, picked)
	close()
	UI.app.toast(Lang.t("saved"))
