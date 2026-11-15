class_name SheetMillPage
extends Page
## One mill inside one month's salary sheet. Starts with no workers; add the
## people who worked here this month. The list stays in the order added.

var sheet_id := ""
var mill_id := ""
var query := ""
var _list: VBoxContainer


func _init() -> void:
	super._init()


func back_label() -> String:
	return Lang.month_ym(DB.sheet(sheet_id).get("ym", ""))


func nav_right() -> Control:
	return UI.icon_button("more", _menu)


func build(b: VBoxContainer) -> void:
	var m := DB.mill(mill_id)
	var sh := DB.sheet(sheet_id)
	if m.is_empty() or sh.is_empty() or not mill_id in DB.sheet_mill_ids(sheet_id):
		return
	title = m.name
	var day := Dates.last_of_month(sh.ym + "-01")
	var rates := UI.hbox(8)
	rates.add_child(UI.label(Lang.month_ym(sh.ym), UI.S_SUB, UI.TEXT2, 600))
	rates.add_child(UI.flex())
	rates.add_child(UI.badge("F"))
	rates.add_child(UI.label("₹" + Money.group(DB.mill_rate(mill_id, "F", day)), UI.S_SUB, UI.TEXT, 600, true))
	rates.add_child(UI.spacer(0, 6))
	rates.add_child(UI.badge("H"))
	rates.add_child(UI.label("₹" + Money.group(DB.mill_rate(mill_id, "H", day)), UI.S_SUB, UI.TEXT, 600, true))
	b.add_child(UI.margin(rates, 16, 0, 16, 4))
	if DB.sheet_workers(sheet_id, mill_id).size() > 12:
		b.add_child(UI.margin(UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill()), 16, 10, 16, 0))
	_list = UI.vbox(0)
	b.add_child(_list)
	_fill()


func _fill() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	UI.clear(_list)
	var workers: Array = DB.sheet_workers(sheet_id, mill_id)
	var q := query.strip_edges().to_lower()
	_list.add_child(UI.section_title(Lang.t("workers_n", [workers.size()]), UI.small_button(Lang.t("add_worker"), "tinted", func(): add_worker(sheet_id, mill_id), "plus")))
	var c := UI.card()
	var rows := []
	var n := 0
	for w in workers:
		n += 1
		var p := DB.person(w.person_id)
		if q != "" and not q in String(p.name).to_lower():
			continue
		var pid: String = w.person_id
		var badges := UI.hbox(4)
		for post in w.posts:
			badges.add_child(UI.badge(post))
		var kid: String = p.khata_id
		var sub := Lang.t("in_family_of", [DB.khata_title(kid)]) if DB.is_family(kid) else UI.balance_text(DB.balance(kid))
		var num := UI.label(str(n), UI.S_CAP, UI.TEXT3, 600, true)
		num.custom_minimum_size.x = 22
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var lead := UI.hbox(8)
		lead.add_child(num)
		lead.add_child(UI.avatar(p.name, 36))
		rows.append(UI.row(p.name, sub, badges, func(): _worker_menu(pid), true, lead))
	if rows.is_empty():
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_match") if q != "" else Lang.t("no_workers"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
	else:
		UI.add_rows(c, rows)
	_list.add_child(UI.margin(c, 16, 0, 16, 0))


static func add_worker(sid: String, mid: String) -> void:
	## Choose someone already in PayTrack or type a new name, then their work.
	var s := Sheet.new(Lang.t("add_worker"))
	UI.app.present(s)
	s.body.add_theme_constant_override("separation", 10)
	s.body.add_child(UI.wrapped(UI.label(Lang.t("pick_or_new", [DB.mill(mid).name]), UI.S_SUB, UI.TEXT2)))
	var exclude := []
	for w in DB.sheet_workers(sid, mid):
		exclude.append(w.person_id)
	var l := PersonList.new()
	l.exclude = exclude
	l.allow_add = true
	l.show_recent = false
	l.on_pick = func(pid):
		s.close()
		SheetWorkSheet.open(sid, mid, pid)
	l.on_add = func(nm: String):
		var p := DB.add_person(nm)
		s.close()
		SheetWorkSheet.open(sid, mid, p.id)
	s.body.add_child(l)
	l.open_keyboard.call_deferred()


func _worker_menu(pid: String) -> void:
	var p := DB.person(pid)
	UI.app.menu(p.name, [
		[Lang.t("open_person_page"), "person", func(): Screens.open_khata(p.khata_id)],
		[Lang.t("change_work"), "edit", func(): SheetWorkSheet.open(sheet_id, mill_id, pid)],
		[Lang.t("remove_from_list"), "close", func(): DB.sheet_set_worker(sheet_id, mill_id, pid, []), true],
	])


func _menu() -> void:
	var m := DB.mill(mill_id)
	var sh := DB.sheet(sheet_id)
	UI.app.menu(m.name, [
		[Lang.t("add_worker"), "plus", func(): add_worker(sheet_id, mill_id)],
		[Lang.t("remove_from_sheet"), "trash", func():
			UI.app.confirm(Lang.t("remove_from_sheet"), Lang.t("remove_mill_sheet_q", [m.name, Lang.month_ym(sh.ym)]), Lang.t("remove"), func():
				DB.sheet_remove_mill(sheet_id, mill_id)
				UI.app.pop(), true), true],
	])
