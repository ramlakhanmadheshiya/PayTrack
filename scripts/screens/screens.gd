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
	var title := DB.khata_title(kid)
	var sub := ""
	if DB.is_family(kid):
		sub = Lang.t("family_with", [DB.khata_subtitle(kid)])
	else:
		sub = person_work_summary(DB.khata(kid).payee_id)
	var right: Control = UI.balance_label(DB.live_balance(kid)) if show_balance else null
	return UI.row(title, sub, right, cb, true, UI.avatar(title, 38))


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
