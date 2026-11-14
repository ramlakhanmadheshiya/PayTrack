extends ScrollContainer
## Receive touch gestures before nested form controls consume them.
var tracking = false
var dragging = false
var origin = Vector2.ZERO
var previous = Vector2.ZERO
var speed = 0.0
var finger = -1

func _ready():
	add_to_group("paytrack_scrolls")
	resized.connect(func(): call_deferred("reveal_focused_field"))

func reveal_focused_field():
	var focused = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and is_ancestor_of(focused): ensure_control_visible(focused)

func _input(event: InputEvent):
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.device == -1 and dragging:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if tracking: return
			var scrolls = get_tree().get_nodes_in_group("paytrack_scrolls").filter(func(node): return node.is_visible_in_tree())
			if scrolls.is_empty() or scrolls.back() != self: return
			if not get_tree().get_nodes_in_group("paytrack_calendar").is_empty(): return
			if not get_global_rect().has_point(event.position): return
			tracking = true
			dragging = false
			finger = event.index
			origin = event.position
			previous = origin
			speed = 0
		elif tracking and event.index == finger:
			tracking = false
			if event.canceled: speed = 0
			if dragging:
				propagate_notification(Control.NOTIFICATION_SCROLL_END)
				scroll_ended.emit()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and tracking and event.index == finger:
		if not dragging and absf(event.position.y-origin.y) >= 12:
			dragging = true
			propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			scroll_started.emit()
		if dragging:
			var delta = previous.y-event.position.y
			scroll_vertical += roundi(delta)
			speed = clampf(-event.velocity.y,-1800,1800)
			get_viewport().set_input_as_handled()
		previous = event.position

func _process(delta: float):
	if not tracking and absf(speed) > 5:
		var before = scroll_vertical
		scroll_vertical += roundi(speed*delta)
		speed = move_toward(speed,0,2400*delta)
		if before == scroll_vertical: speed = 0
