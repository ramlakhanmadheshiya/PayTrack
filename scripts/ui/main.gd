extends Control
## App shell: tabs (phone) or sidebar (iPad / desktop), one navigation stack per
## tab, sheets, the number pad, toasts and screen scaling.

const TABS := ["home", "mills", "people", "balances", "more"]
const TAB_ICONS := {"home": "home", "mills": "mill", "people": "people", "balances": "balance", "more": "more"}
const WIDE := 820.0

var current_tab := "home"
var stacks := {}
var content: Control
var tabbar_holder: Control
var sidebar_holder: Control
var overlay: Control
var numpad: NumPad
var toast_holder: Control
var _wide := false
var _scale := 1.0
var _safe := Rect2()
var _refresh_queued := false
var _in_scale := false


func _ready() -> void:
	UI.app = self
	theme = UI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	get_window().size_changed.connect(_on_window_resized)
	_apply_scale()
	_build_shell()
	DB.changed.connect(_queue_refresh)
	Lang.changed.connect(_on_lang)
	for t in TABS:
		stacks[t] = []
	for t in TABS:
		_push_root(t)
	switch_tab("home")
	Platform.setup()


# ---------------------------------------------------------------------------
# Scaling: 1 logical pixel ≈ 1 iPhone point on every device.
# ---------------------------------------------------------------------------

func device_scale() -> float:
	var s := 1.0
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		s = float(r) if r != null else 1.0
	elif OS.get_name() == "Android":
		s = DisplayServer.screen_get_dpi() / 160.0
	else:
		s = DisplayServer.screen_get_scale()
	return clampf(s, 1.0, 4.0)


func _apply_scale() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	if px.x < 10 or px.y < 10:
		return
	var s := device_scale() * float(DB.setting("text_size", 1.0))
	# Never narrower than a small phone.
	s = minf(s, px.x / 340.0)
	s = maxf(s, 0.5)
	_scale = s
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(int(round(px.x / s)), int(round(px.y / s)))
	# Safe area (notch, home bar) in logical pixels.
	_safe = Rect2()
	if OS.has_feature("mobile"):
		var sa := DisplayServer.get_display_safe_area()
		var ss := DisplayServer.screen_get_size()
		_safe = Rect2(sa.position.x / s, sa.position.y / s, maxf(0, ss.x - sa.end.x) / s, maxf(0, ss.y - sa.end.y) / s)


func safe_top() -> float:
	return _safe.position.y


func safe_bottom() -> float:
	return _safe.size.y


func set_text_size(f: float) -> void:
	DB.set_setting("text_size", f)
	_apply_scale()
	_rebuild_all()


func _on_window_resized() -> void:
	if _in_scale or content == null:
		return
	_in_scale = true
	_apply_scale()
	_in_scale = false
	var w := get_viewport_rect().size.x >= WIDE
	if w != _wide:
		_rebuild_shell_layout()


# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------

func _build_shell() -> void:
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	tabbar_holder = Control.new()
	tabbar_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(tabbar_holder)
	sidebar_holder = Control.new()
	sidebar_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(sidebar_holder)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	# The number pad sits above sheets so it is never dimmed.
	numpad = NumPad.new()
	add_child(numpad)
	toast_holder = Control.new()
	toast_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_holder)
	resized.connect(_layout)
	_rebuild_shell_layout()


func _rebuild_shell_layout() -> void:
	_wide = get_viewport_rect().size.x >= WIDE
	_build_tabbar()
	_build_sidebar()
	_layout()


func is_wide() -> bool:
	return _wide


func has_tabbar_below() -> bool:
	return not _wide and _numpad_height() == 0.0


func _numpad_height() -> float:
	return numpad.get_combined_minimum_size().y if numpad.visible else 0.0


func _layout() -> void:
	var vp := get_viewport_rect().size
	var top := safe_top()
	var np_h := _numpad_height()
	var tab_h := 0.0
	if not _wide:
		tabbar_holder.visible = np_h == 0.0
		if tabbar_holder.visible and tabbar_holder.get_child_count() > 0:
			tab_h = tabbar_holder.get_child(0).get_combined_minimum_size().y
		tabbar_holder.position = Vector2(0, vp.y - tab_h)
		tabbar_holder.size = Vector2(vp.x, tab_h)
		if tabbar_holder.get_child_count() > 0:
			tabbar_holder.get_child(0).size = tabbar_holder.size
		sidebar_holder.visible = false
		content.position = Vector2(0, top)
		content.size = Vector2(vp.x, vp.y - top - tab_h - np_h)
	else:
		tabbar_holder.visible = false
		sidebar_holder.visible = true
		var sw := 260.0
		sidebar_holder.position = Vector2(0, 0)
		sidebar_holder.size = Vector2(sw, vp.y)
		if sidebar_holder.get_child_count() > 0:
			sidebar_holder.get_child(0).size = sidebar_holder.size
		content.position = Vector2(sw, top)
		content.size = Vector2(vp.x - sw, vp.y - top - np_h)
	if numpad.visible:
		var h := numpad.get_combined_minimum_size().y
		numpad.position = Vector2(0, vp.y - h)
		numpad.size = Vector2(vp.x, h)
	for s in overlay.get_children():
		if s is Sheet:
			s.set_bottom_inset(np_h)


func _tab_label(t: String) -> String:
	return Lang.t("tab_" + t)


func _build_tabbar() -> void:
	UI.clear(tabbar_holder)
	if _wide:
		return
	var p := PanelContainer.new()
	var st := UI.box(Color(0.985, 0.985, 0.99, 0.98), 0)
	st.border_color = UI.LINE
	st.border_width_top = 1
	st.content_margin_top = 6
	st.content_margin_bottom = 4 + safe_bottom()
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(0)
	p.add_child(h)
	for t in TABS:
		var on: bool = t == current_tab
		var tap := Tap.new()
		tap.set_styles(StyleBoxEmpty.new(), StyleBoxEmpty.new())
		tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tap.custom_minimum_size.y = 50
		var v := UI.vbox(3)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var c := CenterContainer.new()
		c.add_child(Icons.make(TAB_ICONS[t], UI.ACCENT if on else UI.TEXT3, 25))
		v.add_child(c)
		var l := UI.label(_tab_label(t), 11, UI.ACCENT if on else UI.TEXT3, 600 if on else 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		tap.add_child_ignoring(v)
		var tt: String = t
		tap.tapped.connect(func(): _on_tab_tapped(tt))
		h.add_child(tap)
	tabbar_holder.add_child(p)


func _build_sidebar() -> void:
	UI.clear(sidebar_holder)
	if not _wide:
		return
	var p := PanelContainer.new()
	var st := UI.box(Color("#F7F7FA"), 0)
	st.border_color = UI.LINE
	st.border_width_right = 1
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 18 + safe_top()
	p.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(4)
	p.add_child(v)
	var brand := UI.hbox(10)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(34, 34)
	brand.add_child(logo)
	brand.add_child(UI.label("PayTrack", 21, UI.TEXT, 700))
	v.add_child(UI.margin(brand, 8, 0, 8, 14))
	for t in TABS:
		var on: bool = t == current_tab
		var tap := Tap.new()
		var bg := UI.ACCENT_SOFT if on else Color(0, 0, 0, 0)
		tap.set_styles(UI.pad(UI.box(bg, 10), 12, 0), UI.pad(UI.box(UI.FILL_PRESSED, 10), 12, 0), UI.pad(UI.box(UI.ACCENT_SOFT if on else UI.FILL, 10), 12, 0))
		tap.custom_minimum_size.y = 44
		var h := UI.hbox(12)
		h.add_child(Icons.make(TAB_ICONS[t], UI.ACCENT if on else UI.TEXT2, 22))
		h.add_child(UI.label(_tab_label(t), UI.S_BODY, UI.ACCENT if on else UI.TEXT, 600 if on else 500))
		tap.add_child_ignoring(h)
		var tt: String = t
		tap.tapped.connect(func(): _on_tab_tapped(tt))
		v.add_child(tap)
	v.add_child(UI.spacer(16))
	var actions := UI.vbox(8)
	actions.add_child(UI.button(Lang.t("add_kharchi"), "primary", func(): Screens.open_entry_sheet(), "plus"))
	actions.add_child(UI.button(Lang.t("pay_someone"), "tinted", func(): Screens.start_pay_someone(), "pay"))
	v.add_child(UI.margin(actions, 4, 0, 4, 0))
	sidebar_holder.add_child(p)


func _on_tab_tapped(t: String) -> void:
	if t == current_tab:
		pop_to_root()
	else:
		switch_tab(t)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _push_root(t: String) -> void:
	var page: Page = Screens.root_page(t)
	page.tab = t
	stacks[t].append(page)
	page.visible = false
	content.add_child(page)
	page.setup()


func switch_tab(t: String) -> void:
	numpad_close()
	current_tab = t
	for tab in TABS:
		for p in stacks[tab]:
			p.visible = false
	var top: Page = stacks[t][-1]
	top.visible = true
	top.on_shown()
	_build_tabbar()
	_build_sidebar()
	_layout()


func top_page() -> Page:
	return stacks[current_tab][-1]


func can_go_back(p: Page) -> bool:
	var st: Array = stacks.get(p.tab, [])
	return st.size() > 1 and st.find(p) > 0


func push(page: Page) -> void:
	numpad_close()
	page.tab = current_tab
	top_page().visible = false
	stacks[current_tab].append(page)
	content.add_child(page)
	page.setup()
	page.visible = true
	# Gentle slide-in.
	page.position.x = 40
	page.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(page, "position:x", 0.0, 0.22)
	tw.tween_property(page, "modulate:a", 1.0, 0.18)


func pop() -> void:
	numpad_close()
	var st: Array = stacks[current_tab]
	if st.size() <= 1:
		return
	var p: Page = st.pop_back()
	p.queue_free()
	var top: Page = st[-1]
	top.visible = true
	top.on_shown()


func pop_to_root() -> void:
	numpad_close()
	var st: Array = stacks[current_tab]
	while st.size() > 1:
		st.pop_back().queue_free()
	st[0].visible = true
	st[0].on_shown()


func replace_top(page: Page) -> void:
	## Swap the current page for another (e.g. Pay → Done).
	var st: Array = stacks[current_tab]
	var old: Page = st.pop_back()
	old.queue_free()
	page.tab = current_tab
	st.append(page)
	content.add_child(page)
	page.setup()
	page.visible = true


func go_tab_root(t: String) -> void:
	switch_tab(t)
	pop_to_root()


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_refresh_queued = false
	if numpad.visible:
		return  # never rebuild a screen while someone is typing in it
	var p := top_page()
	if p.has_method("on_data_changed"):
		p.on_data_changed()
	else:
		p.refresh()


func _on_lang() -> void:
	_rebuild_all()


func _rebuild_all() -> void:
	_build_tabbar()
	_build_sidebar()
	# Hidden pages refresh themselves in on_shown().
	top_page().refresh()
	_layout()


# ---------------------------------------------------------------------------
# Sheets, toasts, confirmations
# ---------------------------------------------------------------------------

func present(s: Sheet) -> void:
	numpad_close()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(s)
	s.closed.connect(func(): _on_sheet_closed.call_deferred())


func _on_sheet_closed() -> void:
	var any := false
	for c in overlay.get_children():
		if c is Sheet and not c._closing:
			any = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP if any else Control.MOUSE_FILTER_IGNORE


func top_sheet() -> Sheet:
	for i in range(overlay.get_child_count() - 1, -1, -1):
		var c = overlay.get_child(i)
		if c is Sheet and not c._closing:
			return c
	return null


func toast(text: String, kind := "ok") -> void:
	UI.clear(toast_holder)
	var p := PanelContainer.new()
	var st := UI.pad(UI.box(Color("#1C1C1E") if kind != "error" else UI.RED, 22), 18, 11)
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(8)
	h.add_child(Icons.make("check" if kind != "error" else "warning", Color.WHITE, 18))
	h.add_child(UI.label(text, UI.S_SUB, Color.WHITE, 600))
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_holder.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var vp := get_viewport_rect().size
	var ms := p.get_combined_minimum_size()
	var bottom := 90.0 + safe_bottom() + _numpad_height()
	p.size = ms
	p.position = Vector2((vp.x - ms.x) / 2.0 + (130.0 if _wide else 0.0), vp.y - bottom - ms.y)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func confirm(title: String, message: String, ok_text: String, cb: Callable, danger := false, details: Control = null) -> void:
	var s := Sheet.new(title)
	s.cancel_text = Lang.t("cancel")
	var v := UI.vbox(14)
	if message != "":
		v.add_child(UI.wrapped(UI.label(message, UI.S_BODY, UI.TEXT2)))
	if details:
		v.add_child(details)
	v.add_child(UI.spacer(4))
	v.add_child(UI.button(ok_text, "danger" if danger else "primary", func(): s.close(); cb.call()))
	present(s)
	s.body.add_child(v)


# ---------------------------------------------------------------------------
# Number pad
# ---------------------------------------------------------------------------

func numpad_open(f: NumField) -> void:
	var was := numpad.visible
	numpad.attach(f)
	numpad.visible = true
	if not was:
		_build_tabbar()
	_layout()
	await get_tree().process_frame
	_layout()
	_ensure_visible(f)


func numpad_close() -> void:
	if numpad == null or not numpad.visible:
		return
	numpad.detach()
	numpad.visible = false
	_layout()
	_queue_refresh()


func _ensure_visible(f: Control) -> void:
	if not is_instance_valid(f):
		return
	var n: Node = f.get_parent()
	while n:
		if n is ScrollContainer:
			n.ensure_control_visible(f)
			return
		n = n.get_parent()


func numpad_neighbor(f: NumField, dir: int) -> NumField:
	var root: Node = top_sheet()
	if root == null:
		root = top_page()
	var list: Array = []
	_collect_fields(root, list)
	var i := list.find(f)
	if i < 0:
		return null
	var j := i + dir
	if j < 0 or j >= list.size():
		return null
	return list[j]


func _collect_fields(n: Node, out: Array) -> void:
	if n is NumField and n.is_visible_in_tree() and n.enabled:
		out.append(n)
	for c in n.get_children():
		_collect_fields(c, out)


func _unhandled_input(ev: InputEvent) -> void:
	# Android back button / Escape.
	if ev.is_action_pressed("ui_cancel"):
		var s := top_sheet()
		if s:
			s.close()
		elif stacks[current_tab].size() > 1:
			top_page().on_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var s := top_sheet()
		if s:
			s.close()
		elif numpad and numpad.visible:
			numpad_close()
		elif stacks.has(current_tab) and stacks[current_tab].size() > 1:
			top_page().on_back()
		elif current_tab != "home":
			switch_tab("home")
