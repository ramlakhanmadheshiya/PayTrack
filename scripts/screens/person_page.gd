class_name PersonPage
extends Page
## One person: balance and history. Work is added from a salary sheet
## (Salary › month › mill › Add worker) or on the payment page (Add work).
## Rename, salary, family and hide/delete live in the ⋯ menu.

var person_id := ""


func _init() -> void:
	super._init()


func nav_right() -> Control:
	return UI.icon_button("more", _menu)


func build(b: VBoxContainer) -> void:
	var p := DB.person(person_id)
	if p.is_empty():
		return
	title = p.name
	var k := DB.khata_of(person_id)
	var kid: String = k.id
	var family := DB.is_family(kid)

	if p.get("archived", false):
		b.add_child(UI.margin(UI.pill(Lang.t("hidden"), UI.FILL, UI.TEXT2), 16, 0, 16, 8))

	if family:
		# Money belongs to the family khata: show it as one tappable card.
		var fc := UI.card()
		var sub := Lang.t("family_receives", [DB.khata_title(kid)]) + " · " + UI.balance_text(DB.balance(kid))
		UI.add_rows(fc, [UI.row(DB.family_title(kid), sub, null, func(): Screens.open_family(kid), true, UI.avatar(DB.khata_title(kid), 38, UI.GREEN_SOFT, UI.GREEN))])
		b.add_child(UI.margin(fc, 16, 4, 16, 0))
	else:
		b.add_child(UI.margin(Screens.balance_card(kid), 16, 4, 16, 0))
		var op := Screens.opening_row(kid)
		if op:
			b.add_child(UI.margin(op, 16, 10, 16, 0))

	var acts := UI.hbox(10)
	acts.add_child(UI.expand(UI.button(Lang.t("add_kharchi"), "tinted", func(): Screens.open_entry_sheet(person_id), "plus")))
	acts.add_child(UI.expand(UI.button(Lang.t("pay_family") if family else Lang.t("pay"), "primary", func(): Screens.start_pay_khata(kid), "pay")))
	b.add_child(UI.margin(acts, 16, 12, 16, 0))

	if not family:
		Screens.history(b, kid)
	else:
		# Only this person's own open kharchi; the full history is on the family page.
		var mine := []
		for e in DB.open_entries(kid):
			if e.person_id == person_id and e.type != "adjust":
				mine.append(e)
		if not mine.is_empty():
			b.add_child(UI.section_title(Lang.t("since_last_payment")))
			var oc := UI.card()
			var r2 := []
			for i in range(mine.size() - 1, -1, -1):
				var id: String = mine[i].id
				r2.append(Screens.entry_row(mine[i], false, func(): Screens.open_entry_sheet("", id)))
			UI.add_rows(oc, r2)
			b.add_child(UI.margin(oc, 16, 0, 16, 0))


func _menu() -> void:
	var p := DB.person(person_id)
	var k := DB.khata_of(person_id)
	var items := [[Lang.t("rename") + " · " + Lang.t("hindi_name"), "edit", _rename]]
	if DB.is_master(person_id) or not p.get("salaries", []).is_empty():
		items.append([Lang.t("edit_salary") + " (₹" + Money.group(DB.salary_on(person_id, Dates.today())) + ")", "rupee", func(): RateSheet.open_salary(person_id)])
	if DB.is_family(k.id):
		if k.payee_id != person_id:
			items.append([Lang.t("leave_family"), "close", _leave])
	else:
		items.append([Lang.t("join_family"), "family", _join])
	var archived: bool = p.get("archived", false)
	items.append([Lang.t("show_person") if archived else Lang.t("hide_person"), "history", func(): _toggle_archive(archived)])
	if DB.can_delete_person(person_id) and Sync.is_admin():
		items.append([Lang.t("delete_person"), "trash", _delete, true])
	UI.app.menu(p.name, items)


func _join() -> void:
	PickPersonSheet.open(Lang.t("join_family_pick"), func(head_pid: String):
		var head := DB.person(DB.khata_of(head_pid).payee_id)
		UI.app.confirm(Lang.t("join_family"), Lang.t("join_confirm", [DB.person(person_id).name, head.name]), Lang.t("add_to_family"), func():
			var err := DB.join_family(head.id, person_id)
			UI.app.toast(Lang.t(err) if err != "" else Lang.t("joined_family", [DB.person(person_id).name]), "error" if err != "" else "ok")), [person_id])


func _leave() -> void:
	UI.app.confirm(Lang.t("leave_family"), Lang.t("leave_confirm"), Lang.t("leave_family"), func():
		var err := DB.leave_family(person_id)
		if err != "":
			UI.app.toast(Lang.t(err), "error"), true)


func _rename() -> void:
	RenameSheet.open(person_id)


func _toggle_archive(archived: bool) -> void:
	if archived:
		DB.set_person_archived(person_id, false)
		return
	var bal := DB.balance(DB.khata_of(person_id).id)
	var msg := Lang.t("hide_person_q") if bal == 0 else Lang.t("hide_person_q_balance", [UI.balance_text(bal)])
	UI.app.confirm(Lang.t("hide_person"), msg, Lang.t("hide"), func(): DB.set_person_archived(person_id, true))


func _delete() -> void:
	var name: String = DB.person(person_id).name
	UI.app.confirm(Lang.t("delete_person"), Lang.t("delete_person_q", [name]), Lang.t("delete"), func():
		if DB.delete_person(person_id):
			UI.app.pop()
			UI.app.toast(Lang.t("deleted")), true)
