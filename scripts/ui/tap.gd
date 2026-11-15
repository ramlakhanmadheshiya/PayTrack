class_name Tap
extends PanelContainer
## A tappable surface. Unlike Button it never blocks scrolling: a finger that
## moves more than a few pixels is a scroll, not a tap. Used for every button,
## row and field in the app.

signal tapped

const SLOP := 12.0

var style_normal: StyleBox
var style_pressed: StyleBox
var style_hover: StyleBox
var enabled := true:
	set(v):
		enabled = v
		modulate.a = 1.0 if v else 0.4
var _down := false
var _start := Vector2.ZERO
var _hover := false
var last_tap_global := Vector2.ZERO   # where the last tap ended


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; _apply())
	mouse_exited.connect(func(): _hover = false; _down = false; _apply())


func set_styles(normal: StyleBox, pressed: StyleBox = null, hover: StyleBox = null) -> void:
	style_normal = normal
	style_pressed = pressed if pressed else normal
	style_hover = hover if hover else normal
	_apply()


func _apply() -> void:
	if style_normal == null:
		return
	var s := style_normal
	if _down and enabled:
		s = style_pressed
	elif _hover and enabled and not DisplayServer.is_touchscreen_available():
		s = style_hover
	add_theme_stylebox_override("panel", s)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			_start = ev.global_position
			_apply()
		elif _down:
			_down = false
			_apply()
			last_tap_global = get_global_transform() * ev.position
			if enabled and ev.global_position.distance_to(_start) < SLOP and Rect2(Vector2.ZERO, size).has_point(ev.position):
				tapped.emit()
				# The tap may have rebuilt the screen and removed this button.
				if is_inside_tree():
					accept_event()
	elif ev is InputEventMouseMotion and _down:
		if ev.global_position.distance_to(_start) >= SLOP:
			_down = false
			_apply()


func add_child_ignoring(c: Node) -> void:
	add_child(c)
	UI.ignore_mouse(c)
