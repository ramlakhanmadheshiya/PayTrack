class_name TextField
extends Tap
## A text box typed with the app's own keyboard (TextPad), never the phone's.
## The screen moves up above the keyboard, so what you type is always visible.

signal text_changed(t: String)
signal submitted(t: String)
signal text_settled(t: String)   # after typing pauses (for search lists)

var text := ""
var placeholder := ""
var caption := ""          # shown on the keyboard strip
var max_length := 40
var capitalize_words := true
var style := "box"         # "box" (white, border) | "search" (grey, magnifier) | "plain" (inside a card)
var font_size := UI.S_BODY
var _label: Label
var _active := false
var _caret_on := true
var _blink: Timer
var _settle: Timer
var caret := 0
var _caret_rect: ColorRect


static func make(t: String, ph: String, cap := "", st := "box") -> TextField:
	var f := TextField.new()
	f.text = t
	f.placeholder = ph
	f.caption = cap if cap != "" else ph
	f.style = st
	return f


func _ready() -> void:
	custom_minimum_size.y = 42 if style == "search" else 50
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(8)
	if style == "search":
		h.add_child(Icons.make("search", UI.TEXT3, 18))
	_label = UI.label("", font_size, UI.TEXT, 400)
	_label.set_meta("raw", true)   # what is typed is shown as typed
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_label.clip_text = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_label)
	add_child_ignoring(h)
	_caret_rect = ColorRect.new()
	_caret_rect.color = UI.ACCENT
	_caret_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret_rect.visible = false
	_label.add_child(_caret_rect)
	_label.resized.connect(_show)
	caret = text.length()
	tapped.connect(_on_tapped)
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = 0.18
	_settle.timeout.connect(func(): text_settled.emit(text))
	add_child(_settle)
	_blink = Timer.new()
	_blink.wait_time = 0.55
	_blink.timeout.connect(func(): _caret_on = not _caret_on; _show())
	add_child(_blink)
	_restyle()
	_show()


func set_active(on: bool) -> void:
	_active = on
	_caret_on = true
	if on:
		_blink.start()
	else:
		_blink.stop()
	_restyle()
	_show()


func _restyle() -> void:
	var s: StyleBoxFlat
	match style:
		"search":
			s = UI.box(UI.CARD if _active else Color("#E6E6EC"), 11, UI.ACCENT, 2 if _active else 0)
			UI.pad(s, 12, 6)
		"plain":
			s = UI.box(Color(1, 1, 1, 0), 0)
			UI.pad(s, 16, 8)
		_:
			s = UI.box(UI.CARD, 10, UI.ACCENT if _active else UI.LINE, 2 if _active else 1)
			UI.pad(s, 14, 8)
	set_styles(s, s)


func _on_tapped() -> void:
	var was := _active
	UI.app.numpad_open(self)
	# Tapping inside the text puts the cursor there (to fix one letter).
	if was or text != "":
		set_caret(_caret_from_x(last_tap_global.x - _label.global_position.x))
		if UI.app.textpad.field == self:
			UI.app.textpad.caret_moved()


func _text_width(n: int) -> float:
	var f: Font = _label.get_theme_font("font")
	var fs: int = _label.get_theme_font_size("font_size")
	return f.get_string_size(text.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _caret_from_x(x: float) -> int:
	var best := text.length()
	var best_d := INF
	for i in text.length() + 1:
		var d := absf(_text_width(i) - x)
		if d < best_d:
			best_d = d
			best = i
	return best


func set_caret(i: int) -> void:
	caret = clampi(i, 0, text.length())
	_caret_on = true
	if _blink and _active:
		_blink.start()
	_show()


func _show() -> void:
	if _label == null:
		return
	if text == "" and not _active:
		_label.text = placeholder
		_label.add_theme_color_override("font_color", UI.TEXT3)
	else:
		_label.text = text
		_label.add_theme_color_override("font_color", UI.TEXT)
	_caret_rect.visible = _active and _caret_on
	if _active:
		var fs: int = _label.get_theme_font_size("font_size")
		var h := fs * 1.25
		_caret_rect.size = Vector2(2, h)
		_caret_rect.position = Vector2(minf(_text_width(caret), maxf(_label.size.x - 2, 0)), (_label.size.y - h) / 2.0)


func set_text(t: String, emit := true) -> void:
	text = t.substr(0, max_length)
	caret = text.length()
	_changed(emit)
	if _active and UI.app and UI.app.textpad.field == self:
		UI.app.textpad.caret_moved()


func insert(s: String) -> void:
	if text.length() + s.length() > max_length:
		return
	text = text.substr(0, caret) + s + text.substr(caret)
	caret += s.length()
	_changed(true)


func backspace() -> void:
	if caret <= 0:
		return
	text = text.substr(0, caret - 1) + text.substr(caret)
	caret -= 1
	_changed(true)


func _changed(emit: bool) -> void:
	_caret_on = true
	if _blink and _active:
		_blink.start()
	_show()
	if emit:
		text_changed.emit(text)
		if _settle:
			_settle.start()
