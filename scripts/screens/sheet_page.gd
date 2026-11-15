class_name SheetPage
extends Page
## One month's salary sheet: the mills added to it (Add mills next to the label).

var sheet_id := ""


func _init() -> void:
	super._init()


func back_label() -> String:
	return Lang.t("tab_salary")


func nav_right() -> Control:
	return UI.icon_button("more", _menu)


func build(b: VBoxContainer) -> void:
	var sh := DB.sheet(sheet_id)
	if sh.is_empty():
		return
	title = Lang.month_ym(sh.ym)
	var ids: Array = DB.sheet_mill_ids(sheet_id)
	b.add_child(UI.section_title(Lang.t("mills_n", [ids.size()]), UI.small_button(Lang.t("add_mills"), "tinted", func(): AddMillsSheet.open(sheet_id), "plus")))
	var c := UI.card()
	if ids.is_empty():
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_sheet_mills"), UI.S_SUB, UI.TEXT2)), 16, 14, 16, 14))
	else:
		var rows := []
		for mid in ids:
			var m := DB.mill(mid)
			var id: String = mid
			rows.append(UI.row(m.name, Lang.t("n_workers", [DB.sheet_workers(sheet_id, mid).size()]), null, func(): open_mill(sheet_id, id), true, Icons.make("mill", UI.ACCENT, 22)))
		UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))


static func open_mill(sid: String, mid: String) -> void:
	var p := SheetMillPage.new()
	p.sheet_id = sid
	p.mill_id = mid
	UI.app.push(p)


func _menu() -> void:
	var sh := DB.sheet(sheet_id)
	UI.app.menu(Lang.month_ym(sh.ym), [
		[Lang.t("add_mills"), "plus", func(): AddMillsSheet.open(sheet_id)],
		[Lang.t("delete_sheet"), "trash", func():
			UI.app.confirm(Lang.t("delete_sheet"), Lang.t("delete_sheet_q", [Lang.month_ym(sh.ym)]), Lang.t("delete_sheet"), func():
				DB.delete_sheet(sheet_id)
				UI.app.pop(), true), true],
	])
