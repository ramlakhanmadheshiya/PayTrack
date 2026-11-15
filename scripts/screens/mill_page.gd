class_name MillPage
extends Page
## One mill: a one-line rate header, Pay button, and the workers list
## (a family is one row). Everything else is in the ⋯ menu.

var mill_id := ""
var query := ""
var _list: VBoxContainer


func _init() -> void:
	super._init()


func back_label() -> String:
	return Lang.t("tab_mills")


func nav_right() -> Control:
	return UI.icon_button("more", _menu)


func build(b: VBoxContainer) -> void:
	var m := DB.mill(mill_id)
	if m.is_empty():
		return
	title = m.name
	var today := Dates.today()
	# Rates: one compact line.
	var rates := UI.hbox(8)
	rates.add_child(UI.badge("F"))
	rates.add_child(UI.label("₹" + Money.group(DB.mill_rate(mill_id, "F", today)), UI.S_SUB, UI.TEXT, 600, true))
	rates.add_child(UI.spacer(0, 6))
	rates.add_child(UI.badge("H"))
	rates.add_child(UI.label("₹" + Money.group(DB.mill_rate(mill_id, "H", today)), UI.S_SUB, UI.TEXT, 600, true))
	rates.add_child(UI.flex())
	rates.add_child(UI.link(Lang.t("edit"), func(): RateSheet.open_mill(mill_id), UI.ACCENT, UI.S_SUB))
	b.add_child(UI.margin(rates, 16, 0, 12, 6))
	if m.get("archived", false):
		b.add_child(UI.margin(UI.pill(Lang.t("hidden"), UI.FILL, UI.TEXT2), 16, 0, 16, 6))

	var workers: Array = DB.mill_workers(mill_id)
	if not workers.is_empty() and not m.get("archived", false):
		b.add_child(UI.margin(UI.button(Lang.t("pay_at_mill", [m.name]), "primary", func(): Screens.start_pay_mill(mill_id), "pay"), 16, 6, 16, 4))
	if workers.size() > 12:
		b.add_child(UI.margin(UI.search_field(Lang.t("search_name"), query, func(t): query = t; _fill()), 16, 10, 16, 0))
	_list = UI.vbox(0)
	b.add_child(_list)
	_fill()


func _fill() -> void:
	UI.clear(_list)
	var workers: Array = DB.mill_workers(mill_id)
	var q := query.strip_edges().to_lower()
	# One row per khata: a family shows once, with its members at this mill.
	var kids := []
	var members_here := {}
	for p in workers:
		var kid: String = p.khata_id
		if not members_here.has(kid):
			members_here[kid] = []
			kids.append(kid)
		members_here[kid].append(p)
	kids.sort_custom(func(a, c): return DB.khata_title(a).naturalnocasecmp_to(DB.khata_title(c)) < 0)
	# Add worker sits next to the label, so it is reachable without scrolling 200 rows.
	_list.add_child(UI.section_title(Lang.t("workers_n", [workers.size()]), UI.small_button(Lang.t("add_worker"), "tinted", func(): AddWorkerSheet.open(mill_id), "plus")))
	var c := UI.card()
	var rows := []
	for kid in kids:
		var ppl: Array = members_here[kid]
		var family := DB.is_family(kid)
		var names := []
		for p in ppl:
			names.append(p.name)
		if q != "" and not q in " ".join(names).to_lower() and not q in DB.khata_title(kid).to_lower():
			continue
		var badges := UI.hbox(4)
		var posts := []
		for p in ppl:
			for post in DB.posts_at(p.id, mill_id):
				if not post in posts:
					posts.append(post)
		for post in posts:
			badges.add_child(UI.badge(post))
		var from := DB.next_work_from(kid)
		var sub := Lang.t("work_from", [Lang.date_smart(from)]) if from != "" else Lang.t("not_paid_yet")
		if family:
			sub = ", ".join(names) + " · " + sub
			var k2: String = kid
			rows.append(UI.row(DB.family_title(kid), sub, badges, func(): Screens.open_family(k2), true, UI.avatar(DB.khata_title(kid), 36, UI.GREEN_SOFT, UI.GREEN)))
		else:
			var pid: String = ppl[0].id
			rows.append(UI.row(ppl[0].name, sub, badges, func(): Screens.open_person(pid), true, UI.avatar(ppl[0].name, 36)))
	if rows.is_empty():
		rows.append(UI.row(Lang.t("no_workers"), "", null, Callable(), false))
	UI.add_rows(c, rows)
	_list.add_child(UI.margin(c, 16, 0, 16, 0))


func _menu() -> void:
	var m := DB.mill(mill_id)
	var archived: bool = m.get("archived", false)
	UI.app.menu(m.name, [
		[Lang.t("edit_rates"), "edit", func(): RateSheet.open_mill(mill_id)],
		[Lang.t("rename_mill"), "edit", func(): MillEditSheet.open(mill_id)],
		[Lang.t("show_mill") if archived else Lang.t("hide_mill"), "history", func(): DB.set_mill_archived(mill_id, not archived)],
		[Lang.t("delete_mill"), "trash", _delete, true],
	])


func _delete() -> void:
	var m := DB.mill(mill_id)
	var n := DB.mill_workers(mill_id).size()
	var msg := Lang.t("delete_mill_q", [m.name]) if n == 0 else Lang.t("delete_mill_q_workers", [m.name, n])
	UI.app.confirm(Lang.t("delete_mill"), msg, Lang.t("delete_mill"), func():
		var name: String = m.name
		DB.delete_mill(mill_id)
		UI.app.pop()
		UI.app.toast(Lang.t("mill_deleted", [name])), true)
