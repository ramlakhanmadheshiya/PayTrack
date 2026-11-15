class_name Page
extends Control
## One screen in a navigation stack. Subclasses override build(body).
## refresh() rebuilds the content and keeps the scroll position.

var title := ""
var show_large_title := true
var tab := ""
var scroll: ScrollContainer
var body: VBoxContainer
var nav: HBoxContainer
var _top_holder: VBoxContainer
var _bottom_holder: VBoxContainer
var _dirty := false
var _scroll_reset := false


func scroll_top() -> void:
	## The next refresh starts at the top (e.g. moving to the next step).
	_scroll_reset = true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup() -> void:
	## Called once by the app after the page is placed in a stack.
	UI.clear(self)
	var root := UI.vbox()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_top_holder = UI.vbox()
	root.add_child(_top_holder)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 10
	scroll.follow_focus = true
	root.add_child(scroll)
	var col := Column.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.max_width = max_content_width()
	scroll.add_child(col)
	body = UI.vbox()
	col.add_child(body)
	# Content added later (lists filled after typing) must not block scrolling either.
	body.resized.connect(_let_scroll)
	_bottom_holder = UI.vbox()
	root.add_child(_bottom_holder)
	refresh()


func max_content_width() -> float:
	return 720.0


func refresh() -> void:
	if body == null:
		return
	var keep := 0 if _scroll_reset else scroll.scroll_vertical
	_scroll_reset = false
	UI.clear(body)
	UI.clear(_top_holder)
	UI.clear(_bottom_holder)
	# build() may set the title, so the header is made afterwards.
	build(body)
	_top_holder.add_child(_make_nav())
	if show_large_title and title != "":
		var t := UI.label(title, UI.S_LARGE_TITLE, UI.TEXT, 700)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var head := UI.hbox(8)
		head.add_child(UI.expand(t))
		var extra := title_accessory()
		if extra:
			head.add_child(extra)
		var hm := UI.margin(head, 16, 0, 16, 4)
		body.add_child(hm)
		body.move_child(hm, 0)
	body.add_child(UI.spacer(40))
	UI.let_scroll(body)
	var bottom := bottom_bar()
	if bottom:
		var p := PanelContainer.new()
		var s := UI.pad(UI.box(Color(UI.CARD, 0.97), 0), 16, 10)
		s.border_color = UI.LINE
		s.border_width_top = 1
		s.content_margin_bottom = 10 + UI.app.safe_bottom() if UI.app and not UI.app.has_tabbar_below() else 10
		p.add_theme_stylebox_override("panel", s)
		var col := Column.new()
		col.max_width = max_content_width()
		col.side = 0
		col.add_child(bottom)
		p.add_child(col)
		_bottom_holder.add_child(p)
	_restore_scroll.call_deferred(keep)


func _let_scroll() -> void:
	if is_instance_valid(body):
		UI.let_scroll(body)


func _restore_scroll(v: int) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = v


func _make_nav() -> Control:
	nav = UI.hbox(4)
	nav.custom_minimum_size.y = 48
	var can_back: bool = UI.app != null and UI.app.can_go_back(self)
	if can_back:
		var b := Tap.new()
		b.set_styles(UI.pad(StyleBoxEmpty.new(), 6, 6), UI.pad(UI.box(UI.FILL, 10), 6, 6))
		var h := UI.hbox(2)
		h.add_child(Icons.make("back", UI.ACCENT, 22))
		h.add_child(UI.label(back_label(), UI.S_BODY, UI.ACCENT, 500))
		b.add_child_ignoring(h)
		b.tapped.connect(func(): on_back())
		nav.add_child(b)
	if not show_large_title and title != "":
		var t := UI.label(title, UI.S_HEAD, UI.TEXT, 600)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.ellipsis(t)
		if not can_back:
			nav.add_child(UI.spacer(0, 8))
		nav.add_child(t)
	else:
		nav.add_child(UI.flex())
	var right := nav_right()
	if right:
		nav.add_child(right)
	else:
		nav.add_child(UI.spacer(0, 60 if can_back and not show_large_title else 0))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.pad(StyleBoxEmpty.new(), 8, 0))
	p.add_child(nav)
	var col := Column.new()
	col.max_width = max_content_width() + 16
	col.side = 0
	col.add_child(p)
	return col


func back_label() -> String:
	return Lang.t("back")


func on_back() -> void:
	UI.app.pop()


func title_accessory() -> Control:
	return null


func build(_b: VBoxContainer) -> void:
	pass


func nav_right() -> Control:
	return null


func bottom_bar() -> Control:
	return null


func on_shown() -> void:
	## Called when the page becomes visible again (e.g. after a pop).
	refresh()


func mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_dirty = false
	if is_inside_tree() and visible:
		refresh()
