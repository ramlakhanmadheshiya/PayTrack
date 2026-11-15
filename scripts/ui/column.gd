class_name Column
extends Container
## Holds one child, centred, never wider than max_width (readable on iPad/desktop).

var max_width := 720.0:
	set(v):
		max_width = v
		queue_sort()
var side := 16.0:
	set(v):
		side = v
		queue_sort()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var w: float = minf(size.x - side * 2.0, max_width)
		var x: float = (size.x - w) / 2.0
		for c in get_children():
			if c is Control and c.visible:
				fit_child_in_rect(c, Rect2(x, 0, w, size.y))


func _get_minimum_size() -> Vector2:
	var h := 0.0
	for c in get_children():
		if c is Control and c.visible:
			h = maxf(h, c.get_combined_minimum_size().y)
	return Vector2(0, h)
