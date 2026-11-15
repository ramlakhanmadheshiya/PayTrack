class_name FamilyPage
extends Page
## A family khata: one balance, the members, paid together to the head.

var khata_id := ""


func _init() -> void:
	super._init()


func nav_right() -> Control:
	return UI.icon_button("more", _menu)


func build(b: VBoxContainer) -> void:
	var k := DB.khata(khata_id)
	if k.is_empty():
		return
	if not DB.is_family(khata_id):
		# Became a single person again (members left): show that person instead.
		title = DB.khata_title(khata_id)
	else:
		title = DB.family_title(khata_id)
	b.add_child(UI.margin(Screens.balance_card(khata_id), 16, 4, 16, 0))
	var op := Screens.opening_row(khata_id)
	if op:
		b.add_child(UI.margin(op, 16, 10, 16, 0))
	var acts := UI.hbox(10)
	acts.add_child(UI.expand(UI.button(Lang.t("add_kharchi"), "tinted", _kharchi, "plus")))
	acts.add_child(UI.expand(UI.button(Lang.t("pay_family"), "primary", func(): Screens.start_pay_khata(khata_id), "pay")))
	b.add_child(UI.margin(acts, 16, 12, 16, 0))

	b.add_child(UI.section_title(Lang.t("members_n", [DB.khata_members(khata_id).size()])))
	var c := UI.card()
	var rows := []
	for p in DB.khata_members(khata_id):
		var pid: String = p.id
		var head: bool = p.id == k.payee_id
		var sub := (Lang.t("payee") + " · " if head else "") + Screens.person_work_summary(pid)
		rows.append(UI.row(p.name, sub, null, func(): Screens.open_person(pid), true, UI.avatar(p.name, 36, UI.ACCENT_SOFT if head else UI.FILL, UI.ACCENT if head else UI.TEXT2)))
	rows.append(UI.row(Lang.t("add_family_member"), "", null, _add_member, false, Icons.make("plus", UI.ACCENT, 22)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	Screens.history(b, khata_id)


func _kharchi() -> void:
	## Who took the money? (usually the head)
	var members := DB.khata_members(khata_id)
	if members.size() == 1:
		Screens.open_entry_sheet(members[0].id)
		return
	var items := []
	for p in members:
		var pid: String = p.id
		items.append([p.name, "person", func(): Screens.open_entry_sheet(pid)])
	UI.app.menu(Lang.t("who_took"), items)


func _add_member() -> void:
	var exclude := []
	for p in DB.people_list(true):
		if DB.is_family(DB.khata_of(p.id).id):
			exclude.append(p.id)
	PickPersonSheet.open(Lang.t("add_family_member"), func(mid: String):
		var head: String = DB.khata(khata_id).payee_id
		var err := DB.join_family(head, mid)
		UI.app.toast(Lang.t(err) if err != "" else Lang.t("joined_family", [DB.person(mid).name]), "error" if err != "" else "ok"), exclude)


func _menu() -> void:
	var items := []
	var k := DB.khata(khata_id)
	var members := DB.khata_members(khata_id)
	if members.size() > 1:
		items.append([Lang.t("change_head"), "person", func():
			var sub := []
			for p in members:
				var pid: String = p.id
				sub.append([p.name + (" ✓" if pid == k.payee_id else ""), "person", func(): DB.set_payee(khata_id, pid)])
			UI.app.menu(Lang.t("change_head"), sub)])
		items.append([Lang.t("remove_member"), "close", func():
			var sub := []
			for p in members:
				if p.id == k.payee_id:
					continue
				var pid: String = p.id
				sub.append([p.name, "close", func():
					UI.app.confirm(Lang.t("remove_member"), Lang.t("leave_confirm"), Lang.t("remove"), func(): DB.leave_family(pid), true), true])
			UI.app.menu(Lang.t("remove_member"), sub)])
	items.append([Lang.t("add_family_member"), "plus", _add_member])
	UI.app.menu(DB.family_title(khata_id), items)
