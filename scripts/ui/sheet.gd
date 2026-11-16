class_name Sheet
extends Control
## A modal card: slides up from the bottom on phones, centred on iPad/desktop.
## Build content into `body`; header has Cancel (left) and an optional action (right).

signal closed

var title := ""
var action_text := ""
var action_cb: Callable
var cancel_text := ""
var body: VBoxContainer
var panel: PanelContainer
var scroll: ScrollContainer
var footer: VBoxContainer
var dismiss_on_dim := true
var _action_tap: Tap
var _bottom_inset := 0.0
var _closing := false
var _title_label: Label


func _init(t := "", action := "", cb: Callable = Callable()) -> void:
	title = t
	action_text = action
	action_cb = cb
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = UI.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if dismiss_on_dim and ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UI.vbox()
	panel.add_child(v)
	v.add_child(_header())
	v.add_child(UI.line(0))
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	body = UI.vbox(0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := UI.margin(body, 16, 12, 16, 16)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	footer = UI.vbox(0)
	v.add_child(footer)
	build()
	if _title_label:
		_title_label.text = Lang.show(title)
	get_viewport().size_changed.connect(_layout)
	body.resized.connect(_layout)
	footer.resized.connect(_layout)
	_layout.call_deferred()
	# Slide in.
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)


func build() -> void:
	pass


func set_bottom_inset(px: float) -> void:
	if absf(px - _bottom_inset) > 0.5:
		_bottom_inset = px
		_layout()


func _header() -> Control:
	var h := UI.hbox(8)
	h.custom_minimum_size.y = 54
	var cancel := UI.link(cancel_text if cancel_text != "" else Lang.t("cancel"), close, UI.ACCENT)
	h.add_child(cancel)
	var t := UI.label(title, UI.S_HEAD, UI.TEXT, 600)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.ellipsis(t)
	_title_label = t
	h.add_child(t)
	if action_text != "":
		_action_tap = UI.link(action_text, func(): if action_cb.is_valid(): action_cb.call(), UI.ACCENT)
		var l: Label = _action_tap.get_child(0)
		l.add_theme_font_override("font", UI.font(700))
		h.add_child(_action_tap)
	else:
		# Keep the title centred.
		var ghost := UI.label(cancel_text if cancel_text != "" else Lang.t("cancel"), UI.S_BODY, Color(0, 0, 0, 0))
		h.add_child(UI.margin(ghost, 6, 0, 6, 0))
	return UI.margin(h, 8, 0, 8, 0)


func set_action_enabled(on: bool) -> void:
	if _action_tap:
		_action_tap.enabled = on


func is_wide() -> bool:
	return get_viewport_rect().size.x >= 700


func _layout() -> void:
	if not is_inside_tree() or panel == null:
		return
	UI.let_scroll(body)
	var vp := get_viewport_rect().size
	var wide := is_wide()
	var w: float = minf(vp.x, 560.0) if wide else vp.x
	var safe_top: float = UI.app.safe_top() if UI.app else 0.0
	var max_h: float = vp.y - (60.0 if wide else 24.0 + safe_top) - _bottom_inset
	var content_h: float = body.get_combined_minimum_size().y + 28 + 55 + footer.get_combined_minimum_size().y
	var h: float = clampf(content_h, 200.0, max_h)
	var bottom_pad: float = 0.0 if wide else (UI.app.safe_bottom() if UI.app else 0.0)
	var st := UI.box(UI.BG, 16)
	if not wide:
		st.corner_radius_bottom_left = 0
		st.corner_radius_bottom_right = 0
	st.content_margin_bottom = bottom_pad
	st.shadow_color = Color(0, 0, 0, 0.12)
	st.shadow_size = 18
	panel.add_theme_stylebox_override("panel", st)
	panel.size = Vector2(w, h + bottom_pad)
	if wide:
		panel.position = Vector2((vp.x - w) / 2.0, maxf(30.0, (vp.y - h - _bottom_inset) / 2.0))
	else:
		panel.position = Vector2(0, vp.y - h - bottom_pad - _bottom_inset)


func close() -> void:
	if _closing:
		return
	_closing = true
	if UI.app:
		UI.app.numpad_close()
	closed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
