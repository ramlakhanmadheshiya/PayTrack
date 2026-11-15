class_name DateSheet
extends Sheet
## Calendar picker with quick choices (Today, Yesterday, End of last month).

var value := ""
var shown_month := ""
var on_pick: Callable
var quick: Array = []      # [[label, date], ...]
var min_date := ""
var max_date := ""
var _grid_holder: VBoxContainer


static func open(t: String, current: String, cb: Callable, quick_choices: Array = [], lo := "", hi := "") -> void:
	var s := DateSheet.new(t)
	s.value = current if Dates.valid(current) else Dates.today()
	s.shown_month = Dates.first_of_month(s.value)
	s.on_pick = cb
	s.quick = quick_choices
	s.min_date = lo
	s.max_date = hi
	UI.app.present(s)


func build() -> void:
	if not quick.is_empty():
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 8)
		h.add_theme_constant_override("v_separation", 8)
		for q in quick:
			var d: String = q[1]
			var b := UI.small_button(q[0] + " · " + Lang.date_short(d), "tinted", func(): _pick(d))
			b.enabled = _allowed(d)
			h.add_child(b)
		body.add_child(h)
		body.add_child(UI.spacer(14))
	_grid_holder = UI.vbox(0)
	body.add_child(_grid_holder)
	_draw_month()


func _allowed(d: String) -> bool:
	return (min_date == "" or d >= min_date) and (max_date == "" or d <= max_date)


func _draw_month() -> void:
	UI.clear(_grid_holder)
	var head := UI.hbox(4)
	head.add_child(UI.icon_button("back", func(): shown_month = Dates.add_months(shown_month, -1); _draw_month(), UI.ACCENT, 18))
	var ml := UI.label("%s %d" % [Lang.month_long(Dates.month(shown_month)), Dates.year(shown_month)], UI.S_HEAD, UI.TEXT, 600)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(UI.expand(ml))
	head.add_child(UI.icon_button("chevron", func(): shown_month = Dates.add_months(shown_month, 1); _draw_month(), UI.ACCENT, 18))
	_grid_holder.add_child(head)
	_grid_holder.add_child(UI.spacer(6))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	for i in 7:
		var l := UI.label(Lang.t("wd_%d" % i), UI.S_CAP, UI.TEXT3, 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	var first := Dates.weekday(shown_month)
	for i in first:
		grid.add_child(UI.spacer(40))
	var today := Dates.today()
	for d in Dates.month_days_of(shown_month):
		var ds := Dates.make(Dates.year(shown_month), Dates.month(shown_month), d + 1)
		var t := Tap.new()
		var sel := ds == value
		var bg := UI.ACCENT if sel else Color(0, 0, 0, 0)
		t.set_styles(UI.box(bg, 20), UI.box(UI.ACCENT_PRESSED if sel else UI.FILL, 20))
		t.custom_minimum_size = Vector2(40, 40)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UI.TEXT
		if sel:
			col = Color.WHITE
		elif ds == today:
			col = UI.ACCENT
		var l := UI.label(str(d + 1), UI.S_BODY, col, 700 if (sel or ds == today) else 400, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_child_ignoring(l)
		t.enabled = _allowed(ds)
		t.tapped.connect(func(): _pick(ds))
		grid.add_child(t)
	_grid_holder.add_child(grid)


func _pick(d: String) -> void:
	if not _allowed(d):
		return
	if on_pick.is_valid():
		on_pick.call(d)
	close()
