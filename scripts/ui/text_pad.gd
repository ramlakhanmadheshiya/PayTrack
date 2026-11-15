class_name TextPad
extends PanelContainer
## The app's own letter keyboard (like the iPhone keyboard): A–Z, Shift, 123,
## space, ⌫ and Next/Done. Also accepts a hardware keyboard.

var field: TextField
var shift := false
var numbers := false
var _strip_caption: Label
var _next: Tap
var _prev: Tap
var _grid: VBoxContainer

const ROWS_ABC := [["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], ["a", "s", "d", "f", "g", "h", "j", "k", "l"], ["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"]]
const ROWS_123 := [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], ["-", "/", ".", ",", "'", "(", ")", "&", "@"], ["#", "+", ":", ";", "!", "?", "_", "\"", "⌫"]]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st := UI.box(Color("#D5D7DD"), 0)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 6
	add_theme_stylebox_override("panel", st)
	visible = false


func attach(f: Control) -> void:
	if field and is_instance_valid(field):
		field.set_active(false)
	field = f
	numbers = false
	shift = f.capitalize_words and (f.text == "" or f.text.ends_with(" "))
	f.set_active(true)
	build()


func detach() -> void:
	if field and is_instance_valid(field):
		field.set_active(false)
	field = null


func build() -> void:
	UI.clear(self)
	var v := UI.vbox(6)
	add_child(v)
	var top := UI.hbox(6)
	top.custom_minimum_size.y = 42
	_prev = _strip_icon("back", func(): move(-1))
	top.add_child(_prev)
	_strip_caption = UI.ellipsis(UI.label(field.caption if field else "", UI.S_SUB, UI.TEXT2, 500))
	_strip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_strip_caption)
	# Next/Done is the big key at the bottom right (no second button here).
	top.add_child(UI.spacer(0, 46))
	_prev.enabled = field != null and UI.app.numpad_neighbor(field, -1) != null
	v.add_child(top)
	_grid = UI.vbox(7)
	var col := Column.new()
	col.max_width = 720
	col.side = 0
	col.add_child(_grid)
	v.add_child(col)
	_draw_keys()
	v.add_child(UI.spacer(6 + (UI.app.safe_bottom() if UI.app else 0.0)))


func _draw_keys() -> void:
	UI.clear(_grid)
	var rows: Array = ROWS_123 if numbers else ROWS_ABC
	for r in rows.size():
		var h := UI.hbox(5)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		if r == 1 and not numbers:
			h.add_child(UI.spacer(0, 14))
		for k in rows[r]:
			h.add_child(_key(k))
		if r == 1 and not numbers:
			h.add_child(UI.spacer(0, 14))
		_grid.add_child(h)
	var bottom := UI.hbox(5)
	var nk := _key("ABC" if numbers else "123")
	nk.size_flags_stretch_ratio = 2.2
	bottom.add_child(nk)
	var sp := _key(" ")
	sp.size_flags_stretch_ratio = 6.0
	bottom.add_child(sp)
	var dk := _key("⏎")
	dk.size_flags_stretch_ratio = 2.2
	bottom.add_child(dk)
	_grid.add_child(bottom)


func _key(k: String) -> Tap:
	var t := Tap.new()
	var special := k in ["⇧", "⌫", "123", "ABC", "⏎"]
	var bg := Color("#B9BCC4") if special else Color.WHITE
	if k == "⇧" and shift:
		bg = Color.WHITE
	if k == "⏎":
		bg = UI.ACCENT
	var s := UI.box(bg, 7)
	s.border_width_bottom = 1
	s.border_color = Color("#9A9DA5")
	t.set_styles(s, UI.box(bg.darkened(0.15), 7))
	t.custom_minimum_size = Vector2(26, 46)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown := k
	if k == " ":
		shown = Lang.t("space")
	elif k == "⏎":
		shown = Lang.t("next") if field and UI.app.numpad_neighbor(field, 1) != null else Lang.t("done")
	elif k.length() == 1 and shift and not numbers:
		shown = k.to_upper()
	var l := UI.label(shown, 21 if k.length() == 1 and k != " " else UI.S_SUB, Color.WHITE if k == "⏎" else UI.TEXT, 500 if special else 400)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	c.add_child(l)
	t.add_child_ignoring(c)
	t.tapped.connect(func(): press(k))
	return t


func _strip_icon(icon: String, cb: Callable) -> Tap:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(Color(1, 1, 1, 0.0), 10), 10, 6), UI.pad(UI.box(Color(1, 1, 1, 0.6), 10), 10, 6))
	t.custom_minimum_size = Vector2(46, 40)
	var c := CenterContainer.new()
	c.add_child(Icons.make(icon, UI.ACCENT, 20))
	t.add_child_ignoring(c)
	t.tapped.connect(cb)
	return t


func _strip_text(text: String, cb: Callable) -> Tap:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(UI.ACCENT, 10), 14, 6), UI.pad(UI.box(UI.ACCENT_PRESSED, 10), 14, 6))
	t.custom_minimum_size = Vector2(96, 40)
	var l := UI.label(text, UI.S_SUB, Color.WHITE, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child_ignoring(l)
	t.tapped.connect(cb)
	return t


func press(k: String) -> void:
	if field == null or not is_instance_valid(field):
		return
	match k:
		"⇧":
			shift = not shift
			_draw_keys()
			return
		"123", "ABC":
			numbers = not numbers
			_draw_keys()
			return
		"⌫":
			if field.text != "":
				field.set_text(field.text.substr(0, field.text.length() - 1))
		"⏎":
			move(1)
			return
		_:
			var ch := k
			if shift and not numbers:
				ch = k.to_upper()
			field.set_text(field.text + ch)
	# Capital letter at the start of each word (names).
	var want_shift: bool = field.capitalize_words and not numbers and (field.text == "" or field.text.ends_with(" "))
	if want_shift != shift:
		shift = want_shift
		_draw_keys()


func type_char(ch: String) -> void:
	if field:
		field.set_text(field.text + ch)


func move(dir: int) -> void:
	var n: Control = UI.app.numpad_neighbor(field, dir)
	if dir > 0 and field:
		field.submitted.emit(field.text)
	if n:
		UI.app.numpad_open(n)
	elif dir > 0:
		UI.app.numpad_close()


func _input(ev: InputEvent) -> void:
	if not visible or field == null:
		return
	if ev is InputEventKey and ev.pressed:
		var handled := true
		if ev.keycode == KEY_BACKSPACE:
			press("⌫")
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER or (ev.keycode == KEY_TAB and not ev.shift_pressed):
			move(1)
		elif ev.keycode == KEY_TAB and ev.shift_pressed:
			move(-1)
		elif ev.keycode == KEY_ESCAPE:
			UI.app.numpad_close()
		elif ev.unicode >= 32 and not ev.ctrl_pressed and not ev.meta_pressed:
			type_char(char(ev.unicode))
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()
