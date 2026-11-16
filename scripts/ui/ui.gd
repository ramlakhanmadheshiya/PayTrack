class_name UI
extends RefCounted
## Design system: colours, type, and small builders for every screen.
## Calm, Apple-like, light mode only.

# Colours -------------------------------------------------------------------
const BG := Color("#F2F2F7")
const CARD := Color("#FFFFFF")
const TEXT := Color("#1C1C1E")
const TEXT2 := Color("#6C6C72")
const TEXT3 := Color("#A1A1A8")
const LINE := Color("#E4E4EA")
const FILL := Color("#EEEEF3")
const FILL_PRESSED := Color("#E2E2E8")
const ACCENT := Color("#1D4FB8")
const ACCENT_PRESSED := Color("#163F95")
const ACCENT_SOFT := Color("#E9EFFB")
const GREEN := Color("#16803C")
const GREEN_SOFT := Color("#E5F4EA")
const RED := Color("#C8321F")
const RED_SOFT := Color("#FBEAE7")
const ORANGE := Color("#B25E00")
const ORANGE_SOFT := Color("#FFF3E0")
const DIM := Color(0, 0, 0, 0.32)

# Type sizes (logical pixels) ------------------------------------------------
const S_LARGE_TITLE := 32
const S_TITLE := 22
const S_HEAD := 17
const S_BODY := 17
const S_SUB := 15
const S_CAP := 13
const S_MONEY_BIG := 34

const RADIUS := 14
const ROW_H := 52

static var _fonts := {}
static var app: Node  # main.gd – navigation, sheets, numpad, toast


static func font(weight := 400, tabular := false) -> Font:
	var key := "%d%s" % [weight, "t" if tabular else ""]
	if _fonts.has(key):
		return _fonts[key]
	var ts := TextServerManager.get_primary_interface()
	var deva := FontVariation.new()
	deva.base_font = load("res://assets/fonts/NotoSansDevanagari.ttf")
	deva.variation_opentype = {ts.name_to_tag("wght"): weight}
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Inter.ttf")
	var feats := {}
	if tabular:
		feats[ts.name_to_tag("tnum")] = 1
	f.opentype_features = feats
	f.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("opsz"): 20}
	f.fallbacks = [deva]
	_fonts[key] = f
	return f


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font(400)
	th.default_font_size = S_BODY
	th.set_color("font_color", "Label", TEXT)
	# Text input (names, notes, search).
	var le := box(CARD, 10, LINE, 1)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 12
	le.content_margin_bottom = 12
	var lef := le.duplicate()
	lef.border_color = ACCENT
	lef.set_border_width_all(2)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", lef)
	th.set_stylebox("read_only", "LineEdit", le)
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", TEXT3)
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT, 0.25))
	th.set_font_size("font_size", "LineEdit", S_BODY)
	# Scrollbars: thin and quiet.
	var sb := box(Color(0, 0, 0, 0.18), 3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	var empty := StyleBoxEmpty.new()
	for cls in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", cls, empty)
		th.set_stylebox("scroll_focus", cls, empty)
		th.set_stylebox("grabber", cls, sb)
		th.set_stylebox("grabber_highlight", cls, sb)
		th.set_stylebox("grabber_pressed", cls, sb)
	th.set_stylebox("panel", "PanelContainer", empty)
	th.set_stylebox("panel", "ScrollContainer", empty)
	th.set_stylebox("focus", "ScrollContainer", empty)
	th.set_constant("separation", "VBoxContainer", 0)
	th.set_constant("separation", "HBoxContainer", 0)
	return th


# Style boxes ----------------------------------------------------------------

static func box(bg: Color, radius := RADIUS, border := Color.TRANSPARENT, border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.anti_aliasing = true
	s.corner_detail = 10
	return s


static func pad(s: StyleBox, h: float, v: float) -> StyleBox:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s


# Basic nodes ----------------------------------------------------------------

static func ignore_mouse(n: Node) -> void:
	if n is Control:
		if not (n is LineEdit) and not (n is Tap):
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func let_scroll(n: Node) -> void:
	## Plain boxes (PanelContainer, ColorRect…) catch touches by default, so a
	## drag that starts on them never reaches the scroll view. Let them pass.
	if n is Control and n.mouse_filter == Control.MOUSE_FILTER_STOP:
		if not (n is Tap or n is BaseButton or n is LineEdit or n is TextEdit or n is ScrollContainer or n is Range):
			n.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		let_scroll(c)


static func label(text: String, size := S_BODY, color := TEXT, weight := 400, tabular := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, tabular))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40
	return l


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func ellipsis(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 30
	return l


static func money_label(amount: int, size := S_BODY, weight := 600, colored := false) -> Label:
	var c := TEXT
	if colored:
		c = GREEN if amount > 0 else (RED if amount < 0 else TEXT2)
	var l := label(Money.rs(amount), size, c, weight, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func vbox(sep := 0) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep := 0) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func spacer(h := 8.0, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func flex() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func line(indent := 16.0) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(indent))
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size.y = 1
	m.add_child(r)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


static func margin(c: Control, l := 16, t := 0, r := 16, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(c)
	return m


# Cards and sections -----------------------------------------------------------

static func card(inner_pad := 0.0) -> PanelContainer:
	## A white rounded group. Add rows to card.get_child(0).
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pad(box(CARD), inner_pad, inner_pad))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := vbox()
	p.add_child(v)
	return p


static func card_body(c: PanelContainer) -> VBoxContainer:
	return c.get_child(0)


static func section_title(text: String, right: Control = null) -> Control:
	var h := hbox(8)
	var l := label(text.to_upper() if Lang.lang == "en" else text, S_CAP, TEXT2, 600)
	h.add_child(l)
	h.add_child(flex())
	if right:
		h.add_child(right)
	return margin(h, 16, 22, 16, 8)


static func footnote(text: String) -> Control:
	return margin(wrapped(label(text, S_CAP, TEXT2)), 16, 8, 16, 0)


static func add_rows(c: PanelContainer, rows: Array) -> void:
	## Adds rows with hairlines between them.
	var body := card_body(c)
	var first_in_card := body.get_child_count() == 0
	for i in rows.size():
		if i > 0 or body.get_child_count() > 0:
			body.add_child(line())
		body.add_child(rows[i])
		# Pressed/hover highlight follows the card's rounded corners.
		if rows[i] is Tap:
			_round_row(rows[i], first_in_card and i == 0, i == rows.size() - 1)


static func _round_row(t: Tap, top: bool, bottom: bool) -> void:
	for st in [t.style_pressed, t.style_hover]:
		if st is StyleBoxFlat:
			st.corner_radius_top_left = RADIUS if top else 0
			st.corner_radius_top_right = RADIUS if top else 0
			st.corner_radius_bottom_left = RADIUS if bottom else 0
			st.corner_radius_bottom_right = RADIUS if bottom else 0


# Buttons --------------------------------------------------------------------

static func button(text: String, kind := "primary", cb: Callable = Callable(), icon := "") -> Tap:
	## kind: primary | secondary | plain | danger | tinted
	var t := Tap.new()
	var bg := ACCENT
	var bgp := ACCENT_PRESSED
	var fg := Color.WHITE
	match kind:
		"secondary":
			bg = FILL
			bgp = FILL_PRESSED
			fg = ACCENT
		"tinted":
			bg = ACCENT_SOFT
			bgp = Color("#D9E3F7")
			fg = ACCENT
		"plain":
			bg = Color(1, 1, 1, 0)
			bgp = FILL
			fg = ACCENT
		"danger":
			bg = RED_SOFT
			bgp = Color("#F6D5CF")
			fg = RED
		"white":
			bg = CARD
			bgp = FILL_PRESSED
			fg = ACCENT
	t.set_styles(pad(box(bg, 13), 18, 0), pad(box(bgp, 13), 18, 0), pad(box(bg.darkened(0.04) if kind != "plain" else FILL, 13), 18, 0))
	t.custom_minimum_size.y = 50
	var h := hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != "":
		h.add_child(Icons.make(icon, fg, 20))
	var l := label(text, S_HEAD, fg, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	t.add_child_ignoring(h)
	if cb.is_valid():
		t.tapped.connect(cb)
	return t


static func small_button(text: String, kind := "tinted", cb: Callable = Callable(), icon := "") -> Tap:
	var t := button(text, kind, cb, icon)
	t.custom_minimum_size.y = 36
	t.set_styles(pad(box(_kind_bg(kind), 18), 14, 0), pad(box(_kind_bg(kind).darkened(0.08), 18), 14, 0))
	var l: Label = t.get_child(0).get_child(t.get_child(0).get_child_count() - 1)
	l.add_theme_font_size_override("font_size", S_SUB)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return t


static func _kind_bg(kind: String) -> Color:
	match kind:
		"primary":
			return ACCENT
		"secondary":
			return FILL
		"danger":
			return RED_SOFT
		"plain":
			return Color(1, 1, 1, 0)
		"white":
			return CARD
	return ACCENT_SOFT


static func link(text: String, cb: Callable, color := ACCENT, size := S_BODY) -> Tap:
	var t := Tap.new()
	t.set_styles(pad(StyleBoxEmpty.new(), 6, 8), pad(box(FILL, 8), 6, 8))
	var l := label(text, size, color, 500)
	t.add_child_ignoring(l)
	t.tapped.connect(cb)
	return t


static func icon_button(icon: String, cb: Callable, color := ACCENT, size := 24) -> Tap:
	var t := Tap.new()
	t.set_styles(pad(StyleBoxEmpty.new(), 8, 8), pad(box(FILL, 20), 8, 8))
	t.custom_minimum_size = Vector2(44, 44)
	var c := CenterContainer.new()
	c.add_child(Icons.make(icon, color, size))
	t.add_child_ignoring(c)
	t.tapped.connect(cb)
	return t


# Rows -----------------------------------------------------------------------

static func row(title: String, subtitle := "", right: Variant = null, cb: Callable = Callable(), chevron := true, lead: Control = null) -> Control:
	## A list row like iOS Settings. `right` may be a String or a Control.
	var h := hbox(12)
	if lead:
		h.add_child(lead)
	var v := vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(ellipsis(label(title, S_BODY, TEXT, 500)))
	if subtitle != "":
		v.add_child(ellipsis(label(subtitle, S_SUB, TEXT2)))
	h.add_child(v)
	if right is String and right != "":
		h.add_child(label(right, S_BODY, TEXT2, 400, true))
	elif right is Control:
		h.add_child(right)
	if cb.is_valid() and chevron:
		h.add_child(Icons.make("chevron", TEXT3, 16))
	var min_h := ROW_H if subtitle == "" else 64
	if cb.is_valid():
		var t := Tap.new()
		t.set_styles(pad(StyleBoxEmpty.new(), 16, 8), pad(box(FILL_PRESSED, 0), 16, 8), pad(box(Color("#F7F7FA"), 0), 16, 8))
		t.custom_minimum_size.y = min_h
		t.add_child_ignoring(h)
		t.tapped.connect(cb)
		return t
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pad(StyleBoxEmpty.new(), 16, 8))
	p.custom_minimum_size.y = min_h
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	return p


static func kv(key: String, value: String, value_color := TEXT, weight := 400, size := S_BODY) -> Control:
	var h := hbox(12)
	h.add_child(ellipsis(label(key, size, TEXT2)))
	var r := label(value, size, value_color, weight, true)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h


static func badge(post: String) -> Control:
	var colors := {"BM": [Color("#F1E9FB"), Color("#6B3FA0")], "F": [ORANGE_SOFT, ORANGE], "H": [ACCENT_SOFT, ACCENT]}
	var c: Array = colors.get(post, [FILL, TEXT2])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pad(box(c[0], 7), 7, 2))
	var l := label(post, S_CAP, c[1], 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.custom_minimum_size = Vector2(34, 24)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func pill(text: String, bg: Color, fg: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pad(box(bg, 10), 9, 3))
	p.add_child(label(text, S_CAP, fg, 600))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func avatar(name: String, size := 40, bg := ACCENT_SOFT, fg := ACCENT) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, size / 2))
	p.custom_minimum_size = Vector2(size, size)
	var l := label(Lang.name_of(name).substr(0, 1).to_upper(), int(size * 0.42), fg, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func balance_text(b: int) -> String:
	if b > 0:
		return Lang.t("jama_short", [Money.group(b)])
	if b < 0:
		return Lang.t("advance_short", [Money.group(-b)])
	return Lang.t("clear")


static func balance_label(b: int, size := S_SUB) -> Label:
	var c := GREEN if b > 0 else (RED if b < 0 else TEXT3)
	var l := label(balance_text(b), size, c, 600, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func segmented(options: Array, selected: int, cb: Callable) -> Control:
	## iOS-style segmented control. options = [label, ...]; cb(index)
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", pad(box(FILL, 11), 3, 3))
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := hbox(2)
	outer.add_child(h)
	for i in options.size():
		var t := Tap.new()
		var on := i == selected
		var st: StyleBox = box(CARD, 9) if on else StyleBoxEmpty.new()
		if on:
			st.shadow_color = Color(0, 0, 0, 0.08)
			st.shadow_size = 3
			st.shadow_offset = Vector2(0, 1)
		var hp := 8 if options.size() < 4 else 3
		t.set_styles(pad(st, hp, 7), pad(box(CARD if on else FILL_PRESSED, 9), hp, 7))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_stretch_ratio = 1.0
		t.custom_minimum_size = Vector2(44, 36)
		var fs := S_SUB if options.size() < 4 else S_CAP + 1
		var l := label(options[i], fs, TEXT if on else TEXT2, 600 if on else 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.add_child_ignoring(l)
		var idx := i
		t.tapped.connect(func(): cb.call(idx))
		h.add_child(t)
	return outer


static func switch(on: bool, cb: Callable) -> Control:
	## iOS switch. cb(new_value)
	var t := Tap.new()
	t.set_styles(StyleBoxEmpty.new())
	t.custom_minimum_size = Vector2(52, 32)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := Panel.new()
	track.add_theme_stylebox_override("panel", box(GREEN if on else Color("#E3E3E8"), 16))
	track.custom_minimum_size = Vector2(52, 32)
	var knob := Panel.new()
	var ks := box(CARD, 14)
	ks.shadow_color = Color(0, 0, 0, 0.18)
	ks.shadow_size = 3
	ks.shadow_offset = Vector2(0, 1)
	knob.add_theme_stylebox_override("panel", ks)
	knob.size = Vector2(28, 28)
	knob.position = Vector2(22 if on else 2, 2)
	track.add_child(knob)
	t.add_child_ignoring(track)
	t.tapped.connect(func(): cb.call(not on))
	return t


static func search_field(placeholder: String, text: String, cb: Callable) -> TextField:
	## Search box typed with the in-app keyboard; cb(text) once typing pauses,
	## so long lists are not rebuilt on every key.
	var f := TextField.make(text, placeholder, placeholder, "search")
	f.capitalize_words = false
	f.text_settled.connect(cb)
	return f


static func text_field(placeholder: String, text := "", caption := "") -> TextField:
	return TextField.make(text, placeholder, caption)


static func empty_state(icon: String, title: String, body: String, action: Control = null) -> Control:
	var v := vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := CenterContainer.new()
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", box(ACCENT_SOFT, 36))
	circle.custom_minimum_size = Vector2(72, 72)
	var cc := CenterContainer.new()
	cc.add_child(Icons.make(icon, ACCENT, 32))
	circle.add_child(cc)
	ic.add_child(circle)
	v.add_child(spacer(24))
	v.add_child(ic)
	var t := label(title, S_HEAD, TEXT, 600)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := wrapped(label(body, S_SUB, TEXT2))
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	if action:
		var c := CenterContainer.new()
		c.add_child(action)
		v.add_child(spacer(4))
		v.add_child(c)
	v.add_child(spacer(24))
	return v


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
