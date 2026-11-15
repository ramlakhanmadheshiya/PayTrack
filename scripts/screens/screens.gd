class_name Screens
extends RefCounted
## Entry points shared by every screen.


static func root_page(tab: String) -> Page:
	match tab:
		"home":
			return HomePage.new()
		"mills":
			return MillsPage.new()
		"people":
			return PeoplePage.new()
		"balances":
			return BalancesPage.new()
		_:
			return MorePage.new()


static func open_person(pid: String) -> void:
	var p := PersonPage.new()
	p.person_id = pid
	UI.app.push(p)


static func open_family(kid: String) -> void:
	var p := FamilyPage.new()
	p.khata_id = kid
	UI.app.push(p)


static func open_khata(kid: String) -> void:
	## A family opens the family page; a single person opens their own page.
	if DB.is_family(kid):
		open_family(kid)
	else:
		open_person(DB.khata(kid).payee_id)


static func open_mill(mid: String) -> void:
	var p := MillPage.new()
	p.mill_id = mid
	UI.app.push(p)


static func open_payment(pay_id: String) -> void:
	var p := PaymentPage.new()
	p.payment_id = pay_id
	UI.app.push(p)


static func open_entry_sheet(person_id := "", entry_id := "", type := "kharchi") -> void:
	var s := EntrySheet.new()
	s.person_id = person_id
	s.entry_id = entry_id
	s.type = type
	UI.app.present(s)


static func start_pay_someone() -> void:
	if DB.active_khatas().is_empty():
		UI.app.toast(Lang.t("add_people_first"), "error")
		return
	PickPersonSheet.open(Lang.t("pay_someone"), func(pid: String): start_pay_khata(DB.person(pid).khata_id))


static func start_pay_khata(kid: String) -> void:
	var f := PayFlow.new()
	f.khata_ids = [kid]
	f.step = 1
	UI.app.push(f)


static func start_pay_mill(mid: String) -> void:
	var f := PayFlow.new()
	f.mill_id = mid
	f.step = 0
	UI.app.push(f)


static func person_work_summary(pid: String) -> String:
	## "Ganga F·H, Kaveri H"
	var by_mill := {}
	var order := []
	for po in DB.sorted_posts(pid):
		if not by_mill.has(po.mill_id):
			by_mill[po.mill_id] = []
			order.append(po.mill_id)
		by_mill[po.mill_id].append(po.post)
	var parts := []
	for mid in order:
		parts.append("%s %s" % [DB.mill(mid).get("name", "?"), "·".join(by_mill[mid])])
	return ", ".join(parts) if not parts.is_empty() else Lang.t("no_work_yet")


static func khata_row(kid: String, cb: Callable, show_balance := true) -> Control:
	var title := DB.family_title(kid)
	var sub := ""
	if DB.is_family(kid):
		sub = Lang.t("family_with", [DB.khata_subtitle(kid)])
	else:
		sub = person_work_summary(DB.khata(kid).payee_id)
	var right: Control = UI.balance_label(DB.live_balance(kid)) if show_balance else null
	return UI.row(title, sub, right, cb, true, UI.avatar(DB.khata_title(kid), 38))


static func entry_row(e: Dictionary, show_person := true, cb: Callable = Callable()) -> Control:
	var name: String = DB.person(e.person_id).get("name", "?")
	var title: String = name if show_person else Lang.entry_type(e.type)
	var sub := ""
	if show_person:
		sub = Lang.entry_type(e.type)
	else:
		sub = Lang.day_label(e.date)
	if e.note != "" and e.note != "balance_from_member":
		sub += " · " + e.note
	if e.type == "adjust":
		title = Lang.t("balance_carried", [name])
		sub = Lang.day_label(e.date)
	var sign := Calc.entry_effect(e)
	var amt := UI.label(("+" if sign > 0 else "−") + "₹" + Money.group(absi(e.amount)), UI.S_BODY, UI.GREEN if sign > 0 else UI.TEXT, 600, true)
	var dot_col := {"kharchi": UI.ACCENT, "advance": UI.RED, "payout": UI.GREEN, "received": UI.GREEN, "adjust": UI.TEXT3}
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", UI.box(Color(dot_col.get(e.type, UI.TEXT3), 0.12), 18))
	dot.custom_minimum_size = Vector2(36, 36)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cc := CenterContainer.new()
	cc.add_child(Icons.make({"kharchi": "kharchi", "advance": "rupee", "payout": "pay", "received": "import", "adjust": "undo"}.get(e.type, "rupee"), dot_col.get(e.type, UI.TEXT3), 18))
	dot.add_child(cc)
	return UI.row(title, sub, amt, cb, cb.is_valid() and e.payment_id == "", dot)


static func period_text(from: String, upto: String) -> String:
	return Lang.period(from, upto)


static func balance_card(kid: String) -> Control:
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
	var given := 0
	for e in DB.open_entries(kid):
		if Calc.entry_effect(e) < 0:
			given += e.amount
	if given > 0:
		info += "  ·  " + Lang.t("taken_since", [Money.group(given)])
	v.add_child(UI.wrapped(UI.label(info, UI.S_CAP, UI.TEXT2, 500)))
	p.add_child(v)
	return p


static func opening_row(kid: String) -> Control:
	## Starting balance, editable until the first payment.
	if not DB.payments_of(kid).is_empty():
		return null
	var opening: int = int(DB.khata(kid).get("opening", 0))
	var c := UI.card()
	UI.add_rows(c, [UI.row(Lang.t("opening_balance"), Lang.t("opening_help"), UI.balance_label(opening) if opening != 0 else UI.label(Lang.t("none"), UI.S_SUB, UI.TEXT3), func(): OpeningSheet.open(kid), true, Icons.make("balance", UI.ACCENT, 20))])
	return c


static func history(b: VBoxContainer, kid: String) -> void:
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
			var cb := Callable() if e.type == "adjust" else func(): open_entry_sheet("", id)
			rows.append(entry_row(e, DB.is_family(kid), cb))
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


static func correct_payment(pay_id: String) -> void:
	## Undo a saved payment and open it again with the same numbers to fix it.
	var pay := DB.payment(pay_id)
	if pay.is_empty():
		return
	if not DB.can_undo_payment(pay_id):
		UI.app.toast(Lang.t("only_latest_payment"), "error")
		return
	UI.app.confirm(Lang.t("correct_payment"), Lang.t("correct_payment_q", [pay.payee_name]), Lang.t("correct_payment"), func():
		var original := DB.draft_from_payment(pay)
		DB.undo_payment(pay_id)
		var d := DB.draft_from_payment(pay)
		var f := PayFlow.new()
		f.khata_ids = [pay.khata_id]
		f.pay_date = pay.date
		f.drafts = [d]
		f.correcting = [original]
		f.step = 1
		UI.app.push(f))
