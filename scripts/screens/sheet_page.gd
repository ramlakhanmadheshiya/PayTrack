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
			var nw := DB.sheet_workers(sheet_id, mid).size()
			var sub := Lang.t("n_workers", [nw])
			if nw > 0:
				sub += " · " + Lang.t("n_filled", [DB.sheet_filled_count(sheet_id, mid), nw])
			rows.append(UI.row(m.name, sub, null, func(): open_mill(sheet_id, id), true, Icons.make("mill", UI.ACCENT, 22)))
		UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	var prev := DB.sheet_before(sheet_id)
	if not prev.is_empty() and ids.is_empty():
		b.add_child(UI.margin(repeat_card(sheet_id, prev), 16, 16, 16, 0))


static func repeat_card(sid: String, prev: Dictionary, after: Callable = Callable()) -> Control:
	## "Repeat Oct 2026": the same mills and worker list as that month.
	var n := DB.sheet_counts(prev.id)
	var month := Lang.month_ym(prev.ym)
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(UI.CARD, 12), 16, 12), UI.pad(UI.box(UI.FILL_PRESSED, 12), 16, 12))
	var h := UI.hbox(12)
	h.add_child(Icons.make("undo", UI.ACCENT, 22))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(Lang.t("repeat_month", [month]), UI.S_BODY, UI.ACCENT, 600))
	v.add_child(UI.wrapped(UI.label(Lang.t("repeat_month_sub", [month, n[0], n[1]]), UI.S_SUB, UI.TEXT2)))
	h.add_child(v)
	t.add_child_ignoring(h)
	var pid: String = prev.id
	t.tapped.connect(func():
		repeat(sid, pid)
		if after.is_valid():
			after.call())
	return t


static func repeat(sid: String, from_sid: String) -> void:
	var month := Lang.month_ym(DB.sheet(from_sid).ym)
	var res := DB.sheet_repeat(sid, from_sid)
	if res[0] + res[1] == 0:
		UI.app.toast(Lang.t("repeat_nothing", [month]))
	else:
		UI.app.toast(Lang.t("repeated", [res[0], res[1], month]))


static func open_mill(sid: String, mid: String) -> void:
	var p := SheetMillPage.new()
	p.sheet_id = sid
	p.mill_id = mid
	UI.app.push(p)


func _menu() -> void:
	var sh := DB.sheet(sheet_id)
	var items := [[Lang.t("add_mills"), "plus", func(): AddMillsSheet.open(sheet_id)]]
	var prev := DB.sheet_before(sheet_id)
	if not prev.is_empty():
		var pid: String = prev.id
		items.append([Lang.t("repeat_month", [Lang.month_ym(prev.ym)]), "undo", func(): repeat(sheet_id, pid)])
	items.append(
		[Lang.t("delete_sheet"), "trash", func():
			UI.app.confirm(Lang.t("delete_sheet"), Lang.t("delete_sheet_q", [Lang.month_ym(sh.ym)]), Lang.t("delete_sheet"), func():
				DB.delete_sheet(sheet_id)
				UI.app.pop(), true), true])
	UI.app.menu(Lang.month_ym(sh.ym), items)
