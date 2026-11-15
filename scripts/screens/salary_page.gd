class_name SalaryPage
extends Page
## Salary tab: one sheet per month ("Oct 2026"), newest first.

func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_salary")
	var sheets: Array = DB.sheets_list()
	b.add_child(UI.section_title(Lang.t("salary_sheets", [sheets.size()]), UI.small_button(Lang.t("new_sheet"), "tinted", func(): MonthSheet.open(), "plus")))
	if sheets.is_empty():
		b.add_child(UI.empty_state("doc", Lang.t("no_sheets"), Lang.t("no_sheets_body"), UI.small_button(Lang.t("new_sheet"), "primary", func(): MonthSheet.open(), "plus")))
		return
	var c := UI.card()
	var rows := []
	for sh in sheets:
		var id: String = sh.id
		var sub := Lang.t("sheet_mills_n", [DB.sheet_mill_ids(id).size(), DB.sheet_worker_count(id)])
		rows.append(UI.row(Lang.month_ym(sh.ym), sub, null, func(): open_sheet(id), true, Icons.make("doc", UI.ACCENT, 22)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))


static func open_sheet(sid: String) -> void:
	var p := SheetPage.new()
	p.sheet_id = sid
	UI.app.push(p)
