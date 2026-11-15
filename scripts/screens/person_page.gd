class_name PersonPage
extends Page
## A person and their khata: balance, work, salary, family, full history.

var person_id := ""


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	var p := DB.person(person_id)
	if p.is_empty():
		return
	title = p.name
	var k := DB.khata_of(person_id)
	var kid: String = k.id
	var is_payee: bool = k.payee_id == person_id
	var family := DB.is_family(kid)

	if p.get("archived", false):
		b.add_child(UI.margin(UI.pill(Lang.t("hidden"), UI.FILL, UI.TEXT2), 16, 0, 16, 8))
	if family:
		var who := Lang.t("family_head_of", [DB.khata_subtitle(kid)]) if is_payee else Lang.t("in_family_of", [DB.khata_title(kid)])
		b.add_child(UI.margin(UI.wrapped(UI.label(who, UI.S_SUB, UI.TEXT2, 500)), 16, 0, 16, 10))

	# Balance hero.
	b.add_child(UI.margin(_balance_card(kid), 16, 4, 16, 0))

	# Actions.
	var acts := UI.hbox(10)
	acts.add_child(UI.expand(UI.button(Lang.t("add_kharchi"), "tinted", func(): Screens.open_entry_sheet(person_id), "plus")))
	acts.add_child(UI.expand(UI.button(Lang.t("pay"), "primary", func(): Screens.start_pay_khata(kid), "pay")))
	b.add_child(UI.margin(acts, 16, 12, 16, 0))

	# Work.
	b.add_child(UI.section_title(Lang.t("work"), UI.link(Lang.t("add"), func(): AddWorkSheet.open_for_person(person_id), UI.ACCENT, UI.S_SUB)))
	var wc := UI.card()
	var wrows := []
	var today := Dates.today()
	for po in DB.sorted_posts(person_id):
		var mid: String = po.mill_id
		var post: String = po.post
		var rate := ""
		if post == "BM":
			rate = Lang.t("per_month", [Money.group(DB.salary_on(person_id, today))])
		else:
			rate = Lang.t("per_att", [Money.group(DB.mill_rate(mid, post, today))])
		wrows.append(UI.row(DB.mill(mid).get("name", "?"), Lang.post_name(post) + " · " + rate, null, func(): _work_options(mid, post), false, UI.badge(post)))
	if wrows.is_empty():
		wrows.append(UI.row(Lang.t("add_work"), Lang.t("add_work_help"), null, func(): AddWorkSheet.open_for_person(person_id), false, Icons.make("plus", UI.ACCENT, 22)))
	UI.add_rows(wc, wrows)
	b.add_child(UI.margin(wc, 16, 0, 16, 0))

	# Salary (masters).
	var sal: Array = p.get("salaries", [])
	if DB.is_master(person_id) or not sal.is_empty():
		b.add_child(UI.section_title(Lang.t("salary"), UI.link(Lang.t("edit"), func(): RateSheet.open_salary(person_id), UI.ACCENT, UI.S_SUB)))
		var sc := UI.card()
		var srows := []
		for i in range(sal.size() - 1, -1, -1):
			var s: Dictionary = sal[i]
			var from: String = s.from
			var when := Lang.t("from_date", [Lang.date_full(from)]) if from > "2000-01-01" else Lang.t("from_start")
			var right := UI.hbox(8)
			right.add_child(UI.label("₹" + Money.group(s.amount), UI.S_BODY, UI.TEXT, 600, true))
			if sal.size() > 1:
				right.add_child(UI.icon_button("trash", func(): UI.app.confirm(Lang.t("delete_salary"), Lang.t("delete_rate_q"), Lang.t("delete"), func(): DB.delete_salary(person_id, from), true), UI.RED, 18))
			srows.append(UI.row(Lang.t("monthly_salary"), when, right, Callable(), false))
		UI.add_rows(sc, srows)
		b.add_child(UI.margin(sc, 16, 0, 16, 0))
		b.add_child(UI.footnote(Lang.t("master_rule")))

	# Family.
	b.add_child(UI.section_title(Lang.t("family")))
	var fc := UI.card()
	var frows := []
	if family:
		for m in DB.khata_members(kid):
			var mid2: String = m.id
			var sub := Lang.t("payee") if m.id == k.payee_id else Lang.t("member")
			var cb := Callable()
			if mid2 != person_id:
				cb = func(): Screens.open_person(mid2)
			frows.append(UI.row(m.name, sub, null, cb, cb.is_valid(), UI.avatar(m.name, 34, UI.ACCENT_SOFT if m.id == k.payee_id else UI.FILL, UI.ACCENT if m.id == k.payee_id else UI.TEXT2)))
		if is_payee:
			frows.append(UI.row(Lang.t("add_family_member"), "", null, func(): _add_member(), false, Icons.make("plus", UI.ACCENT, 22)))
		else:
			frows.append(UI.row(Lang.t("make_payee"), Lang.t("make_payee_help"), null, func(): DB.set_payee(kid, person_id); UI.app.toast(Lang.t("saved")), false, Icons.make("person", UI.ACCENT, 20)))
			frows.append(UI.row(Lang.t("leave_family"), Lang.t("leave_family_help"), null, func(): _leave(), false, Icons.make("close", UI.RED, 20)))
	else:
		frows.append(UI.row(Lang.t("add_family_member"), Lang.t("add_family_help", [p.name]), null, func(): _add_member(), false, Icons.make("family", UI.ACCENT, 22)))
		frows.append(UI.row(Lang.t("join_family"), Lang.t("join_family_help"), null, func(): _join(), false, Icons.make("people", UI.ACCENT, 22)))
	UI.add_rows(fc, frows)
	b.add_child(UI.margin(fc, 16, 0, 16, 0))

	# History.
	_history(b, kid)

	# Settings.
	b.add_child(UI.section_title(Lang.t("settings")))
	var stc := UI.card()
	var srows2 := [UI.row(Lang.t("rename"), "", null, func(): _rename(), true, Icons.make("edit", UI.ACCENT, 20))]
	if is_payee and DB.payments_of(kid).is_empty():
		var opening: int = int(k.get("opening", 0))
		srows2.append(UI.row(Lang.t("opening_balance"), Lang.t("opening_help"), UI.balance_label(opening), func(): _opening(kid), true, Icons.make("balance", UI.ACCENT, 20)))
		var start: String = k.get("start", "")
		srows2.append(UI.row(Lang.t("work_counted_from"), Lang.t("work_counted_help"), Lang.date_full(start) if start != "" else Lang.t("not_set"), func():
			DateSheet.open(Lang.t("work_counted_from"), start if start != "" else Dates.first_of_previous_month(Dates.today()), func(d): DB.set_khata_start(kid, d)), true, Icons.make("calendar", UI.ACCENT, 20)))
	var archived: bool = p.get("archived", false)
	srows2.append(UI.row(Lang.t("show_person") if archived else Lang.t("hide_person"), "" if archived else Lang.t("hide_person_help"), null, func(): _toggle_archive(archived), false, Icons.make("history", UI.TEXT2, 20)))
	UI.add_rows(stc, srows2)
	b.add_child(UI.margin(stc, 16, 0, 16, 0))


func _balance_card(kid: String) -> Control:
	var bal := DB.live_balance(kid)
	var col := UI.GREEN if bal > 0 else (UI.RED if bal < 0 else UI.TEXT2)
	var soft := UI.GREEN_SOFT if bal > 0 else (UI.RED_SOFT if bal < 0 else UI.CARD)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.pad(UI.box(soft, 18), 18, 16))
	var v := UI.vbox(2)
	var cap := Lang.t("bal_jama") if bal > 0 else (Lang.t("bal_advance") if bal < 0 else Lang.t("bal_clear"))
	v.add_child(UI.label(cap, UI.S_SUB, col, 600))
	v.add_child(UI.label(Money.rs(absi(bal)), UI.S_MONEY_BIG, col if bal != 0 else UI.TEXT, 700, true))
	var upto: String = DB.khata(kid).get("paid_upto", "")
	var info := Lang.t("work_paid_upto", [Lang.date_full(upto)]) if upto != "" else Lang.t("not_paid_yet")
	var open := DB.open_entries(kid)
	var given := 0
	for e in open:
		if Calc.entry_effect(e) < 0:
			given += e.amount
	if given > 0:
		info += "  ·  " + Lang.t("taken_since", [Money.group(given)])
	v.add_child(UI.wrapped(UI.label(info, UI.S_CAP, UI.TEXT2, 500)))
	p.add_child(v)
	return p


func _history(b: VBoxContainer, kid: String) -> void:
	var open := DB.open_entries(kid)
	var pays: Array = DB.payments_of(kid)
	b.add_child(UI.section_title(Lang.t("history")))
	if open.is_empty() and pays.is_empty():
		var c := UI.card()
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_history"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
		b.add_child(UI.margin(c, 16, 0, 16, 0))
		return
	if not open.is_empty():
		b.add_child(UI.margin(UI.label(Lang.t("since_last_payment"), UI.S_CAP, UI.TEXT2, 600), 20, 0, 16, 6))
		var oc := UI.card()
		var rows := []
		for i in range(open.size() - 1, -1, -1):
			var e: Dictionary = open[i]
			var id: String = e.id
			var cb := Callable() if e.type == "adjust" else func(): Screens.open_entry_sheet("", id)
			rows.append(Screens.entry_row(e, DB.is_family(kid), cb))
		UI.add_rows(oc, rows)
		b.add_child(UI.margin(oc, 16, 0, 16, 12))
	if not pays.is_empty():
		b.add_child(UI.margin(UI.label(Lang.t("payments"), UI.S_CAP, UI.TEXT2, 600), 20, 0, 16, 6))
		var pc := UI.card()
		var rows2 := []
		for i in range(pays.size() - 1, -1, -1):
			rows2.append(PaymentsPage.payment_row(pays[i], false))
		UI.add_rows(pc, rows2)
		b.add_child(UI.margin(pc, 16, 0, 16, 0))


func _work_options(mid: String, post: String) -> void:
	var s := Sheet.new("%s · %s" % [DB.mill(mid).get("name", ""), Lang.post_name(post)])
	UI.app.present(s)
	var v := UI.vbox(10)
	v.add_child(UI.button(Lang.t("open_mill"), "secondary", func(): s.close(); Screens.open_mill(mid), "mill"))
	if post == "BM":
		v.add_child(UI.button(Lang.t("edit_salary"), "secondary", func(): s.close(); RateSheet.open_salary(person_id), "edit"))
	v.add_child(UI.button(Lang.t("remove_work"), "danger", func():
		s.close()
		UI.app.confirm(Lang.t("remove_work"), Lang.t("remove_work_q"), Lang.t("remove"), func(): DB.remove_post(person_id, mid, post), true), "trash"))
	v.add_child(UI.wrapped(UI.label(Lang.t("remove_work_help"), UI.S_CAP, UI.TEXT2)))
	s.body.add_child(v)


func _add_member() -> void:
	var exclude := [person_id]
	for p in DB.people_list(true):
		if DB.is_family(DB.khata_of(p.id).id):
			exclude.append(p.id)
	PickPersonSheet.open(Lang.t("add_family_member"), func(mid: String):
		var name: String = DB.person(mid).name
		UI.app.confirm(Lang.t("add_family_member"), Lang.t("join_confirm", [name, DB.person(person_id).name]), Lang.t("add_to_family"), func():
			var err := DB.join_family(person_id, mid)
			UI.app.toast(Lang.t(err) if err != "" else Lang.t("joined_family", [name]), "error" if err != "" else "ok")), exclude)


func _join() -> void:
	PickPersonSheet.open(Lang.t("join_family"), func(payee: String):
		var target := DB.person(DB.khata_of(payee).payee_id)
		UI.app.confirm(Lang.t("join_family"), Lang.t("join_confirm", [DB.person(person_id).name, target.name]), Lang.t("add_to_family"), func():
			var err := DB.join_family(target.id, person_id)
			UI.app.toast(Lang.t(err) if err != "" else Lang.t("joined_family", [DB.person(person_id).name]), "error" if err != "" else "ok")), [person_id])


func _leave() -> void:
	UI.app.confirm(Lang.t("leave_family"), Lang.t("leave_confirm"), Lang.t("leave_family"), func():
		var err := DB.leave_family(person_id)
		if err != "":
			UI.app.toast(Lang.t(err), "error"), true)


func _rename() -> void:
	var s := Sheet.new(Lang.t("rename"), Lang.t("save"))
	var box := UI.text_field(Lang.t("name_ph"), DB.person(person_id).name)
	var err := UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	s.action_cb = func():
		var n := box.text.strip_edges()
		if n == "":
			err.text = Lang.t("err_name_empty")
			return
		if DB.person_name_taken(n, person_id):
			err.text = Lang.t("err_person_exists", [n])
			return
		DB.rename_person(person_id, n)
		s.close()
	UI.app.present(s)
	s.body.add_theme_constant_override("separation", 10)
	s.body.add_child(box)
	s.body.add_child(err)
	box.grab_focus.call_deferred()


func _opening(kid: String) -> void:
	var cur: int = int(DB.khata(kid).get("opening", 0))
	var state := {"kind": 1 if cur > 0 else (2 if cur < 0 else 0), "amount": float(absi(cur))}
	var s := Sheet.new(Lang.t("opening_balance"), Lang.t("save"))
	s.action_cb = func():
		UI.app.numpad_close()
		var amt := int(state.amount)
		DB.set_opening_balance(kid, 0 if state.kind == 0 else (amt if state.kind == 1 else -amt))
		s.close()
	UI.app.present(s)
	var holder := UI.vbox(12)
	s.body.add_child(holder)
	var draw := func(self_ref: Callable) -> void:
		UI.clear(holder)
		holder.add_child(UI.wrapped(UI.label(Lang.t("opening_help_long"), UI.S_SUB, UI.TEXT2)))
		holder.add_child(UI.segmented([Lang.t("none"), Lang.t("has_jama"), Lang.t("has_advance")], state.kind, func(i): state.kind = i; self_ref.call(self_ref)))
		if state.kind > 0:
			var c := UI.card()
			var f := NumField.make(state.amount, Lang.t("opening_balance"), false, true, 130)
			f.value_changed.connect(func(v): state.amount = v)
			UI.add_rows(c, [UI.row(Lang.t("amount"), "", f, Callable(), false)])
			holder.add_child(c)
	draw.call(draw)


func _toggle_archive(archived: bool) -> void:
	if archived:
		DB.set_person_archived(person_id, false)
		return
	var bal := DB.live_balance(DB.khata_of(person_id).id)
	var msg := Lang.t("hide_person_q") if bal == 0 else Lang.t("hide_person_q_balance", [UI.balance_text(bal)])
	UI.app.confirm(Lang.t("hide_person"), msg, Lang.t("hide"), func(): DB.set_person_archived(person_id, true))
