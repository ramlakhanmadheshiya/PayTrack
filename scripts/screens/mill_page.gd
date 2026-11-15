class_name MillPage
extends Page
## One mill: rates (with history), workers, pay workers here.

var mill_id := ""


func _init() -> void:
	super._init()


func back_label() -> String:
	return Lang.t("tab_mills")


func build(b: VBoxContainer) -> void:
	var m := DB.mill(mill_id)
	if m.is_empty():
		return
	title = m.name
	var today := Dates.today()
	var workers: Array = DB.mill_workers(mill_id)

	if m.get("archived", false):
		b.add_child(UI.margin(UI.pill(Lang.t("hidden"), UI.FILL, UI.TEXT2), 16, 0, 16, 8))

	# Pay button.
	if not workers.is_empty() and not m.get("archived", false):
		b.add_child(UI.margin(UI.button(Lang.t("pay_at_mill", [m.name]), "primary", func(): Screens.start_pay_mill(mill_id), "pay"), 16, 8, 16, 0))

	# Rates.
	b.add_child(UI.section_title(Lang.t("rates"), UI.link(Lang.t("edit"), func(): RateSheet.open_mill(mill_id), UI.ACCENT, UI.S_SUB)))
	var rc := UI.card()
	UI.add_rows(rc, [
		UI.row(Lang.t("rate_f"), Lang.t("per_attendance"), UI.label("₹" + Money.group(DB.mill_rate(mill_id, "F", today)), UI.S_HEAD, UI.TEXT, 600, true), Callable(), false, UI.badge("F")),
		UI.row(Lang.t("rate_h"), Lang.t("per_attendance"), UI.label("₹" + Money.group(DB.mill_rate(mill_id, "H", today)), UI.S_HEAD, UI.TEXT, 600, true), Callable(), false, UI.badge("H")),
	])
	b.add_child(UI.margin(rc, 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("hours_rule")))
	var rates: Array = m.rates
	if rates.size() > 1:
		b.add_child(UI.section_title(Lang.t("rate_history")))
		var hc := UI.card()
		var rows := []
		for i in range(rates.size() - 1, -1, -1):
			var r: Dictionary = rates[i]
			var from: String = r.from
			var when := Lang.t("from_date", [Lang.date_full(from)]) if from > "2000-01-01" else Lang.t("from_start")
			var del: Control = UI.icon_button("trash", func(): UI.app.confirm(Lang.t("delete_rate"), Lang.t("delete_rate_q"), Lang.t("delete"), func(): DB.delete_mill_rate(mill_id, from), true), UI.RED, 18)
			var h := UI.hbox(8)
			h.add_child(UI.label("F ₹%s · H ₹%s" % [Money.group(r.f), Money.group(r.h)], UI.S_SUB, UI.TEXT, 500, true))
			h.add_child(del)
			rows.append(UI.row(when, "", h, Callable(), false))
		UI.add_rows(hc, rows)
		b.add_child(UI.margin(hc, 16, 0, 16, 0))

	# Workers.
	b.add_child(UI.section_title(Lang.t("workers_n", [workers.size()]), UI.link(Lang.t("add"), _add_worker, UI.ACCENT, UI.S_SUB)))
	var wc := UI.card()
	if workers.is_empty():
		UI.card_body(wc).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_workers"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
		UI.card_body(wc).add_child(UI.line())
		UI.card_body(wc).add_child(UI.row(Lang.t("add_worker"), "", null, _add_worker, false, Icons.make("plus", UI.ACCENT, 22)))
	else:
		var rows := []
		for p in workers:
			var id: String = p.id
			var badges := UI.hbox(4)
			for po in DB.sorted_posts(id):
				if po.mill_id == mill_id:
					badges.add_child(UI.badge(po.post))
			var k := DB.khata_of(id)
			var from := DB.next_work_from(k.id)
			var sub := Lang.t("work_from", [Lang.date_smart(from)]) if from != "" else Lang.t("not_paid_yet")
			if DB.is_family(k.id) and k.payee_id != id:
				sub = Lang.t("in_family_of", [DB.khata_title(k.id)])
			var right := UI.hbox(10)
			right.add_child(badges)
			rows.append(UI.row(p.name, sub, right, func(): Screens.open_person(id), true, UI.avatar(p.name, 36)))
		rows.append(UI.row(Lang.t("add_worker"), "", null, _add_worker, false, Icons.make("plus", UI.ACCENT, 22)))
		UI.add_rows(wc, rows)
	b.add_child(UI.margin(wc, 16, 0, 16, 0))

	# Settings.
	b.add_child(UI.section_title(Lang.t("settings")))
	var sc := UI.card()
	var archived: bool = m.get("archived", false)
	UI.add_rows(sc, [
		UI.row(Lang.t("rename_mill"), "", null, func(): MillEditSheet.open(mill_id), true, Icons.make("edit", UI.ACCENT, 20)),
		UI.row(Lang.t("show_mill") if archived else Lang.t("hide_mill"), Lang.t("hide_mill_help") if not archived else "", null, func(): DB.set_mill_archived(mill_id, not archived), false, Icons.make("history", UI.TEXT2, 20)),
	])
	b.add_child(UI.margin(sc, 16, 0, 16, 0))


func _add_worker() -> void:
	AddWorkSheet.open_for_mill(mill_id)
