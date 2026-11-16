class_name PinLock
extends Control
## Optional 4-digit PIN asked when PayTrack opens (More › Lock with PIN).
## Only on this phone. The PIN is kept as a salted fingerprint, never as is.
## Also used to choose a PIN (mode "set").

signal finished(ok: bool)

const PATH := "user://lock.json"
const AWAY_SECONDS := 60

var mode := "unlock"     # "unlock" | "set" | "check"
var _digits := ""
var _first := ""
var _title: Label
var _msg: Label
var _dots: HBoxContainer


static func is_on() -> bool:
	return FileAccess.file_exists(PATH)


static func _hash(pin: String, salt: String) -> String:
	return (salt + ":" + pin).sha256_text()


static func set_pin(pin: String) -> void:
	var salt := str(randi()) + str(Time.get_ticks_usec())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"salt": salt, "hash": _hash(pin, salt)}))
		f.close()


static func turn_off() -> void:
	if is_on():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func check(pin: String) -> bool:
	if not is_on():
		return true
	var p = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (p is Dictionary):
		return true
	return _hash(pin, String(p.get("salt", ""))) == String(p.get("hash", ""))


static func show_lock(m := "unlock") -> PinLock:
	var l := PinLock.new()
	l.mode = m
	UI.app.add_child(l)
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UI.vbox(18)
	v.custom_minimum_size.x = 300
	center.add_child(v)
	var icon := CenterContainer.new()
	icon.add_child(Icons.make("check_circle" if mode == "set" else "info", UI.ACCENT, 40))
	v.add_child(icon)
	_title = UI.label("", UI.S_TITLE, UI.TEXT, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_dots = UI.hbox(16)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_dots)
	_msg = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_msg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]:
		grid.add_child(_key(k))
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	var bottom := UI.hbox(8)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	if mode == "unlock":
		bottom.add_child(UI.link(Lang.t("forgot_pin"), _forgot, UI.ACCENT, UI.S_SUB))
	else:
		bottom.add_child(UI.link(Lang.t("cancel"), func(): _done(false), UI.ACCENT, UI.S_SUB))
	v.add_child(bottom)
	_update()


func _key(k: String) -> Control:
	if k == "":
		return UI.spacer(64, 76)
	var t := Tap.new()
	t.set_styles(UI.box(UI.CARD, 38), UI.box(UI.FILL_PRESSED, 38))
	t.custom_minimum_size = Vector2(76, 64)
	var c := CenterContainer.new()
	c.add_child(UI.label(k, 26, UI.TEXT, 500))
	t.add_child_ignoring(c)
	t.tapped.connect(func(): press(k))
	return t


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_BACKSPACE:
			press("⌫")
		elif ev.unicode >= 48 and ev.unicode <= 57:
			press(char(ev.unicode))
		get_viewport().set_input_as_handled()


func press(k: String) -> void:
	if k == "⌫":
		_digits = _digits.substr(0, maxi(_digits.length() - 1, 0))
	elif _digits.length() < 4:
		_digits += k
		_msg.text = ""
	_update()
	if _digits.length() == 4:
		_complete.call_deferred()


func _update() -> void:
	if mode == "set":
		_title.text = Lang.t("set_pin") if _first == "" else Lang.t("confirm_pin")
	else:
		_title.text = Lang.t("enter_pin")
	UI.clear(_dots)
	for i in 4:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(16, 16)
		d.add_theme_stylebox_override("panel", UI.box(UI.ACCENT if i < _digits.length() else UI.LINE, 8))
		_dots.add_child(d)


func _complete() -> void:
	if _digits.length() != 4:
		return
	if mode == "set":
		if _first == "":
			_first = _digits
			_digits = ""
			_update()
			return
		if _first != _digits:
			_first = ""
			_digits = ""
			_msg.text = Lang.t("pins_differ")
			_update()
			return
		set_pin(_digits)
		_done(true)
		return
	if check(_digits):
		_done(true)
	else:
		_digits = ""
		_msg.text = Lang.t("wrong_pin")
		_update()


func _done(ok: bool) -> void:
	finished.emit(ok)
	queue_free()


func _forgot() -> void:
	## Shown inside the lock (other screens are hidden behind it).
	var shared: bool = Sync.enabled()
	var panel := ColorRect.new()
	panel.color = UI.BG
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var v := UI.vbox(16)
	v.custom_minimum_size.x = 320
	center.add_child(v)
	var t := UI.label(Lang.t("forgot_pin"), UI.S_TITLE, UI.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.wrapped(UI.label(Lang.t("forgot_pin_shared") if shared else Lang.t("forgot_pin_alone"), UI.S_SUB, UI.TEXT2)))
	var sure := [false]
	var erase_btn := UI.button(Lang.t("erase_and_reset"), "danger", func(): pass, "trash")
	erase_btn.tapped.connect(func():
		if not sure[0]:
			sure[0] = true
			t.text = Lang.t("erase_q2")
			return
		_erase_phone(shared))
	v.add_child(erase_btn)
	v.add_child(UI.button(Lang.t("back"), "secondary", func(): panel.queue_free()))


func _erase_phone(shared: bool) -> void:
	Sync.leave()
	var lang := Lang.lang
	DB.data = DB.empty_data()
	DB.data.settings.lang = lang
	DB.save()
	turn_off()
	UI.app.go_tab_root("home")
	_done(true)
	if shared:
		JoinSheet.open()
