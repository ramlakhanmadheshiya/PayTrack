class_name PadBase
extends PanelContainer
## Shared touch handling for the app's keyboards (NumPad, TextPad).
## A key fires the moment a finger touches it, like a phone keyboard, and
## several fingers can type at once (fast two-thumb typing). Holding ⌫ keeps
## deleting, faster the longer it is held.

const REPEAT_FIRST := 0.42
const REPEAT_SLOW := 0.09
const REPEAT_FAST := 0.04

var _keys: Array = []      # [{node, key, normal, pressed, enabled}]
var _held := {}            # pointer index -> key dict
var _repeat: Timer
var _repeat_n := 0


func _init() -> void:
	_repeat = Timer.new()
	_repeat.one_shot = true
	_repeat.timeout.connect(_on_repeat)
	add_child(_repeat, false, Node.INTERNAL_MODE_FRONT)


## Subclasses: what a key does.
func key_down(_k: String) -> void:
	pass


## Subclasses: hardware keyboard. Return true if handled.
func hardware_key(_ev: InputEventKey) -> bool:
	return false


func clear_keys() -> void:
	_keys.clear()
	_held.clear()
	_repeat.stop()


func make_key(k: String, normal: StyleBox, pressed: StyleBox, enabled := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", normal)
	if not enabled:
		p.modulate.a = 0.4
	_keys.append({"node": p, "key": k, "normal": normal, "pressed": pressed, "enabled": enabled})
	return p


func key_at(pos: Vector2) -> Dictionary:
	for kd in _keys:
		var n: Control = kd.node
		if is_instance_valid(n) and n.is_visible_in_tree() and n.get_global_rect().grow(2.5).has_point(pos):
			return kd
	return {}


func _input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventScreenTouch:
		if _pointer(ev.index, ev.position, ev.pressed):
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		# Touches arrive as ScreenTouch too; their copy as a mouse click is skipped.
		if ev.device == InputEvent.DEVICE_ID_EMULATION:
			if not key_at(ev.position).is_empty():
				get_viewport().set_input_as_handled()
			return
		if _pointer(-1, ev.position, ev.pressed):
			get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed:
		if hardware_key(ev):
			get_viewport().set_input_as_handled()


func _pointer(idx: int, pos: Vector2, pressed: bool) -> bool:
	if pressed:
		var kd := key_at(pos)
		if kd.is_empty():
			return false
		if not kd.enabled:
			return true
		_held[idx] = kd
		kd.node.add_theme_stylebox_override("panel", kd.pressed)
		if kd.key == "⌫":
			_repeat_n = 0
			_repeat.start(REPEAT_FIRST)
		key_down(kd.key)
		return true
	if _held.has(idx):
		var kd: Dictionary = _held[idx]
		_held.erase(idx)
		if is_instance_valid(kd.node):
			kd.node.add_theme_stylebox_override("panel", kd.normal)
		if kd.key == "⌫":
			_repeat.stop()
		return true
	return false


func _on_repeat() -> void:
	var still := false
	for kd in _held.values():
		if kd.key == "⌫" and is_instance_valid(kd.node):
			still = true
	if not still or not visible:
		return
	_repeat_n += 1
	key_down("⌫")
	_repeat.start(REPEAT_FAST if _repeat_n > 12 else REPEAT_SLOW)


func release_all() -> void:
	for kd in _held.values():
		if is_instance_valid(kd.node):
			kd.node.add_theme_stylebox_override("panel", kd.normal)
	_held.clear()
	_repeat.stop()
