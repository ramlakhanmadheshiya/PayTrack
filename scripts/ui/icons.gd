class_name Icons
extends Control
## Line icons drawn in code (SF-Symbols-like), sharp at every screen size.

var icon := ""
var color := Color.BLACK
var px := 24.0


static func make(name: String, c: Color, size := 24.0) -> Icons:
	var i := Icons.new()
	i.icon = name
	i.color = c
	i.px = size
	i.custom_minimum_size = Vector2(size, size)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _p(x: float, y: float) -> Vector2:
	# Icons are designed on a 24 × 24 grid.
	return Vector2(x, y) * (px / 24.0)


func _l(pts: Array, w := 2.0) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p[0], p[1]))
	draw_polyline(arr, color, w * px / 24.0, true)


func _arc(cx: float, cy: float, r: float, a0: float, a1: float, w := 2.0) -> void:
	draw_arc(_p(cx, cy), r * px / 24.0, deg_to_rad(a0), deg_to_rad(a1), 40, color, w * px / 24.0, true)


func _circle(cx: float, cy: float, r: float, w := 2.0) -> void:
	_arc(cx, cy, r, 0, 360, w)


func _dot(cx: float, cy: float, r: float) -> void:
	draw_circle(_p(cx, cy), r * px / 24.0, color, true, -1.0, true)


func _rrect(x: float, y: float, w: float, h: float, r: float, lw := 2.0) -> void:
	_l([[x + r, y], [x + w - r, y]], lw)
	_l([[x + r, y + h], [x + w - r, y + h]], lw)
	_l([[x, y + r], [x, y + h - r]], lw)
	_l([[x + w, y + r], [x + w, y + h - r]], lw)
	_arc(x + r, y + r, r, 180, 270, lw)
	_arc(x + w - r, y + r, r, 270, 360, lw)
	_arc(x + w - r, y + h - r, r, 0, 90, lw)
	_arc(x + r, y + h - r, r, 90, 180, lw)


func _draw() -> void:
	match icon:
		"home":
			_l([[3, 11], [12, 3.5], [21, 11]])
			_l([[5.5, 9.5], [5.5, 20], [18.5, 20], [18.5, 9.5]])
			_l([[10, 20], [10, 14], [14, 14], [14, 20]])
		"mill":
			_l([[3, 20.5], [21, 20.5]])
			_l([[4, 20.5], [4, 11], [9, 14], [9, 11], [14, 14], [14, 7], [17, 7], [17, 20.5]])
			_l([[17, 7], [17, 4], [19.5, 4], [19.5, 20.5]])
		"people":
			_circle(9, 8, 3.5)
			_arc(9, 20, 6.5, 180, 360)
			_circle(17, 9, 2.6, 1.8)
			_arc(17, 19, 4.6, 230, 360, 1.8)
		"person":
			_circle(12, 8, 4)
			_arc(12, 21, 7.5, 180, 360)
		"balance":
			_rrect(3, 6, 18, 13, 3)
			_l([[3, 10], [21, 10]])
			_l([[15, 15], [18, 15]])
		"more":
			_dot(5, 12, 1.8)
			_dot(12, 12, 1.8)
			_dot(19, 12, 1.8)
		"gear":
			_circle(12, 12, 3)
			_circle(12, 12, 7.5)
		"plus":
			_l([[12, 5], [12, 19]])
			_l([[5, 12], [19, 12]])
		"minus":
			_l([[5, 12], [19, 12]])
		"chevron":
			_l([[9, 5], [16, 12], [9, 19]], 2.4)
		"chevron_down":
			_l([[6, 9], [12, 15], [18, 9]], 2.2)
		"back":
			_l([[15, 4], [7, 12], [15, 20]], 2.6)
		"check":
			_l([[5, 12.5], [10, 17.5], [19, 7]], 2.4)
		"check_circle":
			_circle(12, 12, 9)
			_l([[8, 12.3], [11, 15.3], [16.5, 9.2]], 2.2)
		"circle":
			_circle(12, 12, 9, 1.6)
		"close":
			_l([[6, 6], [18, 18]])
			_l([[18, 6], [6, 18]])
		"calendar":
			_rrect(3.5, 5, 17, 15, 3)
			_l([[3.5, 10], [20.5, 10]])
			_l([[8, 3], [8, 7]])
			_l([[16, 3], [16, 7]])
		"search":
			_circle(10.5, 10.5, 6)
			_l([[15, 15], [20, 20]], 2.4)
		"share":
			_l([[12, 3], [12, 14]])
			_l([[8, 7], [12, 3], [16, 7]])
			_l([[8, 10], [5.5, 10], [5.5, 20.5], [18.5, 20.5], [18.5, 10], [16, 10]])
		"export":
			_l([[12, 15], [12, 3]])
			_l([[7.5, 7.5], [12, 3], [16.5, 7.5]])
			_l([[4, 14], [4, 20], [20, 20], [20, 14]])
		"import":
			_l([[12, 3], [12, 15]])
			_l([[7.5, 10.5], [12, 15], [16.5, 10.5]])
			_l([[4, 14], [4, 20], [20, 20], [20, 14]])
		"trash":
			_l([[4, 6.5], [20, 6.5]])
			_l([[9, 6.5], [9, 3.5], [15, 3.5], [15, 6.5]])
			_l([[6, 6.5], [7, 20.5], [17, 20.5], [18, 6.5]])
		"edit":
			_l([[4, 20], [4.5, 16], [15.5, 5], [19, 8.5], [8, 19.5], [4, 20]])
			_l([[13.5, 7], [17, 10.5]])
		"rupee":
			_l([[7, 4.5], [18, 4.5]])
			_l([[7, 9], [18, 9]])
			_l([[7, 4.5], [11, 4.5]])
			_arc(10.5, 9, 4.5, -90, 90)
			_l([[10.5, 13.5], [7, 13.5], [15.5, 20.5]])
		"kharchi":
			_rrect(3, 6.5, 18, 11, 2.5)
			_circle(12, 12, 2.6, 1.8)
			_dot(6.5, 12, 1)
			_dot(17.5, 12, 1)
		"pay":
			_rrect(2.5, 5.5, 19, 13, 3)
			_l([[2.5, 9.5], [21.5, 9.5]])
			_l([[6, 14.5], [10, 14.5]])
		"family":
			_circle(7, 7.5, 2.6, 1.8)
			_circle(17, 7.5, 2.6, 1.8)
			_circle(12, 13, 2.2, 1.8)
			_arc(7, 18, 4.5, 200, 340, 1.8)
			_arc(17, 18, 4.5, 200, 340, 1.8)
			_arc(12, 22, 3.6, 200, 340, 1.8)
		"undo":
			_arc(13, 13, 6.5, -90, 120)
			_l([[13, 6.5], [6.5, 6.5]])
			_l([[9.5, 3.5], [6.5, 6.5], [9.5, 9.5]])
		"language":
			_circle(12, 12, 9, 1.8)
			_l([[3, 12], [21, 12]], 1.6)
			_arc(12, 12, 9, 0, 0, 1)
			_l([[12, 3], [12, 21]], 1.6)
		"info":
			_circle(12, 12, 9)
			_l([[12, 11], [12, 16.5]])
			_dot(12, 7.8, 1.3)
		"warning":
			_l([[12, 3.5], [21.5, 20], [2.5, 20], [12, 3.5]])
			_l([[12, 9.5], [12, 14]])
			_dot(12, 17, 1.2)
		"arrow_right":
			_l([[4, 12], [19, 12]])
			_l([[13, 6], [19, 12], [13, 18]])
		"history":
			_circle(12, 12, 8.5)
			_l([[12, 7], [12, 12], [15.5, 14]])
		"doc":
			_l([[6, 3], [14, 3], [19, 8], [19, 21], [6, 21], [6, 3]])
			_l([[14, 3], [14, 8], [19, 8]])
			_l([[9, 13], [16, 13]], 1.6)
			_l([[9, 16.5], [16, 16.5]], 1.6)
		"text_size":
			_l([[3, 19], [8, 6], [13, 19]])
			_l([[4.8, 14.5], [11.2, 14.5]])
			_l([[14, 19], [17.5, 11], [21, 19]], 1.6)
		_:
			_circle(12, 12, 8)
