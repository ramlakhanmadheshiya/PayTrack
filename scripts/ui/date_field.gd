class_name PayTrackDateField
extends Button
const Calendar = preload("res://scripts/domain/payroll.gd")
signal date_changed(value: String)
var value: String = "":
	set(new_value):
		value = new_value
		if Calendar.valid_date(value):
			text = display(value)
		date_changed.emit(value)

static func display(date: String) -> String:
	if not Calendar.valid_date(date): return date
	var parts = date.split("-")
	return "%d %s %s" % [int(parts[2]),["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][int(parts[1])-1],parts[0]]

func _ready():
	custom_minimum_size.y = 48
	icon = preload("res://assets/ui/attendance.svg")
	icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_constant_override("h_separation",8)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(open_calendar)

func open_calendar():
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 120
	get_tree().root.get_child(get_tree().root.get_child_count()-1).add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.08,0.12,0.2,0.28)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel",style)
	panel.custom_minimum_size.x = 320
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var top = HBoxContainer.new()
	column.add_child(top)
	var month = OptionButton.new()
	month.custom_minimum_size = Vector2(160,44)
	for name in ["January","February","March","April","May","June","July","August","September","October","November","December"]: month.add_item(name)
	top.add_child(month)
	var year = SpinBox.new()
	year.min_value = 1900
	year.max_value = 2200
	year.custom_minimum_size = Vector2(110,44)
	top.add_child(year)
	var parts = value.split("-") if Calendar.valid_date(value) else Time.get_date_string_from_system().split("-")
	month.select(int(parts[1])-1)
	year.value = int(parts[0])
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation",2)
	grid.add_theme_constant_override("v_separation",4)
	column.add_child(grid)
	var refresh = func(_unused = 0):
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		for weekday in ["M","T","W","T","F","S","S"]:
			var heading = Label.new()
			heading.text = weekday
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(heading)
		var first = "%04d-%02d-01" % [int(year.value),month.selected+1]
		var day_of_week = int(Time.get_datetime_dict_from_unix_time(Calendar.day(first)*86400).weekday)
		for _blank in (day_of_week+6)%7:
			grid.add_child(Control.new())
		for day_number in Calendar.month_days(int(year.value),month.selected+1):
			var day_value = "%04d-%02d-%02d" % [int(year.value),month.selected+1,day_number+1]
			var day_button = Button.new()
			day_button.text = str(day_number+1)
			day_button.custom_minimum_size = Vector2(38,42)
			grid.add_child(day_button)
			if day_value == value: day_button.modulate = Color("c5ddff")
			day_button.pressed.connect(func():
				value = day_value
				overlay.queue_free())
	month.item_selected.connect(refresh)
	year.value_changed.connect(refresh)
	refresh.call()
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size.y = 44
	column.add_child(cancel)
	cancel.pressed.connect(overlay.queue_free)
