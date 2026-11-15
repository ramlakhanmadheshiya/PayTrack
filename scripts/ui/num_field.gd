class_name NumField
extends Tap
## A number box. Tapping it opens the app's own number pad (never the phone
## keyboard). "Next" on the pad jumps to the next NumField on the screen.

signal value_changed(v: float)

var value := 0.0
var decimals := true
var caption := ""         # shown on the number pad, e.g. "Ramu · F · Attendance"
var placeholder := "—"
var is_money := false
var min_width := 64.0
var align := HORIZONTAL_ALIGNMENT_CENTER
var font_size := UI.S_BODY
var _label: Label
var _active := false


static func make(v: float, cap: String, allow_decimals := true, money := false, width := 64.0) -> NumField:
	var f := NumField.new()
	f.value = v
	f.caption = cap
	f.decimals = allow_decimals
	f.is_money = money
	f.min_width = width
	return f


func _ready() -> void:
	custom_minimum_size = Vector2(min_width, 42)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = UI.label("", font_size, UI.TEXT, 600, true)
	_label.horizontal_alignment = align
	add_child_ignoring(_label)
	tapped.connect(func(): UI.app.numpad_open(self))
	_restyle()
	_show()


func set_active(on: bool) -> void:
	_active = on
	_restyle()


func _restyle() -> void:
	var s: StyleBoxFlat
	if _active:
		s = UI.box(UI.CARD, 10, UI.ACCENT, 2)
	else:
		s = UI.box(UI.FILL, 10)
	UI.pad(s, 8, 4)
	set_styles(s, UI.pad(UI.box(UI.FILL_PRESSED, 10), 8, 4))


func text_value() -> String:
	if value == 0.0:
		return ""
	if is_money:
		return str(int(value))
	return Money.num(value)


func _show() -> void:
	if _label == null:
		return
	var t := text_value()
	if t == "":
		_label.text = placeholder
		_label.add_theme_color_override("font_color", UI.TEXT3)
	else:
		_label.text = Money.group(int(value)) if is_money else t
		_label.add_theme_color_override("font_color", UI.TEXT)


func set_value(v: float, emit := true) -> void:
	value = v
	_show()
	if emit:
		value_changed.emit(v)


func set_display(text: String) -> void:
	## While typing: show the raw buffer (e.g. "31.").
	if _label:
		_label.text = text if text != "" else placeholder
		_label.add_theme_color_override("font_color", UI.TEXT if text != "" else UI.TEXT3)
