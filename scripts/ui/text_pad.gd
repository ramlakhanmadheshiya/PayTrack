class_name TextPad
extends PadBase
## The app's own letter keyboard (like the iPhone keyboard): A–Z, Shift, 123,
## space, ⌫ and Next/Done. Types at the cursor, which can be placed anywhere
## by tapping in the text box. Also accepts a hardware keyboard.

var field: TextField
var shift := false
var numbers := false
var _strip_caption: Label
var _prev: Tap
var _grid: VBoxContainer
var _letter_labels: Array = []   # [[Label, key]]
var _shift_key: PanelContainer
var _done_label: Label

const ROWS_ABC := [["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], ["a", "s", "d", "f", "g", "h", "j", "k", "l"], ["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"]]
const ROWS_123 := [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], ["-", "/", ".", ",", "'", "(", ")", "&", "@"], ["#", "+", ":", ";", "!", "?", "_", "\"", "⌫"]]
const SPECIAL := ["⇧", "⌫", "123", "ABC", "⏎"]


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
	f.set_active(true)
	shift = _want_shift()
	build()


func detach() -> void:
	release_all()
	if field and is_instance_valid(field):
		field.set_active(false)
	field = null


func build() -> void:
	UI.clear(self)
	clear_keys()
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
	clear_keys()
	_letter_labels.clear()
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


func _key_bg(k: String) -> Color:
	if k == "⏎":
		return UI.ACCENT
	if k == "⇧" and shift:
		return Color.WHITE
	return Color("#B9BCC4") if k in SPECIAL else Color.WHITE


func _key_styles(k: String) -> Array:
	var bg := _key_bg(k)
	var s := UI.box(bg, 7)
	s.border_width_bottom = 1
	s.border_color = Color("#9A9DA5")
	var p := UI.box(Color("#B9BCC4") if not k in SPECIAL else bg.darkened(0.15), 7)
	return [s, p]


func _key(k: String) -> PanelContainer:
	var st := _key_styles(k)
	var t := make_key(k, st[0], st[1])
	t.custom_minimum_size = Vector2(26, 46)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown := k
	if k == " ":
		shown = Lang.t("space")
	elif k == "⏎":
		shown = _done_text()
	elif k.length() == 1 and shift and not numbers:
		shown = k.to_upper()
	var l := UI.label(shown, 21 if k.length() == 1 and k != " " else UI.S_SUB, Color.WHITE if k == "⏎" else UI.TEXT, 500 if k in SPECIAL else 400)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	t.add_child(c)
	UI.ignore_mouse(c)
	if k.length() == 1 and k != " " and not k in SPECIAL:
		_letter_labels.append([l, k])
	if k == "⇧":
		_shift_key = t
	if k == "⏎":
		_done_label = l
	return t


func _done_text() -> String:
	return Lang.t("next") if field and UI.app.numpad_neighbor(field, 1) != null else Lang.t("done")


func _set_shift(on: bool) -> void:
	## Changes only the letters on the keys (no rebuild, so typing stays fast).
	if on == shift:
		return
	shift = on
	if numbers:
		return
	for pair in _letter_labels:
		pair[0].text = pair[1].to_upper() if shift else pair[1]
	for kd in _keys:
		if kd.key == "⇧":
			var st := _key_styles("⇧")
			kd.normal = st[0]
			kd.pressed = st[1]
			if is_instance_valid(kd.node):
				kd.node.add_theme_stylebox_override("panel", st[0])


func _want_shift() -> bool:
	if field == null or not field.capitalize_words or numbers:
		return false
	var c: int = field.caret
	return c == 0 or field.text.substr(c - 1, 1) == " "


func _strip_icon(icon: String, cb: Callable) -> Tap:
	var t := Tap.new()
	t.set_styles(UI.pad(UI.box(Color(1, 1, 1, 0.0), 10), 10, 6), UI.pad(UI.box(Color(1, 1, 1, 0.6), 10), 10, 6))
	t.custom_minimum_size = Vector2(46, 40)
	var c := CenterContainer.new()
	c.add_child(Icons.make(icon, UI.ACCENT, 20))
	t.add_child_ignoring(c)
	t.tapped.connect(cb)
	return t


func key_down(k: String) -> void:
	press(k)


func press(k: String) -> void:
	if field == null or not is_instance_valid(field):
		return
	match k:
		"⇧":
			_set_shift(not shift)
			return
		"123", "ABC":
			numbers = not numbers
			_draw_keys.call_deferred()
			return
		"⌫":
			field.backspace()
		"⏎":
			move.call_deferred(1)
			return
		_:
			var ch := k
			if shift and not numbers:
				ch = k.to_upper()
			field.insert(ch)
	# Capital letter at the start of each word (names).
	_set_shift(_want_shift())


func type_char(ch: String) -> void:
	if field:
		field.insert(ch)
		_set_shift(_want_shift())


func caret_moved() -> void:
	## The field's cursor was moved by a tap.
	_set_shift(_want_shift())


func move(dir: int) -> void:
	if field == null or not is_instance_valid(field):
		return
	var n: Control = UI.app.numpad_neighbor(field, dir)
	if dir > 0 and field:
		field.submitted.emit(field.text)
	if n:
		UI.app.numpad_open(n)
	elif dir > 0:
		UI.app.numpad_close()


func hardware_key(ev: InputEventKey) -> bool:
	if field == null:
		return false
	match ev.keycode:
		KEY_BACKSPACE:
			press("⌫")
		KEY_ENTER, KEY_KP_ENTER:
			move(1)
		KEY_TAB:
			move(-1 if ev.shift_pressed else 1)
		KEY_ESCAPE:
			UI.app.numpad_close()
		KEY_LEFT:
			field.set_caret(field.caret - 1)
			caret_moved()
		KEY_RIGHT:
			field.set_caret(field.caret + 1)
			caret_moved()
		KEY_HOME:
			field.set_caret(0)
		KEY_END:
			field.set_caret(field.text.length())
		_:
			if ev.unicode >= 32 and not ev.ctrl_pressed and not ev.meta_pressed:
				type_char(char(ev.unicode))
			else:
				return false
	return true
