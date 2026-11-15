class_name ActivityPage
extends Page
## Everything done in PayTrack, newest first: mills, people, groups, salary
## sheets, kharchi, advance, jama, payments.

var shown := 150


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("activity")
	var list: Array = DB.log_list()
	if list.is_empty():
		b.add_child(UI.empty_state("history", Lang.t("activity"), Lang.t("no_activity")))
		return
	var n := mini(shown, list.size())
	var i := 0
	while i < n:
		var d: String = list[i].get("d", "")
		var rows := []
		while i < n and list[i].get("d", "") == d:
			rows.append(_row(list[i]))
			i += 1
		b.add_child(UI.section_title(Lang.day_label(d) if d != "" else ""))
		var c := UI.card()
		UI.add_rows(c, rows)
		b.add_child(UI.margin(c, 16, 0, 16, 0))
	if list.size() > shown:
		b.add_child(UI.margin(UI.button(Lang.t("show_more"), "secondary", func(): shown += 150; refresh()), 16, 14, 16, 0))


static func text_of(l: Dictionary) -> String:
	var k: String = l.get("k", "")
	var a: Array = l.get("a", []).duplicate()
	for j in a.size():
		if a[j] is float:
			a[j] = Money.group(int(a[j]))
		elif a[j] is int:
			a[j] = Money.group(a[j])
	match k:
		"entry_added":
			var ty: String = l.get("ty", "")
			if ty == "received":
				return Lang.t("log_entry_added_in", [Lang.entry_type(ty), a[1], a[0]])
			return Lang.t("log_entry_added", [Lang.entry_type(ty), a[1], a[0]])
		"entry_edited", "entry_deleted":
			return Lang.t("log_" + k, [Lang.entry_type(l.get("ty", "")), a[1], a[0]])
		"sheet_repeated":
			return Lang.t("log_sheet_repeated", [Lang.month_ym(String(a[0])), Lang.month_ym(String(a[1]))])
		"sheet_added", "sheet_deleted":
			return Lang.t("log_" + k, [Lang.month_ym(String(a[0]))])
		"sheet_mill_added", "sheet_mill_removed", "sheet_worker_added", "sheet_worker_removed":
			a[0] = Lang.month_ym(String(a[0]))
	var key := "log_" + k
	var tmpl := Lang.t(key)
	if tmpl == key:
		return k
	var need := tmpl.count("%s")
	while a.size() < need:
		a.append("")
	return tmpl % a.slice(0, need) if need > 0 else tmpl


func _row(l: Dictionary) -> Control:
	var t := Time.get_datetime_dict_from_unix_time(int(l.get("t", 0)) + _tz_offset())
	var time := "%02d:%02d" % [t.hour, t.minute]
	var k: String = l.get("k", "")
	var icon := "history"
	if k.begins_with("entry"):
		icon = "kharchi"
	elif k.begins_with("payment"):
		icon = "pay"
	elif k.begins_with("mill"):
		icon = "mill"
	elif k.begins_with("sheet"):
		icon = "doc"
	elif k.begins_with("group"):
		icon = "family"
	elif k.begins_with("person") or k.begins_with("work") or k.begins_with("salary") or k.begins_with("opening"):
		icon = "person"
	var h := UI.hbox(12)
	h.add_child(Icons.make(icon, UI.ACCENT, 20))
	var txt := UI.wrapped(UI.label(text_of(l), UI.S_SUB, UI.TEXT, 500))
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(txt)
	h.add_child(UI.label(time, UI.S_CAP, UI.TEXT3, 500, true))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.pad(StyleBoxEmpty.new(), 16, 10))
	p.custom_minimum_size.y = 48
	p.add_child(h)
	return p


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
