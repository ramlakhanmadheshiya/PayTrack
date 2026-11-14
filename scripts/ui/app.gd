extends "res://scripts/ui/app_support.gd"
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const TextField = preload("res://scripts/ui/text_field.gd")
const DateField = preload("res://scripts/ui/date_field.gd")
const INK = Color("192436")
const MUTED = Color("758196")
const BLUE = Color("0877f9")
var test_mode = false
var batch_rows = []
var side: PanelContainer
var bottom: HBoxContainer
var page_scroll: ScrollContainer
var page_margin: MarginContainer
var top_title: Label
var nav_buttons = {}
var layout_grids: Array = []
var modal_layer: Control
var chosen_person = ""
var payment_state = {}
var current_section = ""
var toast_timer: Timer
var modal_message: Label
var stat_widgets = []
var action_tiles = []

func _ready():
	if OS.has_feature("web"):
		get_window().content_scale_factor = maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1")))
	make_theme()
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",0)
	add_child(root)
	side = PanelContainer.new()
	side.custom_minimum_size.x = 220
	side.add_theme_stylebox_override("panel",box(Color.WHITE,0,20))
	root.add_child(side)
	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation",8)
	side.add_child(menu)
	var brand = HBoxContainer.new()
	brand.add_theme_constant_override("separation",10)
	menu.add_child(brand)
	var logo = TextureRect.new()
	logo.texture = preload("res://assets/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(34,34)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(logo)
	var brand_title = label("PayTrack",22,INK)
	brand_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.add_child(brand_title)
	var tagline = label("Your everyday hisab-kitab",11,MUTED)
	tagline.custom_minimum_size.y = 40
	menu.add_child(tagline)
	for item in [["Home","Overview","home"],["Attendance","Attendance","attendance"],["History","Payments","pay"],["People","People & families","people"],["Money","Money book","money"]]:
		var nav = button(menu,item[1],func(): show_page(item[0]))
		nav.icon = icon(item[2])
		nav.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_theme_constant_override("h_separation",12)
		nav.add_theme_font_size_override("font_size",14)
		nav_buttons[item[0]] = nav
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(spacer)
	var settings = button(menu,"Settings",func(): show_page("Settings"))
	settings.icon = icon("settings")
	settings.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nav_buttons.Settings = settings
	menu.add_child(HSeparator.new())
	menu.add_child(label("Demo workspace",12,INK))
	menu.add_child(label("Records stay on this device.",11,MUTED))
	var main = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",0)
	root.add_child(main)
	var bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel",box(Color.WHITE,0,20))
	main.add_child(bar)
	var bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation",12)
	bar.add_child(bar_row)
	top_title = label("Overview",16,INK)
	top_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(top_title)
	var save = button(bar_row,"Save a backup",backup_now)
	save.icon = icon("backup")
	save.size_flags_horizontal = Control.SIZE_SHRINK_END
	save.custom_minimum_size.x = 160
	save.add_theme_font_size_override("font_size",13)
	save.custom_minimum_size.y = 40
	status = label("",14)
	status.visible = false
	status.custom_minimum_size.y = 38
	main.add_child(status)
	page_scroll = TouchScroll.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.follow_focus = true
	page_scroll.scroll_deadzone = 12
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(page_scroll)
	page_margin = MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",22)
	page_margin.add_child(body)
	bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation",2)
	main.add_child(bottom)
	for item in [["Home","Home","home"],["Attendance","Attendance","attendance"],["Pay","Pay","pay"],["People","People","people"],["More","More","more"]]:
		var nav = button(bottom,item[1],func(): show_page(item[0]))
		nav.text = ""
		var nav_center = CenterContainer.new()
		nav_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nav_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav.add_child(nav_center)
		var nav_content = VBoxContainer.new()
		nav_content.add_theme_constant_override("separation",4)
		nav_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_center.add_child(nav_content)
		var nav_icon = TextureRect.new()
		nav_icon.texture = icon(item[2])
		nav_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nav_icon.custom_minimum_size = Vector2(20,20)
		nav_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nav_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_content.add_child(nav_icon)
		var nav_label = label(item[1],10,MUTED)
		nav_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		nav_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_content.add_child(nav_label)
		nav.add_theme_font_size_override("font_size",11)
		nav.custom_minimum_size.y = 62
		nav_buttons["mobile_"+item[0]] = nav
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 8
	add_child(toast_timer)
	toast_timer.timeout.connect(func(): status.hide())
	var load_error = ""
	if not test_mode and not repo.load_data(): load_error = repo.error
	get_viewport().size_changed.connect(responsive)
	responsive()
	show_page("Home")
	if not load_error.is_empty(): notice("Your saved records could not be opened. Restore a backup from Settings. The old save has been kept.",true)

func box(color: Color, radius: int = 16, padding: int = 22, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	return style

func make_theme():
	var base = Theme.new()
	base.default_font = preload("res://assets/NotoSans.ttf")
	base.default_font_size = 15
	base.set_color("font_color","Label",INK)
	for control in ["Button","OptionButton"]:
		base.set_stylebox("normal",control,box(Color.WHITE,10,12,Color("e4e9f0")))
		base.set_stylebox("hover",control,box(Color("f0f6ff"),10,12,Color("d4e5fc")))
		base.set_stylebox("pressed",control,box(Color("e6f0ff"),10,12,Color("bcd6fa")))
		base.set_stylebox("focus",control,box(Color.TRANSPARENT,10,12,Color("8bbcff")))
		base.set_color("font_color",control,INK)
		base.set_color("font_hover_color",control,BLUE)
		base.set_color("font_pressed_color",control,BLUE)
		base.set_color("font_hover_pressed_color",control,BLUE)
		base.set_color("font_disabled_color",control,MUTED)
		base.set_color("font_focus_color",control,INK)
	for state in ["normal","read_only"]:
		base.set_stylebox(state,"LineEdit",box(Color("fafbfd"),9,12,Color("dfe5ee")))
	base.set_stylebox("focus","LineEdit",box(Color("f7fbff"),9,12,BLUE))
	base.set_color("font_color","LineEdit",INK)
	base.set_color("font_placeholder_color","LineEdit",Color("a2adbd"))
	base.set_stylebox("panel","PopupMenu",box(Color.WHITE,12,10,Color("dfe5ee")))
	base.set_stylebox("hover","PopupMenu",box(Color("edf4ff"),6,8))
	base.set_color("font_color","PopupMenu",INK)
	base.set_color("font_hover_color","PopupMenu",BLUE)
	base.set_constant("v_separation","PopupMenu",12)
	var separator = StyleBoxLine.new()
	separator.color = Color("e5eaf1")
	separator.thickness = 1
	base.set_stylebox("separator","HSeparator",separator)
	base.set_color("font_color","CheckBox",INK)
	base.set_color("font_hover_color","CheckBox",BLUE)
	base.set_stylebox("scroll","VScrollBar",box(Color("e6eaf0"),4,0))
	base.set_stylebox("grabber","VScrollBar",box(Color("c4cedb"),4,0))
	base.set_stylebox("grabber_highlight","VScrollBar",box(Color("aebdce"),4,0))
	theme = base

func icon(name: String) -> Texture2D:
	return load("res://assets/ui/"+name+".svg")

func narrow() -> bool:
	return get_viewport_rect().size.x < 900

func responsive():
	if not is_instance_valid(side): return
	if OS.has_feature("web"):
		var scale = maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1")))
		if not is_equal_approx(get_window().content_scale_factor,scale): get_window().content_scale_factor = scale
	side.visible = not narrow()
	bottom.visible = narrow()
	for edge in ["left","right","top","bottom"]:
		page_margin.add_theme_constant_override("margin_"+edge,20 if narrow() else 36)
	for grid in layout_grids:
		if is_instance_valid(grid.node):
			var width = get_viewport_rect().size.x
			grid.node.columns = 1 if width < grid.get("threshold",700) else (2 if grid.columns == 4 and width < 1200 else grid.columns)
	for widget in stat_widgets:
		if not is_instance_valid(widget.number): continue
		widget.number.add_theme_font_size_override("font_size",clampi(140 / maxi(1,widget.number.text.length()),12,20) if narrow() else 28)
		widget.caption.add_theme_font_size_override("font_size",11 if narrow() else 12)
		widget.panel.add_theme_stylebox_override("panel",box(Color.WHITE,14,12 if narrow() else 22,Color("e8edf3")))
	for tile in action_tiles:
		if is_instance_valid(tile): tile.custom_minimum_size.y = 94 if narrow() else 116
	if is_instance_valid(top_title): top_title.text = "PayTrack" if narrow() else page_title(current)

func label(value: String, size: int = 16, color: Color = INK) -> Label:
	var node = Label.new()
	node.text = tr(value)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	return node

func button(parent: Node, title: String, callback: Callable) -> Button:
	var node = Button.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.text = tr(title)
	node.custom_minimum_size.y = 46
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.clip_text = true
	parent.add_child(node)
	node.pressed.connect(callback)
	return node

func primary(parent: Node, title: String, callback: Callable) -> Button:
	var node = button(parent,title,callback)
	node.add_theme_stylebox_override("normal",box(BLUE,10,14))
	node.add_theme_stylebox_override("hover",box(Color("0066df"),10,14))
	node.add_theme_stylebox_override("pressed",box(Color("0057bd"),10,14))
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: node.add_theme_color_override(state,Color.WHITE)
	return node

func quiet(parent: Node, title: String, callback: Callable) -> Button:
	var node = button(parent,title,callback)
	node.add_theme_stylebox_override("normal",box(Color.TRANSPARENT,8,10))
	node.add_theme_color_override("font_color",BLUE)
	return node

func panel(parent: Node, title: String = "", subtitle: String = "") -> VBoxContainer:
	var shell = PanelContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel",box(Color.WHITE,16,22,Color("e8edf3")))
	parent.add_child(shell)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	shell.add_child(content)
	if not title.is_empty(): content.add_child(label(title,18))
	if not subtitle.is_empty(): content.add_child(label(subtitle,13,MUTED))
	return content

func card(title: String, subtitle: String = "") -> VBoxContainer:
	return panel(body,title,subtitle)

func grid(parent: Node, columns: int = 2, threshold: int = 700) -> GridContainer:
	var node = GridContainer.new()
	node.columns = 1 if get_viewport_rect().size.x < threshold else (2 if columns == 4 and get_viewport_rect().size.x < 1200 else columns)
	node.add_theme_constant_override("h_separation",18)
	node.add_theme_constant_override("v_separation",16)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	layout_grids.append({"node":node,"columns":columns,"threshold":threshold})
	return node

func column(parent: Node) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation",10)
	parent.add_child(node)
	return node

func input(parent: Node, title: String, value: String = "") -> LineEdit:
	var field = column(parent)
	field.add_child(label(title,13,MUTED))
	var node = TextField.new()
	node.text = value
	node.custom_minimum_size.y = 48
	field.add_child(node)
	return node

func amount_field(parent: Node, title: String, value: String = "") -> LineEdit:
	var node = input(parent,title,value)
	node.numeric = true
	node.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	node.placeholder_text = "₹ 0"
	return node

func date_input(parent: Node, title: String, value: String) -> PayTrackDateField:
	var field = column(parent)
	field.add_child(label(title,13,MUTED))
	var date = DateField.new()
	date.value = value
	field.add_child(date)
	return date

func select(parent: Node, title: String, collection: Array, title_field: String = "name") -> OptionButton:
	var field = column(parent)
	if not title.is_empty(): field.add_child(label(title,13,MUTED))
	var node = OptionButton.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.fit_to_longest_item = false
	node.clip_text = true
	node.custom_minimum_size.y = 48
	node.get_popup().max_size = Vector2i(0,400)
	field.add_child(node)
	for row in collection:
		node.add_item(row.get(title_field,""))
		node.set_item_metadata(node.item_count-1,row.id)
	if collection.is_empty():
		node.add_item("No people yet" if title.to_lower().contains("person") else "Nothing to choose yet")
		node.set_item_metadata(0,"")
		node.disabled = true
	return node

func choice(parent: Node, title: String, values: Array) -> OptionButton:
	var records = []
	for value in values: records.append({"id":value,"name":value})
	return select(parent,title,records)

func choose(node: OptionButton, key: String):
	for i in node.item_count:
		if str(node.get_item_metadata(i)) == key:
			node.select(i)
			return

func active_rows(collection: String) -> Array:
	return repo.data[collection].filter(func(row): return row.get("active",true))

func display_date(value: String) -> String:
	return DateField.display(value)

func page_title(page: String) -> String:
	return {"Home":"Overview","Pay":"Make a payment","History":"Payments","Money":"Money book","People":"People & families","More":"More"}.get(page,page)

func heading(title: String, subtitle: String = ""):
	var c = column(body)
	c.add_child(label(title,30 if not narrow() else 26))
	if not subtitle.is_empty(): c.add_child(label(subtitle,14,MUTED))

func clear_body():
	layout_grids = []
	stat_widgets = []
	action_tiles = []
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	page_scroll.scroll_vertical = 0

func show_page(page: String):
	current = page
	current_section = ""
	clear_body()
	status.hide()
	top_title.text = "PayTrack" if narrow() else page_title(page)
	for key in nav_buttons:
		var active = key.trim_prefix("mobile_") == page or (page == "Pay" and key == "History")
		nav_buttons[key].add_theme_stylebox_override("normal",box(Color("edf4ff") if active else Color.TRANSPARENT,9,12))
		nav_buttons[key].add_theme_color_override("font_color",BLUE if active else MUTED)
	match page:
		"Home": home()
		"People": people()
		"Attendance": attendance_page()
		"Money": money_page()
		"Pay": pay_page()
		"History": history_page()
		"Families": families_page()
		"Settings": settings_page()
		"More": more_page()

func notice(message: String, error: bool = false):
	if error and is_instance_valid(modal_layer) and is_instance_valid(modal_message):
		modal_message.text = friendly_error(message)
		modal_message.show()
	status.text = "   " + friendly_error(message)
	status.add_theme_color_override("font_color",Color("b44333") if error else Color("22744e"))
	status.show()
	if is_instance_valid(toast_timer):
		toast_timer.stop()
		if not error: toast_timer.start()

func friendly_error(message: String) -> String:
	return message.replace("Invalid range, before payroll start, or already paid period.","Check the dates. Attendance must be on or after the person’s pay start date, and after their last payment.").replace("Stale payment preview. Preview again.","The records changed. Please calculate this payment again.").replace("Invalid actual cash payment date", "Choose the date you gave the money").replace("Recovery exceeds outstanding advance.","The amount to recover is more than the remaining loan.").replace("Already paid through this date, or before payroll start.","This date has already been paid, or is before the person's start date.").replace("Duplicate normalized name", "This name is already in your list")

func commit_action(action: Callable, success: String, refresh: bool = true) -> bool:
	var before = repo.data.duplicate(true)
	if not action.call():
		repo.data = before
		notice(service.error,true)
		return false
	service.audit("account edit",current)
	if not repo.save():
		repo.data = before
		notice(repo.error,true)
		return false
	if refresh: show_page(current)
	notice(success)
	return true

func transact(action: Callable):
	commit_action(action,"Saved.")

func modal(title: String, subtitle: String = "") -> VBoxContainer:
	if is_instance_valid(modal_layer): modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = 100
	add_child(modal_layer)
	var dim = ColorRect.new()
	dim.color = Color(0.06,0.10,0.17,0.32)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+edge,18 if narrow() else 48)
	modal_layer.add_child(inset)
	var center = CenterContainer.new()
	inset.add_child(center)
	var shell = PanelContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	shell.custom_minimum_size.x = minf(520,get_viewport_rect().size.x-36)
	shell.add_theme_stylebox_override("panel",box(Color.WHITE,20,24))
	center.add_child(shell)
	var modal_scroll = TouchScroll.new()
	modal_scroll.custom_minimum_size.y = minf(520,maxf(80,get_viewport_rect().size.y-100))
	modal_scroll.follow_focus = true
	modal_scroll.scroll_deadzone = 12
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(modal_scroll)
	var c = VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation",16)
	c.custom_minimum_size.x = minf(472,get_viewport_rect().size.x-84)
	modal_scroll.add_child(c)
	c.add_child(label(title,23))
	if not subtitle.is_empty(): c.add_child(label(subtitle,14,MUTED))
	modal_message = label("",13,Color("b44333"))
	modal_message.hide()
	c.add_child(modal_message)
	c.minimum_size_changed.connect(func(): fit_modal(modal_scroll,c))
	var resize_modal = func():
		if is_instance_valid(inset):
			for edge in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+edge,18 if narrow() else 48)
		if is_instance_valid(shell): shell.custom_minimum_size.x = minf(520,get_viewport_rect().size.x-36)
		if is_instance_valid(c): c.custom_minimum_size.x = minf(472,get_viewport_rect().size.x-84)
		fit_modal(modal_scroll,c)
	get_viewport().size_changed.connect(resize_modal)
	c.tree_exiting.connect(func():
		if get_viewport().size_changed.is_connected(resize_modal): get_viewport().size_changed.disconnect(resize_modal))
	call_deferred("fit_modal",modal_scroll,c)
	return c

func fit_modal(scroll: ScrollContainer, content: VBoxContainer):
	if is_instance_valid(scroll) and is_instance_valid(content):
		scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y,maxf(80,get_viewport_rect().size.y-100))

func close_modal():
	if is_instance_valid(modal_layer):
		remove_child(modal_layer)
		modal_layer.queue_free()

func confirm(message: String, callback: Callable):
	var c = modal("Please check",message)
	primary(c,"Confirm",func():
		close_modal()
		callback.call())
	quiet(c,"Go back",close_modal)

func fold(parent: Node, title: String, build: Callable) -> VBoxContainer:
	var target = column(parent)
	var content = column(target)
	content.hide()
	var toggle = quiet(target,title + "  +",func():
		if content.get_child_count() == 0: build.call(content)
		content.visible = not content.visible)
	target.move_child(toggle,0)
	return content

func empty_state(parent: Node, title: String, description: String):
	var c = panel(parent)
	c.add_child(label(title,19))
	c.add_child(label(description,14,MUTED))
	return c

func home():
	heading("Today’s overview",display_date(today()))
	var intro = PanelContainer.new()
	intro.add_theme_stylebox_override("panel",box(Color("eaf3ff"),16,18))
	body.add_child(intro)
	var intro_row = HBoxContainer.new()
	intro.add_child(intro_row)
	var message = label("Demo workspace · Your entries stay on this device. Save a backup to keep a copy.",13,Color("45698f"))
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_row.add_child(message)
	if repo.data.persons.is_empty():
		var welcome = card("Let's get your book ready","Add the people you pay and the mills they work at. You can then enter attendance and check the exact amount to pay.")
		var steps = grid(welcome,2,620)
		var people_step = panel(steps,"1. Add your people","A name and the date their pay starts.")
		primary(people_step,"+ Add a person",func(): person_form())
		var mill_step = panel(steps,"2. Add a mill","Set the fireman and helper rates once.")
		button(mill_step,"+ Add a mill",func(): mill_form())
		quiet(welcome,"Just exploring? Try sample people",seed_demo)
		return
	var actions = grid(body,3,680)
	for item in [["Attendance","attendance","Attendance","Enter shifts received from a mill."],["Pay","pay","Payments","Check the amount and pay someone."],["Money","money","Money book","Add kharchi, advance or jama."]]:
		quick_action(actions,item[2],item[3],item[0],item[1])
	var totals = grid(body,3,0)
	var paid = 0
	var payment_count = 0
	for payment in repo.data.settlements:
		if not payment.cancelled and payment.paid_date.left(7) == today().left(7):
			paid += int(payment.cash)
			payment_count += 1
	var unpaid = {}
	for row in repo.data.attendance:
		if row.settlement_id.is_empty(): unpaid[row.person_id] = true
	for metric in [[str(active_rows("persons").size()),"People"],[str(unpaid.size()),"Unpaid work"],[P.money(paid),"Paid this month"]]:
		var c = panel(totals)
		if narrow(): c.get_parent().add_theme_stylebox_override("panel",box(Color.WHITE,14,12,Color("e8edf3")))
		var number = label(metric[0],clampi(140 / maxi(1,str(metric[0]).length()),12,20) if narrow() else 28)
		number.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.add_child(number)
		var caption = label(metric[1],11 if narrow() else 12,MUTED)
		c.add_child(caption)
		stat_widgets.append({"number":number,"caption":caption,"panel":c.get_parent()})
	var lower = grid(body,2,1000)
	var ready = panel(lower,"People to pay")
	var ready_count = 0
	for who in active_rows("persons"):
		if not who.family_id.is_empty(): continue
		var slip = service.preview(who.id,today())
		if slip.has("error") or int(slip.totals.net) <= 0: continue
		person_row(ready,who.name,"Through " + display_date(today()),P.money(int(slip.totals.net)),func(): open_pay(who.id))
		ready_count += 1
		if ready_count >= 4: break
	for family in active_rows("families"):
		if ready_count >= 4: break
		var family_pay = service.family_preview(family.id,today())
		if family_pay.has("error") or int(family_pay.net) <= 0: continue
		person_row(ready,family.name,"Family payment",P.money(int(family_pay.net)),func(): open_pay(family.id))
		ready_count += 1
	if ready_count == 0: ready.add_child(label("No pending amount yet. Add attendance to get started.",14,MUTED))
	var recent = panel(lower,"Recent payments")
	var payments = repo.data.settlements.filter(func(item): return not item.cancelled)
	payments.reverse()
	for payment in payments.slice(0,4):
		person_row(recent,payment_name(payment),display_date(payment.paid_date),P.money(int(payment.cash)),func(): receipt(payment))
	if payments.is_empty(): recent.add_child(label("Your recorded payments will appear here.",14,MUTED))
	quiet(recent,"View all payments",func(): show_page("History"))

func person_row(parent: Node, title: String, subtitle: String, action: String, callback: Callable):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var details = column(row)
	details.add_child(label(title,15))
	details.add_child(label(subtitle,12,MUTED))
	var next = quiet(row,action,callback)
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.custom_minimum_size.x = 80
	parent.add_child(HSeparator.new())

func payment_name(payment: Dictionary) -> String:
	if not payment.get("family_name","").is_empty(): return payment.family_name
	return payment.slips[0].name if not payment.slips.is_empty() else "Payment"

func open_pay(key: String = ""):
	chosen_person = key
	show_page("Pay")

func backup_now():
	repo.data.settings.last_backup_at = Time.get_datetime_string_from_system(true)
	if not repo.save():
		notice(repo.error,true)
		return
	download(repo.backup(),"paytrack-backup.json","application/json")
	notice("Backup downloaded. Keep the file somewhere safe.")

func people():
	heading("People & families","Everyone you work with, in one simple list.")
	var tabs = HBoxContainer.new()
	body.add_child(tabs)
	button(tabs,"People",func(): show_page("People"))
	quiet(tabs,"Families",func(): show_page("Families"))
	var c = card("Your people")
	primary(c,"+ Add a person",func(): person_form())
	var search = input(c,"Find a person")
	search.placeholder_text = "Search by name or person number"
	var list = column(c)
	var refresh = func(query: String):
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		var found = service.search(query)
		if found.is_empty(): list.add_child(label("No people found. Add a person or try another name.",14,MUTED))
		for who in found:
			var detail = who.id + (" · Inactive" if not who.active else "")
			if not who.family_id.is_empty(): detail += " · " + repo.find("families",who.family_id).get("name","Family")
			person_row(list,who.name,detail,"View",func(): person_detail(repo.find("persons",who.id)))
	search.text_changed.connect(refresh)
	refresh.call("")

func person_form(key: String = ""):
	var who = repo.find("persons",key)
	var c = modal("Add a person" if who.is_empty() else "Edit person")
	var name = input(c,"Name",who.get("name",""))
	name.placeholder_text = "Full name"
	primary(c,"Add person" if who.is_empty() else "Save changes",func():
		var success = commit_action(func():
			if key.is_empty():
				# Ordinary workers need only a name. Salary eligibility is configured separately.
				return service.person(name.text,today().substr(0,7)+"-01")
			var person = repo.find("persons",key)
			var clean = " ".join(name.text.replace("\t"," ").replace("\n"," ").split(" ",false)).strip_edges()
			if clean.is_empty(): return service.fail("Please enter a name.")
			for other in repo.data.persons:
				if other.id != key and other.name.to_lower() == clean.to_lower(): return service.fail("This name is already in your list. Add a suffix to distinguish this person.")
			service.audit("person changed",person.duplicate(true))
			person.name = clean
			return true,"Person added." if key.is_empty() else "Person updated.")
		if success: close_modal())
	quiet(c,"Cancel",close_modal)

func pay_start_form(key: String):
	var who = repo.find("persons",key)
	var c = modal("First pay period", "Only change this when entering older work or setting a different first pay period.")
	var start = date_input(c,"Pay starts from",who.payroll_start_date)
	primary(c,"Save pay period",func():
		if commit_action(func():
			if not who.paid_up_to.is_empty(): return service.fail("The first pay period is fixed after a payment.")
			for row in repo.data.attendance:
				if row.person_id == key and row.start < start.value: return service.fail("The date would leave out saved attendance.")
			service.audit("pay start changed",who.duplicate(true))
			who.payroll_start_date = start.value
			return true,"Pay period updated."): close_modal())
	quiet(c,"Cancel",close_modal)

func person_detail(who: Dictionary):
	clear_body()
	var key: String = who.id
	quiet(body,"‹ Back to people",func(): show_page("People"))
	heading(who.name,who.id + " · Pay starts " + display_date(who.payroll_start_date))
	var c = card("At a glance")
	c.add_child(label("Paid through " + display_date(who.paid_up_to) if not who.paid_up_to.is_empty() else "No payment recorded yet",14,MUTED))
	var actions = grid(c,2)
	primary(actions,"Make a payment",func(): open_pay(who.family_id if not who.family_id.is_empty() else key))
	button(actions,"Edit details",func(): person_form(key))
	var pending = card("Attendance")
	var count = 0
	for row in repo.data.attendance:
		if row.person_id != key: continue
		attendance_summary(pending,row)
		count += 1
	if count == 0: pending.add_child(label("No attendance entered yet.",14,MUTED))
	var money = card("Money entries")
	for entry in repo.data.ledger:
		if entry.person_id == key: money_summary(money,entry)
	fold(body,"More options",func(options):
		if who.paid_up_to.is_empty(): button(options,"Change first pay period",func(): pay_start_form(key))
		button(options,"Mark inactive" if who.active else "Make active",func(): confirm("Change " + who.name + "'s active status? Their old records will be kept.",func(): commit_action(func():
			var person = repo.find("persons",key)
			person.active = not person.active
			return true,"Person updated."))))

func attendance_page():
	heading("Add attendance","Choose a mill and period, then enter the shifts you received.")
	if active_rows("persons").is_empty() or active_rows("mills").is_empty():
		var empty = empty_state(body,"A quick setup first","Add your people and a mill before entering attendance.")
		primary(empty,"Add a person",func(): person_form())
		button(empty,"Set up a mill",func(): mill_form())
		return
	var c = card("1. Mill and dates")
	var mill = select(c,"Mill",active_rows("mills"))
	var dates = grid(c,2)
	var start = date_input(dates,"From",today().left(8)+"01")
	var end = date_input(dates,"Through",today())
	var workers = card("2. People and shifts","One attendance is one 12-hour shift. Use 0.5 for a half shift.")
	var rows_box = column(workers)
	batch_rows = []
	var add_row = func():
		var wrapper = PanelContainer.new()
		wrapper.add_theme_stylebox_override("panel",box(Color("f7f9fc"),12,16))
		rows_box.add_child(wrapper)
		var row_box = column(wrapper)
		var first = grid(row_box,4,600)
		var who = select(first,"Person",active_rows("persons"))
		var role = choice(first,"Work",["Fireman","Helper","Boiler master"])
		var numbers = first
		var units = input(numbers,"Attendances","")
		units.placeholder_text = "e.g. 26 or 26.5"
		units.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		var hours_box = column(numbers)
		var hours = input(hours_box,"Extra hours (if any)","")
		hours.placeholder_text = "0"
		hours.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		var rate_label = label("",12,MUTED)
		row_box.add_child(rate_label)
		var row = {"person":who,"role":role,"units":units,"hours":hours,"wrapper":wrapper}
		batch_rows.append(row)
		var remove = quiet(row_box,"Remove this person",func():
			if batch_rows.size() <= 1:
				notice("Keep at least one person in this entry.",true)
				return
			batch_rows.erase(row)
			wrapper.queue_free()
			for other in batch_rows: other.remove.visible = batch_rows.size() > 1)
		row.remove = remove
		for other in batch_rows: other.remove.visible = batch_rows.size() > 1
		var update = func(_unused = 0):
			var post = ["F","H","BM"][role.selected]
			hours_box.visible = post != "BM"
			var value = service.effective("rates","mill_id",selected(mill),start.value,post)
			rate_label.text = "Fixed monthly salary. Attendance is used for extra shifts." if post == "BM" else P.money(int(value.get("amount",0))) + " per attendance · rate filled for you"
		role.item_selected.connect(update)
		mill.item_selected.connect(update)
		start.date_changed.connect(update)
		update.call()
	button(workers,"+ Add another person",add_row)
	add_row.call()
	primary(workers,"Save attendance",func(): save_attendance(selected(mill),start.value,end.value,false))
	fold(body,"View previous attendance",func(list):
		var rows = repo.data.attendance.duplicate()
		rows.reverse()
		for row in rows.slice(0,30): attendance_summary(list,row))

func save_attendance(mill: String, start: String, end: String, allow_overlap: bool):
	var success = commit_action(func():
		for row in batch_rows:
			var units = decimal_units(row.units.text,2)
			var minutes = decimal_units("0" if row.hours.text.is_empty() else row.hours.text,60)
			var role = ["F","H","BM"][row.role.selected]
			if units < 0 or minutes < 0: return service.fail("Enter attendances in halves (such as 26.5) and extra hours in quarters (such as 1.25).")
			if not service.attendance(selected(row.person),mill,role,start,end,units,0 if role == "BM" else minutes,allow_overlap): return false
		return true,"Attendance saved.",false)
	if success:
		show_page("Attendance")
		notice("Attendance saved. You can add the next batch.")
	elif service.error.begins_with("Overlapping") and not allow_overlap:
		confirm("There is already attendance for this person, mill and work during these dates. Save this as an additional entry?",func(): save_attendance(mill,start,end,true))

func attendance_summary(parent: Node, row: Dictionary):
	var who = repo.find("persons",row.person_id)
	var name = who.get("name",row.person_id)
	var mill = repo.find("mills",row.mill_id).get("name",row.mill_id)
	var description = mill + " · " + {"F":"Fireman","H":"Helper","BM":"Boiler master"}.get(row.role,row.role) + " · " + str(int(row.half_units)/2.0) + " shifts"
	var date_range = display_date(row.start)+" – "+display_date(row.end)
	person_row(parent,name,description+"\n"+date_range,"Edit" if row.settlement_id.is_empty() else "Paid",func():
		if row.settlement_id.is_empty(): attendance_edit(row.id)
		else: notice("This attendance is part of a recorded payment and cannot be changed.",true))

func attendance_edit(key: String):
	var row = repo.find("attendance",key)
	var c = modal("Change attendance",repo.find("persons",row.person_id).name)
	var dates = grid(c,2)
	var start = date_input(dates,"From",row.start)
	var end = date_input(dates,"Through",row.end)
	var units = input(c,"Attendances",str(int(row.half_units)/2.0))
	var hours = input(c,"Extra hours",str(int(row.minutes)/60.0))
	hours.get_parent().visible = row.role != "BM"
	var reason = input(c,"Reason for this change")
	primary(c,"Save changes",func():
		if commit_action(func(): return service.edit_attendance(key,start.value,end.value,decimal_units(units.text,2),decimal_units(hours.text,60),reason.text),"Attendance updated."): close_modal())
	if row.role != "BM": quiet(c,"Correct the rate for this entry",func(): rate_form(key))
	quiet(c,"Split this entry for an early payment",func(): split_form(key,today()))
	quiet(c,"Cancel",close_modal)

func split_form(key: String, through: String, after: Callable = Callable()):
	var row = repo.find("attendance",key)
	var c = modal("Attendance before the pay date","This entry covers " + display_date(row.start) + " to " + display_date(row.end) + ". Enter the actual shifts worked in the first part.")
	var date = date_input(c,"First part ends",through if through >= row.start and through < row.end else row.start)
	var units = input(c,"Attendances in the first part")
	var hours = input(c,"Extra hours in the first part","0")
	hours.get_parent().visible = row.role != "BM"
	c.add_child(label("The remaining shifts stay for the next payment. The total amount is kept the same.",12,MUTED))
	primary(c,"Split attendance",func():
		if commit_action(func(): return service.split(key,date.value,decimal_units(units.text,2),decimal_units(hours.text,60)),"Attendance split.",false):
			close_modal()
			if after.is_valid(): after.call()
			else: show_page("Attendance"))
	quiet(c,"Go back",close_modal)

var money_kind = "kharchi"

func money_page():
	heading("Money book","Keep track of money given and money held.")
	var types = HBoxContainer.new()
	types.add_theme_constant_override("separation",6)
	body.add_child(types)
	for kind in [["kharchi","Kharchi"],["advance","Advance"],["jama","Jama"]]:
		var pick = button(types,kind[1],func():
			money_kind = kind[0]
			show_page("Money"))
		if money_kind == kind[0]:
			pick.add_theme_stylebox_override("normal",box(Color("eaf3ff"),10,12,Color("a8cdff")))
			pick.add_theme_color_override("font_color",BLUE)
	var description = {"kharchi":"Money already given for food, water or daily expenses. This is deducted at payment.","advance":"Money lent to a person. Choose how much to recover from each payment.","jama":"Money that belongs to the person and is held by you. This is added at payment."}
	var c = card("Add " + money_kind.capitalize(),description[money_kind])
	var who = select(c,"Person",active_rows("persons"))
	var inputs = grid(c,2)
	var amount = amount_field(inputs,"Amount")
	var date = date_input(inputs,"Date",today())
	var installment: LineEdit
	if money_kind == "advance": installment = amount_field(c,"Recover from each payment (optional)")
	primary(c,"Save " + money_kind,func():
		if not amount.text.is_valid_int() or (is_instance_valid(installment) and not installment.text.is_empty() and not installment.text.is_valid_int()):
			notice("Enter an amount in whole rupees.",true)
			return
		var recovery = int(installment.text) if is_instance_valid(installment) else 0
		commit_action(func(): return service.ledger(selected(who),money_kind,int(amount.text),date.value,recovery),money_kind.capitalize()+" saved."))
	if money_kind == "kharchi": quiet(c,"Add daily kharchi for several people",bulk_money_form)
	var recent = card("Recent money entries")
	var entries = repo.data.ledger.duplicate()
	entries.reverse()
	for entry in entries.slice(0,8): money_summary(recent,entry)
	if entries.is_empty(): recent.add_child(label("Your money entries will appear here.",14,MUTED))

func money_summary(parent: Node, entry: Dictionary):
	var title = repo.find("persons",entry.person_id).get("name",entry.person_id)
	var subtitle = entry.kind.capitalize()+" · "+display_date(entry.date)
	person_row(parent,title,subtitle,P.money(int(entry.amount)),func(): money_edit(entry.id))

func money_edit(key: String):
	var entry = repo.find("ledger",key)
	var c = modal(entry.kind.capitalize()+" · "+repo.find("persons",entry.person_id).name)
	if not entry.settlement_id.is_empty() or int(entry.recovered) > 0:
		c.add_child(label("This entry has already been used in a payment. Its original record is kept.",14,MUTED))
		c.add_child(label(P.money(int(entry.amount)),28))
		quiet(c,"Close",close_modal)
		return
	var amount = amount_field(c,"Amount",str(int(entry.amount)))
	var date = date_input(c,"Date",entry.date)
	var installment = amount_field(c,"Recover per payment",str(int(entry.installment)))
	installment.get_parent().visible = entry.kind == "advance"
	var reason = input(c,"Reason for the correction")
	primary(c,"Save changes",func():
		if not amount.text.is_valid_int() or not installment.text.is_valid_int():
			notice("Enter whole rupees.",true)
			return
		if commit_action(func(): return service.edit_ledger(key,int(amount.text),date.value,int(installment.text),reason.text),"Money entry updated."): close_modal())
	quiet(c,"Cancel",close_modal)

func bulk_money_form():
	var c = modal("Daily kharchi","Choose the people and dates. We will work out the total for you.")
	var options = []
	for person in active_rows("persons"):
		var item = CheckBox.new()
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.text = person.name
		item.custom_minimum_size.y = 44
		c.add_child(item)
		options.append({"node":item,"id":person.id})
	var dates = grid(c,2)
	var start = date_input(dates,"From",today())
	var end = date_input(dates,"Through",today())
	var amount = amount_field(c,"Per person, per day")
	var total = label("Choose people and enter a daily amount.",14,BLUE)
	c.add_child(total)
	var refresh = func(_unused = ""):
		var people_count = 0
		for item in options:
			if item.node.button_pressed: people_count += 1
		var days = maxi(0,P.day(end.value)-P.day(start.value)+1)
		if amount.text.is_valid_int() and int(amount.text) >= 0 and int(amount.text) <= P.MAX_VALUE:
			total.text = "%d people × %d days = %s" % [people_count,days,P.money(people_count*days*int(amount.text))]
	for item in options: item.node.toggled.connect(refresh)
	start.date_changed.connect(refresh)
	end.date_changed.connect(refresh)
	amount.text_changed.connect(refresh)
	primary(c,"Save daily kharchi",func():
		var ids = []
		for item in options:
			if item.node.button_pressed: ids.append(item.id)
		if ids.is_empty() or not amount.text.is_valid_int():
			notice("Choose at least one person and enter the daily amount.",true)
			return
		if commit_action(func(): return service.bulk_kharchi(ids,start.value,end.value,int(amount.text)),"Daily kharchi saved."): close_modal())
	quiet(c,"Cancel",close_modal)

func payees() -> Array:
	var result = []
	for person in active_rows("persons"):
		if person.family_id.is_empty(): result.append(person)
	for family in active_rows("families"): result.append(family)
	return result

func pay_page():
	heading("Make a payment","Choose who to pay and the last day to include.")
	if payees().is_empty():
		var empty = empty_state(body,"Add someone first","Once a person is in your book, you can calculate their pay here.")
		primary(empty,"+ Add a person",func(): person_form())
		return
	var c = card("Who are you paying?")
	var all_payees = payees()
	var search = input(c,"Find a person or family")
	search.placeholder_text = "Type a name"
	search.get_parent().visible = all_payees.size() > 6
	var who = select(c,"Person or family",all_payees)
	choose(who,chosen_person)
	search.text_changed.connect(func(query):
		who.clear()
		for person in all_payees:
			if query.is_empty() or person.name.to_lower().contains(query.to_lower()) or person.id.to_lower().contains(query.to_lower()):
				who.add_item(person.name)
				who.set_item_metadata(who.item_count-1,person.id))
	var end = date_input(c,"Pay through",today())
	var period = label("",13,MUTED)
	c.add_child(period)
	var update = func(_unused = 0):
		var person = repo.find("persons",selected(who))
		if person.is_empty():
			period.text = "One payment for the whole family, with each person's details."
		else:
			var start: String = person.payroll_start_date if person.paid_up_to.is_empty() else P.date_from_day(P.day(person.paid_up_to)+1)
			period.text = "Includes work from " + display_date(start) + ". Earlier recorded payments are already taken care of."
	who.item_selected.connect(update)
	update.call()
	primary(c,"Calculate payment",func(): prepare_payment(selected(who),end.value))
	quiet(c,"View past payments",func(): show_page("History"))

func calculate_payment(key: String, end: String, overrides: Dictionary = {}) -> Dictionary:
	if key.begins_with("FAM"):
		return service.family_preview(key,end,overrides)
	var options: Dictionary = overrides.get(key,{})
	var slip = service.preview(key,end,int(options.get("recovery",-1)),int(options.get("cash",-1)))
	if slip.has("error"): return slip
	return {"slips":[slip],"cash":slip.totals.cash,"net":slip.totals.net,"family_id":""}

func prepare_payment(key: String, end: String, overrides: Dictionary = {}):
	if key.is_empty():
		notice("Choose the person or family you want to pay.",true)
		return
	var ids = [key]
	if key.begins_with("FAM"): ids = repo.find("families",key).get("members",[])
	for row in repo.data.attendance:
		if row.person_id in ids and row.settlement_id.is_empty() and row.start <= end and row.end > end:
			split_form(row.id,end,func(): prepare_payment(key,end,overrides))
			return
	var result = calculate_payment(key,end,overrides)
	if result.has("error"):
		notice(result.error,true)
		return
	payment_state = {"key":key,"end":end,"result":result,"controls":{},"paid_date":today()}
	payment_review()

func money_line(parent: Node, title: String, amount: int, emphasis: bool = false) -> Label:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var caption = label(title,18 if emphasis else 14,INK if emphasis else MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var value = label(P.money(amount),22 if emphasis else 16,INK)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value

func combined_totals(slips: Array) -> Dictionary:
	var totals = {"earnings":0,"jama":0,"kharchi":0,"recovery":0,"net":0,"cash":0,"new_jama":0,"shortfall":0}
	for slip in slips:
		for key in totals: totals[key] += int(slip.totals[key])
	return totals

func payment_review():
	clear_body()
	quiet(body,"‹ Change person or date",func(): show_page("Pay"))
	var key: String = payment_state.key
	var result: Dictionary = payment_state.result
	var name: String = repo.find("families",key).get("name","") if key.begins_with("FAM") else repo.find("persons",key).name
	heading("Check the payment",name+" · Through "+display_date(payment_state.end))
	var c = card("Payment summary")
	var totals = combined_totals(result.slips)
	var labels = {}
	labels.earnings = money_line(c,"Wages earned",totals.earnings)
	labels.jama = money_line(c,"+ Jama held by you",totals.jama)
	labels.kharchi = money_line(c,"− Kharchi already given",totals.kharchi)
	labels.recovery = money_line(c,"− Advance to recover",totals.recovery)
	c.add_child(HSeparator.new())
	labels.net = money_line(c,"Amount payable",totals.net,true)
	var giving = card("Money you are giving")
	payment_state.controls = {}
	var recovery_box = column(giving)
	recovery_box.hide()
	var entry_box = column(giving)
	giving.move_child(entry_box,1)
	for slip in result.slips:
		var person_fields = column(entry_box)
		if result.slips.size() > 1: person_fields.add_child(label(slip.name,17))
		var cash = amount_field(person_fields,"Amount" if result.slips.size() == 1 else "Giving to "+slip.name,str(int(slip.totals.cash)))
		var loan_fields = column(recovery_box)
		var recovery = amount_field(loan_fields,"Advance deduction" if result.slips.size() == 1 else slip.name+" · Advance deduction",str(int(slip.totals.recovery)))
		loan_fields.add_child(label("Loan remaining before payment: "+P.money(int(slip.outstanding)),12,MUTED))
		payment_state.controls[slip.person_id] = {"cash":cash,"recovery":recovery}
	var carry = label("",13,Color("2f7859"))
	giving.add_child(carry)
	var error_label = label("",13,Color("b44333"))
	error_label.hide()
	giving.add_child(error_label)
	quiet(giving,"Change advance deduction or payment date",func(): recovery_box.visible = not recovery_box.visible)
	var paid_date = date_input(recovery_box,"Date you are giving the money",today())
	var use_full = quiet(recovery_box,"Use the full payable amount",func():
		var overrides = {}
		for member in payment_state.controls:
			var field = payment_state.controls[member].recovery
			if not field.text.is_valid_int():
				notice("Enter whole rupees for the advance deduction.",true)
				return
			overrides[member] = {"recovery":int(field.text)}
		prepare_payment(key,payment_state.end,overrides))
	use_full.add_theme_font_size_override("font_size",13)
	fold(body,"See the wage calculation",func(details):
		for slip in result.slips: slip_details(details,slip))
	var record = primary(body,"Record payment · "+P.money(int(result.cash)),func():
		var fresh = read_payment_controls()
		if fresh.has("error"):
			notice(fresh.error,true)
			return
		var summary = combined_totals(fresh.slips)
		var message = "Give "+P.money(summary.cash)+" to "+name+"?\nWork included through "+display_date(payment_state.end)+"."
		if summary.new_jama > 0: message += "\n"+P.money(summary.new_jama)+" stays as jama for the next payment."
		if summary.shortfall > 0: message += "\nNo money is due for the negative amount. "+P.money(summary.shortfall)+" will carry as an advance."
		confirm(message,func():
			if service.record_slips(fresh.slips,fresh.family_id,paid_date.value,true):
				receipt(repo.data.settlements.back())
				notice("Payment recorded. A receipt is ready.")
			else: notice(service.error,true)))
	var refresh = func(_unused = ""):
		var fresh = read_payment_controls()
		if fresh.has("error"):
			error_label.text = friendly_error(fresh.error)
			error_label.show()
			record.disabled = true
			return
		error_label.hide()
		record.disabled = false
		var updated = combined_totals(fresh.slips)
		for field in labels: labels[field].text = P.money(int(updated[field]))
		record.text = "Record payment · "+P.money(updated.cash)
		carry.text = P.money(updated.new_jama)+" will stay as jama for the next payment." if updated.new_jama > 0 else "The full payable amount is being given."
		if updated.shortfall > 0: carry.text = P.money(updated.shortfall)+" will carry as an advance. No negative cash payment."
	for member in payment_state.controls:
		payment_state.controls[member].cash.text_changed.connect(refresh)
		payment_state.controls[member].recovery.text_changed.connect(refresh)
	refresh.call()

func read_payment_controls() -> Dictionary:
	var overrides = {}
	for key in payment_state.controls:
		var row = payment_state.controls[key]
		for field in ["cash","recovery"]:
			if not row[field].text.is_valid_int() or int(row[field].text) < 0 or int(row[field].text) > 9000000000000000:
				return {"error":"Enter a non-negative amount in whole rupees."}
		overrides[key] = {"cash":int(row.cash.text),"recovery":int(row.recovery.text)}
	return calculate_payment(payment_state.key,payment_state.end,overrides)

func slip_details(parent: Node, slip: Dictionary):
	var c = panel(parent,slip.name,display_date(slip.start)+" – "+display_date(slip.end))
	if not slip.bm.is_empty():
		money_line(c,"Boiler master salary",int(slip.bm.base))
		money_line(c,"Extra BM shifts",int(slip.bm.extra))
		c.add_child(label("Monthly salary "+P.money(int(slip.bm.salary))+" · "+str(int(slip.bm.days))+" days in this period",12,MUTED))
	for row in slip.attendance:
		var role: String = {"F":"Fireman","H":"Helper","BM":"Boiler master"}.get(row.role,row.role)
		var description: String = row.get("mill_name",row.mill_id)+" · "+role+" · "+str(int(row.half_units)/2.0)+" shifts"
		c.add_child(label(description,14))
		c.add_child(label(display_date(row.start)+" – "+display_date(row.end),12,MUTED))
		if row.role != "BM":
			var wage = P.worker(int(row.rate),int(row.half_units),int(row.minutes))
			money_line(c,"Attendance at "+P.money(int(row.rate)),wage.attendance)
			if wage.hours > 0: money_line(c,"Extra hours",wage.hours)
			if int(row.get("split_adjustment",0)) != 0: money_line(c,"Split rounding adjustment",int(row.split_adjustment))
	money_line(c,"Wages",int(slip.totals.earnings))
	money_line(c,"Jama",int(slip.totals.jama))
	money_line(c,"Kharchi",int(slip.totals.kharchi))
	money_line(c,"Advance recovered",int(slip.totals.recovery))
	money_line(c,"Amount given",int(slip.totals.cash),true)
	if slip.totals.new_jama > 0: money_line(c,"Jama kept for next payment",int(slip.totals.new_jama))
	if slip.remaining_advance > 0: money_line(c,"Advance still remaining",int(slip.remaining_advance))

func history_page():
	heading("Payments","A clear record of every person and family paid.")
	primary(body,"+ Make a payment",func(): open_pay())
	if repo.data.settlements.is_empty():
		empty_state(body,"No payments yet","Your first recorded payment and receipt will appear here.")
		return
	var c = card("Payment history")
	var payments = repo.data.settlements.duplicate()
	payments.reverse()
	for payment in payments:
		person_row(c,payment_name(payment),display_date(payment.paid_date)+(" · Cancelled" if payment.cancelled else ""),P.money(int(payment.cash)),func(): receipt(payment))

func receipt(payment: Dictionary, clear: bool = true):
	if clear: clear_body()
	top_title.text = "Payment receipt"
	heading("Payment cancelled" if payment.cancelled else "Payment recorded",payment_name(payment))
	var c = card("Amount given")
	c.add_child(label(P.money(int(payment.cash)),38,Color("25815a") if not payment.cancelled else MUTED))
	c.add_child(label("Paid on "+display_date(payment.paid_date),14,MUTED))
	if not payment.slips.is_empty(): c.add_child(label("Work through "+display_date(payment.slips[0].end),13,MUTED))
	if not payment.cancelled: c.add_child(label("Remember to save a fresh backup after payments.",12,MUTED))
	var actions = grid(c,2)
	primary(actions,"Save / print receipt",func(): download(receipt_html(payment),"paytrack-receipt.html","text/html"))
	button(actions,"Back to payments",func(): show_page("History"))
	var totals = combined_totals(payment.slips)
	if totals.new_jama > 0: c.add_child(label(P.money(totals.new_jama)+" stays as jama for the next payment.",14,BLUE))
	for slip in payment.slips: slip_details(body,slip)
	if not payment.cancelled and not repo.data.settlements.is_empty() and repo.data.settlements.back().id == payment.id:
		fold(body,"Correct a payment mistake",func(options):
			options.add_child(label("Cancel this latest payment to put its entries back. You can then record the corrected payment.",13,MUTED))
			button(options,"Cancel this payment",func(): confirm("Cancel the payment to "+payment_name(payment)+"? Its attendance and money entries will be available again.",func():
				if service.cancel_latest(payment.id,true):
					show_page("History")
					notice("Payment cancelled. You can now record it again.")
				else: notice(service.error,true))))

func receipt_html(payment: Dictionary) -> String:
	var html = "<!doctype html><meta charset='utf-8'><title>PayTrack receipt</title><style>body{font:15px system-ui;color:#192436;max-width:760px;margin:48px auto;padding:0 24px}h1{font-size:24px}h2{font-size:18px;margin-top:32px}.amount{font-size:38px;margin:20px 0}table{width:100%;border-collapse:collapse}td{padding:10px 0;border-bottom:1px solid #e5e9ef}td:last-child{text-align:right}small{color:#758196}button{padding:12px 20px}@media print{button{display:none}}</style><h1>PayTrack</h1><p>"+payment_name(payment).xml_escape()+"</p><div class='amount'>"+P.money(int(payment.cash))+"</div><p>Paid on "+display_date(payment.paid_date)+"</p>"
	for slip in payment.slips:
		html += "<h2>"+slip.name.xml_escape()+" <small>"+slip.person_id+"</small></h2><p>"+display_date(slip.start)+" – "+display_date(slip.end)+"</p><table>"
		for row in slip.attendance:
			var wage = P.worker(int(row.rate),int(row.half_units),int(row.minutes))
			var work = str(row.get("mill_name",row.mill_id)).xml_escape()+" · "+row.role+" · "+str(int(row.half_units)/2.0)+" shifts"
			if row.role == "BM":
				html += "<tr><td>"+work+"</td><td>BM attendance</td></tr>"
			else:
				html += "<tr><td>"+work+" at "+P.money(int(row.rate))+"</td><td>"+P.money(wage.attendance)+"</td></tr>"
				if int(row.minutes) > 0: html += "<tr><td>Extra hours · "+str(int(row.minutes)/60.0)+"</td><td>"+P.money(wage.hours)+"</td></tr>"
				if int(row.get("split_adjustment",0)) != 0: html += "<tr><td>Split rounding adjustment</td><td>"+P.money(int(row.split_adjustment))+"</td></tr>"
		if not slip.bm.is_empty():
			html += "<tr><td>BM fixed salary for this period</td><td>"+P.money(int(slip.bm.base))+"</td></tr>"
			html += "<tr><td>Extra BM shifts</td><td>"+P.money(int(slip.bm.extra))+"</td></tr>"
		for field in [["earnings","Wages"],["jama","Jama added"],["kharchi","Kharchi deducted"],["recovery","Advance recovered"],["net","Payable"],["cash","Amount given"],["new_jama","Jama kept"],["shortfall","Carry-forward advance"]]: html += "<tr><td>"+field[1]+"</td><td>"+P.money(int(slip.totals[field[0]]))+"</td></tr>"
		html += "<tr><td>Advance remaining</td><td>"+P.money(int(slip.remaining_advance))+"</td></tr></table>"
	return html+"<p><small>Receipt "+payment.id+(" · CANCELLED" if payment.cancelled else "")+"</small></p><button onclick='print()'>Print receipt</button>"

func families_page():
	heading("Families","One payment, with a separate calculation for each person.")
	var tabs = HBoxContainer.new()
	body.add_child(tabs)
	quiet(tabs,"People",func(): show_page("People"))
	button(tabs,"Families",func(): show_page("Families"))
	primary(body,"+ Create a family",func(): family_form())
	var any = false
	for family in active_rows("families"):
		any = true
		var names = []
		for key in family.members: names.append(repo.find("persons",key).get("name",key))
		var c = card(family.name,", ".join(names))
		var actions = grid(c,2)
		primary(actions,"Pay family",func(): open_pay(family.id))
		button(actions,"Edit family",func(): family_form(family.id))
	if not any: empty_state(body,"No families yet","Group people who receive one combined payment. You can keep everyone separate if you prefer.")

func family_form(key: String = ""):
	var family = repo.find("families",key)
	var c = modal("Create a family" if family.is_empty() else "Edit family","Choose at least two people. Pay dates must match and old balances must be settled before changing a family.")
	var name = input(c,"Family name",family.get("name",""))
	var members = []
	for person in active_rows("persons"):
		if not person.family_id.is_empty() and person.family_id != key: continue
		var item = CheckBox.new()
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.text = person.name
		item.custom_minimum_size.y = 46
		item.button_pressed = person.id in family.get("members",[])
		c.add_child(item)
		members.append({"node":item,"id":person.id})
	primary(c,"Create family" if family.is_empty() else "Save family",func():
		var ids = []
		for item in members:
			if item.node.button_pressed: ids.append(item.id)
		if commit_action(func(): return service.family(name.text,ids) if key.is_empty() else service.family_change(key,name.text,ids),"Family saved."): close_modal())
	if not key.is_empty(): quiet(c,"Dissolve this family",func():
		var family_name: String = family.name
		confirm("Stop paying "+family_name+" as a group? Each person's records will be kept.",func(): commit_action(func(): return service.family_change(key,family_name,[]),"Family dissolved.")))
	quiet(c,"Cancel",close_modal)

func settings_page():
	heading("Settings","Change rates, manage salaries and keep a copy of your records.")
	var cards = grid(body,2,800)
	var mills = panel(cards,"Mills & attendance rates","Fireman and helper rates, saved with the date they start.")
	for mill in active_rows("mills"):
		var f = service.effective("rates","mill_id",mill.id,today(),"F")
		var h = service.effective("rates","mill_id",mill.id,today(),"H")
		person_row(mills,mill.name,"Fireman "+P.money(int(f.get("amount",0)))+" · Helper "+P.money(int(h.get("amount",0))),"Edit",func(): mill_form(mill.id))
	button(mills,"+ Add a mill",func(): mill_form())
	var masters = panel(cards,"Boiler master salaries","Fixed monthly salary, even when no shifts were entered.")
	var master_count = 0
	for person in active_rows("persons"):
		var salary = service.effective("salaries","person_id",person.id,today())
		if int(salary.get("amount",0)) <= 0: continue
		person_row(masters,person.name,"Monthly salary",P.money(int(salary.amount)),func(): salary_form(person.id))
		master_count += 1
	if master_count == 0: masters.add_child(label("No boiler master salary set yet.",14,MUTED))
	button(masters,"Set or change a salary",func(): salary_form())
	var backup = card("Keep a copy of your records","Entries stay in this browser on this device. A backup lets you restore them or move them to another device.")
	var last: String = repo.data.settings.get("last_backup_at","")
	backup.add_child(label("Last backup: "+display_date(last.left(10)) if not last.is_empty() else "No backup saved yet",13,MUTED))
	var actions = grid(backup,2)
	primary(actions,"Save a backup",backup_now)
	button(actions,"Restore a backup",import_backup)
	if not OS.is_userfs_persistent(): backup.add_child(label("This browser may not keep your records after it closes. Please save a backup.",13,Color("b44333")))
	fold(body,"Export for Excel",func(exports):
		for item in [["persons","People"],["attendance","Attendance"],["ledger","Money entries"],["settlements","Payments"]]: button(exports,"Download "+item[1],func(): export_csv(item[0])))
	fold(body,"Rate and salary history",func(history):
		for collection in ["rates","salaries"]:
			var rows = repo.data[collection].duplicate()
			rows.reverse()
			for row in rows:
				var entity = repo.find("mills",row.mill_id).get("name",row.mill_id) if collection == "rates" else repo.find("persons",row.person_id).get("name",row.person_id)
				history.add_child(label(entity+" · "+row.get("role","Monthly salary")+" · "+P.money(int(row.amount))+" · From "+display_date(row.effective_from),13,MUTED)))

func mill_form(key: String = ""):
	var mill = repo.find("mills",key)
	var c = modal("Add a mill" if mill.is_empty() else "Mill & rates","Old payments keep their original rates.")
	var name = input(c,"Mill name",mill.get("name",""))
	var rates = grid(c,2)
	var f = service.effective("rates","mill_id",key,today(),"F")
	var h = service.effective("rates","mill_id",key,today(),"H")
	var fireman = amount_field(rates,"Fireman · per attendance",str(int(f.amount)) if not f.is_empty() else "")
	var helper = amount_field(rates,"Helper · per attendance",str(int(h.amount)) if not h.is_empty() else "")
	var date: PayTrackDateField
	var note: LineEdit
	if not mill.is_empty():
		date = date_input(c,"Rates start from",today())
		note = input(c,"Note (optional)")
	primary(c,"Save mill & rates",func():
		if not fireman.text.is_valid_int() or not helper.text.is_valid_int():
			notice("Enter whole-rupee rates for both kinds of work.",true)
			return
		if commit_action(func():
			var mill_id = key
			if mill_id.is_empty():
				if not service.mill(name.text): return false
				mill_id = repo.data.mills.back().id
			else:
				var row = repo.find("mills",mill_id)
				var clean = name.text.strip_edges()
				if clean.is_empty(): return service.fail("Enter a mill name.")
				for other in repo.data.mills:
					if other.id != mill_id and other.name.to_lower() == clean.to_lower(): return service.fail("That mill name is already in your list.")
				if row.name != clean:
					service.audit("mill renamed",{"id":key,"old":row.name,"new":clean})
					row.name = clean
			var effective_date = date.value if is_instance_valid(date) else today().left(8)+"01"
			var reason = note.text if is_instance_valid(note) else "Initial rates"
			return service.rate(mill_id,"F",int(fireman.text),effective_date,reason) and service.rate(mill_id,"H",int(helper.text),effective_date,reason),"Mill and rates saved."): close_modal())
	if not key.is_empty():
		quiet(c,"Update rates on unpaid attendance",func(): reprice_form(key))
		quiet(c,"Stop using this mill",func(): confirm("Hide this mill from new attendance? All old records will stay.",func(): commit_action(func():
			repo.find("mills",key).active = false
			return true,"Mill marked inactive.")))
	quiet(c,"Cancel",close_modal)

func salary_form(key: String = ""):
	var c = modal("Boiler master salary","Choose the date this salary starts. You will see the change before saving.")
	var who = select(c,"Person",active_rows("persons"))
	choose(who,key)
	var salary = service.effective("salaries","person_id",selected(who),today())
	var amount = amount_field(c,"Monthly salary",str(int(salary.get("amount",0))))
	who.item_selected.connect(func(_index): amount.text = str(int(service.effective("salaries","person_id",selected(who),today()).get("amount",0))))
	var date = date_input(c,"Starts from",today())
	var reason = input(c,"Note (optional)")
	c.add_child(label("Set the salary to 0 to stop BM eligibility from this date.",12,MUTED))
	primary(c,"Review salary change",func():
		if not amount.text.is_valid_int():
			notice("Enter the monthly salary in whole rupees.",true)
			return
		var person_id = selected(who)
		var amount_value = int(amount.text)
		var effective_date: String = date.value
		var note: String = reason.text
		var comparison = service.salary_comparison(person_id,amount_value,effective_date,today())
		if comparison.has("error"):
			notice(comparison.error,true)
			return
		confirm(repo.find("persons",person_id).name+" · New monthly salary "+P.money(amount_value)+"\nFrom "+display_date(effective_date)+"\nUnpaid wages through today: "+P.money(int(comparison.old))+" → "+P.money(int(comparison.new))+"\nOld payments are kept as they were.",func(): commit_action(func(): return service.salary(person_id,amount_value,effective_date,note),"Salary updated.")))
	quiet(c,"Cancel",close_modal)

func reprice_form(key: String):
	var c = modal("Change unpaid attendance rates","Only unpaid entries will be considered. Recorded payments will stay as they were.")
	var role = choice(c,"Work",["Fireman","Helper"])
	var amount = amount_field(c,"New rate per attendance")
	var date = date_input(c,"Apply from",today())
	var reason = input(c,"Reason for the change")
	primary(c,"See affected entries",func():
		if not amount.text.is_valid_int() or int(amount.text) < 0 or int(amount.text) > P.MAX_VALUE or reason.text.strip_edges().is_empty():
			notice("Enter a valid whole-rupee rate and a reason.",true)
			return
		var preview = service.reprice_preview(key,["F","H"][role.selected],date.value,int(amount.text))
		if preview.has("error"):
			notice(preview.error,true)
			return
		var note: String = reason.text
		confirm(str(preview.rows.size())+" unpaid entries will change.\nOld wages "+P.money(int(preview.old))+"\nNew wages "+P.money(int(preview.new)),func(): commit_action(func(): return service.reprice(preview,note),"Unpaid rates updated.")))
	quiet(c,"Cancel",close_modal)

func rate_form(key: String):
	var row = repo.find("attendance",key)
	var c = modal("Correct this attendance rate",repo.find("persons",row.person_id).name+" · "+repo.find("mills",row.mill_id).name)
	var amount = amount_field(c,"Rate per attendance",str(int(row.rate)))
	var reason = input(c,"Reason for the correction")
	primary(c,"Save corrected rate",func():
		if not amount.text.is_valid_int():
			notice("Enter whole rupees.",true)
			return
		if commit_action(func(): return service.correct_rate(key,int(amount.text),reason.text),"Attendance rate corrected."): close_modal())
	quiet(c,"Cancel",close_modal)

func more_page():
	heading("More","The other things you may need.")
	var c = card("")
	for item in [["Money book","Money"],["Payment history","History"],["Families","Families"],["Mills, salaries & backups","Settings"]]: button(c,item[0],func(): show_page(item[1]))
	var backup = card("Your records stay on this device","Save a backup regularly, especially after payments.")
	primary(backup,"Save a backup",backup_now)

func preview_restore(content: String):
	var result = repo.inspect_backup(content)
	if result.has("error"):
		notice("This backup could not be read. Your current records have not been changed.",true)
		return
	pending_backup = content
	confirm("This backup has %d people and %d payments.\nReplace the records on this device with this backup? A safety copy of your current records will be kept." % [result.people,result.payments],func():
		if repo.restore(pending_backup):
			show_page("Home")
			notice("Your backup has been restored.")
		else: notice("The backup could not be restored. Your previous records have been kept.",true))

func quick_action(parent: Node, title: String, description: String, page: String, symbol: String):
	var tile = button(parent,"",func(): show_page(page))
	action_tiles.append(tile)
	tile.custom_minimum_size.y = 94 if narrow() else 116
	tile.add_theme_stylebox_override("normal",box(Color("edf5ff") if page == "Pay" else Color.WHITE,14,0,Color("dbe8fa") if page == "Pay" else Color("e6ebf2")))
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(margin)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",14)
	margin.add_child(row)
	var image = TextureRect.new()
	image.texture = icon(symbol)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.custom_minimum_size = Vector2(27,27)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var words = column(row)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var action = label({"Attendance":"Add attendance","Pay":"Make a payment","Money":"Record money"}[page],16,BLUE if page == "Pay" else INK)
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(action)
	var help = label(description,12,MUTED)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(help)
