class_name NumPad
extends PanelContainer
## The app's own number pad (like the iPhone keypad). Works with touch and
## with a hardware keyboard (digits, ".", Backspace, Enter/Tab = next, Esc = done).

signal height_changed(h: float)

var field: NumField
var buffer := ""
var fresh := true
var _caption: Label
var _value: Label
var _next: Tap
var _prev: Tap


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st := UI.box(Color("#D5D7DD"), 0)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	add_theme_stylebox_override("panel", st)
	visible = false


func build() -> void:
	UI.clear(self)
	var v := UI.vbox(6)
	add_child(v)
	# Top strip: what you are typing, the value, prev / next / done.
	var top := UI.hbox(6)
	top.custom_minimum_size.y = 46
	_prev = _strip_button("back", func(): move(-1))
	top.add_child(_prev)
	var mid := UI.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	_caption = UI.ellipsis(UI.label("", UI.S_CAP, UI.TEXT2, 500))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value = UI.label("", 22, UI.TEXT, 700, true)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_caption)
	mid.add_child(_value)
	top.add_child(mid)
	_next = _strip_text(Lang.t("next"), func(): move(1))
	top.add_child(_next)
	top.add_child(_strip_text(Lang.t("done"), func(): UI.app.numpad_close(), true))
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]:
		grid.add_child(_key(k))
	var col := Column.new()
	col.max_width = 520
	col.side = 0
	col.add_child(grid)
	v.add_child(col)
	var pad_bottom := UI.spacer(6 + (UI.app.safe_bottom() if UI.app else 0.0))
	v.add_child(pad_bottom)


func _strip_button(icon: String, cb: Callable) -> Tap:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(Color(1, 1, 1, 0.0), 10), 10, 6), UI.pad(UI.box(Color(1, 1, 1, 0.6), 10), 10, 6))
	t.custom_minimum_size = Vector2(46, 42)
	var c := CenterContainer.new()
	c.add_child(Icons.make(icon, UI.ACCENT, 20))
	t.add_child_ignoring(c)
	t.tapped.connect(cb)
	return t


func _strip_text(text: String, cb: Callable, bold := false) -> Tap:
	var t := Tap.new()
	var bg := UI.ACCENT if bold else Color(1, 1, 1, 0.75)
	t.set_styles(UI.pad(UI.box(bg, 10), 14, 6), UI.pad(UI.box(bg.darkened(0.12), 10), 14, 6))
	t.custom_minimum_size.y = 40
	var l := UI.label(text, UI.S_SUB, Color.WHITE if bold else UI.ACCENT, 700 if bold else 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child_ignoring(l)
	t.tapped.connect(cb)
	return t


func _key(k: String) -> Tap:
	var t := Tap.new()
	var special := k == "⌫" or k == "."
	var bg := Color("#BFC2CA") if k == "⌫" else Color.WHITE
	var s := UI.box(bg, 8)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 1)
	s.border_width_bottom = 1
	s.border_color = Color("#9A9DA5")
	var sp := UI.box(Color("#C6C9D0") if not special or k == "." else Color.WHITE, 8)
	t.set_styles(s, sp)
	t.custom_minimum_size = Vector2(0, 48)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := CenterContainer.new()
	if k == "⌫":
		c.add_child(UI.label("⌫", 22, UI.TEXT, 400))
	else:
		c.add_child(UI.label(k, 25, UI.TEXT, 400, true))
	t.add_child_ignoring(c)
	t.tapped.connect(func(): press(k))
	if k == "." and field and not field.decimals:
		t.enabled = false
	return t


func attach(f: NumField) -> void:
	if field and is_instance_valid(field):
		field.set_active(false)
	field = f
	buffer = f.text_value()
	fresh = true
	f.set_active(true)
	build()
	_update()


func detach() -> void:
	if field and is_instance_valid(field):
		_commit()
		field.set_active(false)
		field._show()
	field = null


func _commit() -> void:
	if field == null or not is_instance_valid(field):
		return
	var v := buffer.to_float() if buffer != "" and buffer != "." else 0.0
	if not field.decimals:
		v = floorf(v)
	field.set_value(v)


func press(k: String) -> void:
	if field == null or not is_instance_valid(field):
		return
	if k == "⌫":
		if fresh:
			buffer = ""
		else:
			buffer = buffer.substr(0, maxi(0, buffer.length() - 1))
		fresh = false
	elif k == ".":
		if not field.decimals:
			return
		if fresh:
			buffer = "0."
		elif not "." in buffer:
			buffer = (buffer if buffer != "" else "0") + "."
		fresh = false
	else:
		if fresh:
			buffer = ""
			fresh = false
		if "." in buffer and buffer.get_slice(".", 1).length() >= 2:
			return
		if buffer.replace(".", "").length() >= 9:
			return
		if buffer == "0":
			buffer = ""
		buffer += k
	_commit()
	_update()


func _update() -> void:
	if field == null:
		return
	_caption.text = field.caption
	var shown := buffer
	if field.is_money and buffer != "" and not "." in buffer:
		shown = "₹" + Money.group(buffer.to_int())
	_value.text = shown if shown != "" else "0"
	field.set_display(Money.group(buffer.to_int()) if field.is_money and buffer != "" and not "." in buffer else buffer)
	_next.enabled = UI.app.numpad_neighbor(field, 1) != null
	_prev.enabled = UI.app.numpad_neighbor(field, -1) != null


func move(dir: int) -> void:
	var n: NumField = UI.app.numpad_neighbor(field, dir)
	if n:
		_commit()
		UI.app.numpad_open(n)
	elif dir > 0:
		UI.app.numpad_close()


func _input(ev: InputEvent) -> void:
	if not visible or field == null:
		return
	if ev is InputEventKey and ev.pressed:
		var kc: int = ev.keycode
		var handled := true
		if kc >= KEY_0 and kc <= KEY_9:
			press(str(kc - KEY_0))
		elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
			press(str(kc - KEY_KP_0))
		elif kc == KEY_PERIOD or kc == KEY_KP_PERIOD:
			press(".")
		elif kc == KEY_BACKSPACE:
			press("⌫")
		elif kc == KEY_TAB and ev.shift_pressed:
			move(-1)
		elif kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_TAB:
			move(1)
		elif kc == KEY_ESCAPE:
			UI.app.numpad_close()
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()
