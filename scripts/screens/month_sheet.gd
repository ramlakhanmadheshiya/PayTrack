class_name MonthSheet
extends Sheet
## Pick a month for a new salary sheet: ‹ year › and 12 months.

var year := 0


static func open() -> void:
	var s := MonthSheet.new(Lang.t("pick_month"))
	s.year = int(Dates.today().substr(0, 4))
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 12)
	var yr := UI.hbox(8)
	yr.alignment = BoxContainer.ALIGNMENT_CENTER
	yr.add_child(UI.icon_button("back", func(): year -= 1; build()))
	var yl := UI.label(str(year), UI.S_TITLE, UI.TEXT, 700, true)
	yl.custom_minimum_size.x = 90
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yr.add_child(yl)
	var fwd := UI.icon_button("chevron", func(): year += 1; build())
	yr.add_child(fwd)
	body.add_child(yr)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for m in range(1, 13):
		var ym := "%04d-%02d" % [year, m]
		var have := not DB.sheet_for(ym).is_empty()
		var kind := "secondary"
		if have:
			kind = "tinted"
		var btn := UI.button(Lang.month_short(m) + (" ✓" if have else ""), kind, func(): _pick(ym))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)
	body.add_child(grid)


func _pick(ym: String) -> void:
	var have := DB.sheet_for(ym)
	close()
	if not have.is_empty():
		UI.app.toast(Lang.t("sheet_exists", [Lang.month_ym(ym)]))
		SalaryPage.open_sheet(have.id)
		return
	var sh := DB.add_sheet(ym)
	SalaryPage.open_sheet(sh.id)
	AddMillsSheet.open(sh.id)
