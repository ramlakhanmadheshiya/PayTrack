extends Control
const P = preload("res://scripts/domain/payroll.gd")
const R = preload("res://scripts/storage/repository.gd")
const S = preload("res://scripts/services/payroll_service.gd")
var repo = R.new()
var service = S.new(repo)
var body: VBoxContainer
var status: Label
var navigation: GridContainer
var current = "Home"
var import_callback
var pending_backup = ""
var preview_slips: Array = []
var preview_family = ""
var preview_end = ""
var preview_person = ""
var member_overrides = {}
var fields = {}
var batch_rows = []

func _ready():
	if OS.has_feature("web"):
		get_window().content_scale_factor = maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1")))
	var base = Theme.new()
	base.default_font = preload("res://assets/NotoSans.ttf")
	base.default_font_size = 16
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)
	normal.border_color = Color("dee3eb")
	normal.set_border_width_all(1)
	base.set_stylebox("normal", "Button", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("eaf3ff")
	base.set_stylebox("hover", "Button", hover)
	base.set_stylebox("focus", "Button", hover)
	base.set_color("font_color", "Button", Color("007aff"))
	base.set_color("font_hover_color", "Button", Color("005ac4"))
	base.set_color("font_color", "Label", Color("1d2838"))
	base.set_color("font_color", "LineEdit", Color("1d2838"))
	base.set_color("font_color", "OptionButton", Color("1d2838"))
	base.set_stylebox("normal", "LineEdit", normal)
	base.set_stylebox("normal", "OptionButton", normal)
	theme = base
	var outer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	var top = MarginContainer.new()
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_right", 24)
	top.add_theme_constant_override("margin_top", 18)
	top.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(top)
	var header = HBoxContainer.new()
	top.add_child(header)
	var brand = label("PayTrack", 28)
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var badge = label("LOCAL DEMO",13,Color("007aff"))
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(badge)
	navigation = GridContainer.new()
	navigation.columns = 7
	outer.add_child(navigation)
	for page in ["Home", "People", "Attendance", "Money", "Pay", "Families", "Settings"]:
		button(navigation, page, func(): show_page(page))
	status = label("Local testing data — not synced between devices. Use fictional records only.", 14, Color("64748b"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	margin.add_child(body)
	if not repo.load_data():
		status.text = repo.error
	get_viewport().size_changed.connect(responsive)
	responsive()
	show_page("Home")

func responsive():
	if OS.has_feature("web"):
		var scale = maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1")))
		if not is_equal_approx(get_window().content_scale_factor,scale): get_window().content_scale_factor = scale
	var narrow = get_viewport_rect().size.x < 700
	navigation.columns = 4 if narrow else 7
	navigation.add_theme_constant_override("h_separation", 4 if narrow else 8)
	for child in navigation.get_children():
		child.add_theme_font_size_override("font_size", 12 if narrow else 16)

func label(text: String, size: int = 16, color: Color = Color("1d2838")) -> Label:
	var node = Label.new()
	node.text = tr(text)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func text(value: String, size: int = 16):
	var node = label(value, size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(node)
	return node

func button(parent: Node, title: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = tr(title)
	node.clip_text = true
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = 46
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func card(title: String, subtitle: String = "") -> VBoxContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	body.add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	content.add_child(label(title, 21))
	if not subtitle.is_empty():
		var sub = label(subtitle, 14, Color("64748b"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(sub)
	return content

func input(parent: Node, title: String, value: String = "") -> LineEdit:
	parent.add_child(label(title, 14, Color("64748b")))
	var node = LineEdit.new()
	node.text = value
	node.custom_minimum_size.y = 46
	parent.add_child(node)
	return node

func select(parent: Node, title: String, collection: Array, title_field: String = "name") -> OptionButton:
	parent.add_child(label(title, 14, Color("64748b")))
	var node = OptionButton.new()
	node.fit_to_longest_item = false
	node.clip_text = true
	node.custom_minimum_size.y = 46
	parent.add_child(node)
	for row in collection:
		node.add_item(row.get(title_field, "") + "  ·  " + row.id)
		node.set_item_metadata(node.item_count - 1, row.id)
	return node

func choice(parent: Node, title: String, values: Array) -> OptionButton:
	parent.add_child(label(title, 14, Color("64748b")))
	var node = OptionButton.new()
	parent.add_child(node)
	node.custom_minimum_size.y = 46
	for value in values:
		node.add_item(value)
	return node

func selected(node: OptionButton) -> String:
	return "" if node.selected < 0 else str(node.get_item_metadata(node.selected))

func today() -> String:
	return Time.get_date_string_from_system()

func transact(action: Callable):
	var before = repo.data.duplicate(true)
	if not action.call():
		repo.data = before
		show_page(current)
		status.text = service.error
		return
	service.audit("account edit", current)
	if not repo.save():
		repo.data = before
		show_page(current)
		status.text = repo.error
		return
	show_page(current)
	status.text = "Saved on this device. Download a backup to keep a portable copy."

func confirm(message: String, callback: Callable):
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.05,0.10,0.18,0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = minf(480.0,get_viewport_rect().size.x-48.0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(20)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",18)
	panel.add_child(content)
	content.add_child(label("Review and confirm",22))
	var description = label(message,16)
	description.custom_minimum_size.x = minf(432.0,get_viewport_rect().size.x-96.0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	button(content,"Confirm",func():
		overlay.queue_free()
		callback.call())
	button(content,"Cancel",overlay.queue_free)

func show_page(page: String):
	current = page
	fields = {}
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	text(page if page != "Home" else "Your work, in balance.", 34)
	match page:
		"Home": home()
		"People": people()
		"Attendance": attendance_page()
		"Money": money_page()
		"Pay": pay_page()
		"Families": families_page()
		"Settings": settings_page()

func home():
	text("A clear view of attendance, money and every payment.", 18)
	var summary = card("A little clarity for payday", "Your records stay in this browser. Nothing is uploaded or synced.")
	summary.add_child(label("%d people     ·     %d attendance entries     ·     %d payments" % [repo.data.persons.size(), repo.data.attendance.size(), repo.data.settlements.size()]))
	for action in [["Add Attendance", "Attendance"], ["Pay Someone", "Pay"], ["Money Entry", "Money"], ["Manage People", "People"]]:
		button(summary, action[0] + "  >", func(): show_page(action[1]))
	var recent = card("Recent payments")
	if repo.data.settlements.is_empty():
		recent.add_child(label("A fresh start. Your first recorded payment will appear here.", 15))
	for payment in repo.data.settlements.slice(-5):
		button(recent, payment.id + "  ·  " + payment.paid_date + "  ·  " + P.money(int(payment.cash)) + ("  Cancelled" if payment.cancelled else ""), func(): receipt(payment))
	if repo.data.persons.is_empty():
		button(body, "Try fictional sample data", seed_demo)
	backup_reminder()

func seed_demo():
	transact(func():
		service.person("Aarav Demo", "2026-11-01")
		service.person("Meera Demo", "2026-11-01")
		for name in ["Willow Demo", "Maple Demo", "Cedar Demo", "Elm Demo", "Pine Demo"]:
			service.mill(name)
			var key = repo.data.mills.back().id
			service.rate(key,"F",350,"2026-01-01")
			service.rate(key,"H",250,"2026-01-01")
		service.salary(repo.data.persons[0].id,24000,"2026-11-01")
		return true)

func people():
	var c = card("People", "Permanent IDs stay with each person. Use a suffix to distinguish matching names.")
	var search_box = input(c,"Search name or ID")
	var results = VBoxContainer.new()
	c.add_child(results)
	var refresh = func(query: String):
		for child in results.get_children():
			results.remove_child(child)
			child.queue_free()
		for who in service.search(query):
			button(results, who.id + "  ·  " + who.name + ("  ·  Inactive" if not who.active else "") + ("  ·  " + who.family_id if not who.family_id.is_empty() else ""), func(): person_detail(who))
	search_box.text_changed.connect(refresh)
	refresh.call("")
	var add = card("Add a person")
	var name = input(add,"Full name")
	var start = input(add,"Payroll start · YYYY-MM-DD",today())
	button(add,"Add person",func(): transact(func(): return service.person(name.text,start.text)))

func person_detail(who: Dictionary):
	show_page("People")
	var c = card(who.name + "  ·  " + who.id, "Payroll start: " + who.payroll_start_date + "   ·   Paid through: " + ("Not yet" if who.paid_up_to.is_empty() else who.paid_up_to))
	var name = input(c,"Name",who.name)
	var payroll_start = input(c,"Payroll start",who.payroll_start_date)
	button(c,"Update payroll start",func(): transact(func():
		if not P.valid_date(payroll_start.text) or not who.paid_up_to.is_empty(): return service.fail("Payroll start is editable only before first payment.")
		for row in repo.data.attendance:
			if row.person_id == who.id and row.start < payroll_start.text: return service.fail("New start would exclude attendance.")
		service.audit("payroll start",{"id":who.id,"old":who.payroll_start_date,"new":payroll_start.text})
		who.payroll_start_date = payroll_start.text
		return true))
	button(c,"Save name",func(): transact(func():
		var clean = " ".join(name.text.split(" ",false)).strip_edges()
		for other in repo.data.persons:
			if other.id != who.id and other.name.to_lower() == clean.to_lower():
				return service.fail("That name already exists.")
		if clean.is_empty(): return service.fail("Enter a name.")
		service.audit("person renamed",{"id":who.id,"old":who.name,"new":clean})
		who.name = clean
		return true))
	button(c,"Mark inactive" if who.active else "Reactivate",func(): transact(func():
		who.active = not who.active
		return true))
	for row in repo.data.attendance:
		if row.person_id == who.id:
			c.add_child(label(row.id + " · " + row.role + " · " + row.start + " → " + row.end + " · " + ("Unpaid" if row.settlement_id.is_empty() else row.settlement_id),14))
	for event in repo.data.ledger:
		if event.person_id == who.id:
			c.add_child(label(event.kind.capitalize() + " · " + P.money(int(event.amount)) + " · " + event.date,14))

func attendance_page():
	var c = card("Batch attendance", "Set the mill and dates once. Enter supplied counts; one attendance is a 12-hour shift.")
	var mill = select(c,"Mill",repo.data.mills)
	var start = input(c,"From · YYYY-MM-DD",today())
	var end = input(c,"Through · YYYY-MM-DD",today())
	var rows_box = VBoxContainer.new()
	c.add_child(rows_box)
	batch_rows = []
	var add_row = func():
		var row_box = VBoxContainer.new()
		rows_box.add_child(row_box)
		var who = select(row_box,"Person",repo.data.persons)
		var role = choice(row_box,"Post",["F","H","BM"])
		var units = input(row_box,"Attendances · halves accepted","0")
		var hours = input(row_box,"Extra hours · quarters accepted","0")
		var rate_label = label("",14)
		row_box.add_child(rate_label)
		var update = func(_index = 0):
			var value = service.effective("rates","mill_id",selected(mill),start.text,role.get_item_text(role.selected))
			rate_label.text = "BM fixed salary + extra shifts" if role.selected == 2 else "Saved rate: " + P.money(int(value.get("amount",0))) + " / shift"
		role.item_selected.connect(update)
		mill.item_selected.connect(update)
		start.text_changed.connect(func(_value): update.call())
		update.call()
		batch_rows.append({"person":who,"role":role,"units":units,"hours":hours})
	button(c,"+ Add another person",add_row)
	add_row.call()
	var overlap = CheckBox.new()
	overlap.text = "I reviewed and confirm overlapping rows"
	c.add_child(overlap)
	button(c,"Save batch",func(): transact(func():
		for row in batch_rows:
			var halves = decimal_units(row.units.text,2)
			var minutes = decimal_units(row.hours.text,60)
			if halves < 0 or minutes < 0:
				return service.fail("Use non-negative half attendances and quarter hours.")
			if not service.attendance(selected(row.person),selected(mill),row.role.get_item_text(row.role.selected),start.text,end.text,halves,minutes,overlap.button_pressed):
				return false
		return true))
	var edit = card("Correct received attendance", "Unpaid rows only. Existing rates stay frozen; every correction records a reason.")
	var edit_rows = []
	for row in repo.data.attendance:
		if row.settlement_id.is_empty(): edit_rows.append({"id":row.id,"name":row.person_id + " · " + row.role + " · " + row.start + " / " + row.end})
	var edit_row = select(edit,"Unpaid row",edit_rows)
	var edit_start = input(edit,"Corrected from",today())
	var edit_end = input(edit,"Corrected through",today())
	var edit_units = input(edit,"Corrected attendances","0")
	var edit_hours = input(edit,"Corrected extra hours","0")
	var edit_reason = input(edit,"Reason for correction")
	button(edit,"Save audited correction",func(): transact(func(): return service.edit_attendance(selected(edit_row),edit_start.text,edit_end.text,decimal_units(edit_units.text,2),decimal_units(edit_hours.text,60),edit_reason.text,overlap.button_pressed)))
	var split_card = card("Split an unpaid range", "Supply actual counts for the first part. The remaining counts stay in the second part.")
	var entries = []
	for row in repo.data.attendance:
		if row.settlement_id.is_empty(): entries.append({"id":row.id,"name":row.person_id + " · " + row.start + " → " + row.end})
	var entry = select(split_card,"Entry",entries)
	var through = input(split_card,"First part ends",today())
	var halves = input(split_card,"First part attendances","0")
	var mins = input(split_card,"First part extra hours","0")
	button(split_card,"Split and preserve totals",func(): transact(func(): return service.split(selected(entry),through.text,decimal_units(halves.text,2),decimal_units(mins.text,60))))

func decimal_units(value: String, scale: int) -> int:
	var bits = value.strip_edges().split(".")
	if bits.size() > 2 or not bits[0].is_valid_int() or int(bits[0]) < 0: return -1
	var fraction = 0
	if bits.size() == 2:
		if not bits[1].is_valid_int() or bits[1].length() > 2: return -1
		fraction = int(bits[1].rpad(2,"0"))
	if (fraction * scale) % 100 != 0: return -1
	return int(bits[0]) * scale + fraction * scale / 100

func money_page():
	var c = card("Money entry", "Jama is owed to a person. Kharchi is already given. Advance is a recoverable loan.")
	var who = select(c,"Person",repo.data.persons)
	var kind = choice(c,"Type",["jama","kharchi","advance"])
	var amount = input(c,"Whole rupees","0")
	var date = input(c,"Date",today())
	var installment = input(c,"Suggested recovery per settlement · advances only","0")
	button(c,"Save money entry",func(): transact(func():
		if not amount.text.is_valid_int() or not installment.text.is_valid_int(): return service.fail("Enter whole rupees.")
		return service.ledger(selected(who),kind.get_item_text(kind.selected),int(amount.text),date.text,int(installment.text))))
	var bulk = card("Bulk kharchi", "Each day is posted separately so an early payment only includes eligible dates.")
	var selections = []
	for person in repo.data.persons:
		var check = CheckBox.new()
		check.text = person.name + " · " + person.id
		bulk.add_child(check)
		selections.append([check,person.id])
	var start = input(bulk,"From",today())
	var end = input(bulk,"Through",today())
	var daily = input(bulk,"Rupees per person per day","0")
	button(bulk,"Record daily kharchi",func(): transact(func():
		var ids = []
		for item in selections:
			if item[0].button_pressed: ids.append(item[1])
		if ids.is_empty() or not daily.text.is_valid_int(): return service.fail("Select people and a whole-rupee daily amount.")
		return service.bulk_kharchi(ids,start.text,end.text,int(daily.text))))
	ledger_edit_form()

func ledger_edit_form():
	var c = card("Correct an unallocated money entry", "Consumed entries and recovered loans are protected. Use an audited correction before settlement.")
	var entries = []
	for row in repo.data.ledger:
		if row.settlement_id.is_empty() and row.recovered == 0: entries.append({"id":row.id,"name":row.person_id + " · " + row.kind + " · " + P.money(int(row.amount))})
	var entry = select(c,"Entry",entries)
	var amount = input(c,"Correct amount","0")
	var date = input(c,"Correct effective date",today())
	var installment = input(c,"Recovery installment","0")
	var reason = input(c,"Correction reason")
	button(c,"Save correction",func(): transact(func():
		if not amount.text.is_valid_int() or not installment.text.is_valid_int(): return service.fail("Enter whole rupees.")
		return service.edit_ledger(selected(entry),int(amount.text),date.text,int(installment.text),reason.text)))

func pay_page():
	var c = card("Pay to any date", "Preview first. Recording freezes the slip and clears only its allocated items.")
	var payees = []
	for person in repo.data.persons:
		if person.family_id.is_empty(): payees.append(person)
	for family in repo.data.families:
		if family.active: payees.append(family)
	var who = select(c,"Person or family",payees)
	var end = input(c,"Pay through",today())
	var actual = input(c,"Cash handed out on",today())
	var recovery = input(c,"Advance recovery · blank uses installment")
	var cash = input(c,"Cash paid · blank pays full net")
	var allocations = VBoxContainer.new()
	c.add_child(allocations)
	member_overrides = {}
	var refresh_members = func(_index = 0):
		for child in allocations.get_children():
			allocations.remove_child(child)
			child.queue_free()
		member_overrides = {}
		var group = repo.find("families",selected(who))
		if not group.is_empty():
			for member in group.members:
				allocations.add_child(label(repo.find("persons",member).name + " · " + member,18))
				member_overrides[member] = {"recovery":input(allocations,"Recovery · blank uses installment"),"cash":input(allocations,"Cash allocation · blank uses full net")}
	who.item_selected.connect(refresh_members)
	refresh_members.call()
	button(c,"Preview payment",func():
		if (not recovery.text.is_empty() and (not recovery.text.is_valid_int() or int(recovery.text) < 0)) or (not cash.text.is_empty() and (not cash.text.is_valid_int() or int(cash.text) < 0)):
			status.text = "Enter whole rupees."
			return
		for member in member_overrides:
			for field in ["cash","recovery"]:
				var value_text = member_overrides[member][field].text
				if not value_text.is_empty() and (not value_text.is_valid_int() or int(value_text) < 0):
					status.text = "Family amounts must be non-negative whole rupees."
					return
		var key = selected(who)
		preview_family = key if key.begins_with("FAM") else ""
		var value = service.family_preview(key,end.text,read_member_overrides()) if not preview_family.is_empty() else service.preview(key,end.text,-1 if recovery.text.is_empty() else int(recovery.text),-1 if cash.text.is_empty() else int(cash.text))
		if value.has("error"):
			status.text = value.error
			return
		if not preview_family.is_empty() and (not cash.text.is_empty() or not recovery.text.is_empty()):
			status.text = "Use the per-member fields below for family recovery and cash allocations."
			return
		preview_slips = value.slips if not preview_family.is_empty() else [value]
		var snapshot = {"id":"PREVIEW","paid_date":actual.text,"slips":preview_slips,"cash":0,"cancelled":false}
		for slip in preview_slips: snapshot.cash += int(slip.totals.cash)
		receipt(snapshot,false)
		button(body,"Confirm and record " + P.money(int(snapshot.cash)),func(): confirm("Record this payment? Negative net, if any, becomes an advance. Saved slips are frozen.",func():
			# Recompute to reject stale previews.
			var fresh = service.family_preview(key,end.text,read_member_overrides()) if not preview_family.is_empty() else service.preview(key,end.text,-1 if recovery.text.is_empty() else int(recovery.text),-1 if cash.text.is_empty() else int(cash.text))
			if fresh.has("error"):
				status.text = fresh.error
				return
			var slips = fresh.slips if not preview_family.is_empty() else [fresh]
			if service.record_slips(slips,preview_family,actual.text,true):
				show_page("Home")
				status.text = "Payment recorded. Download a fresh backup."
			else: status.text = service.error)))
	var history = card("Payment history")
	for payment in repo.data.settlements:
		button(history,payment.id + " · " + P.money(int(payment.cash)) + (" · Cancelled" if payment.cancelled else ""),func(): receipt(payment))

func receipt(payment: Dictionary, clear: bool = true):
	if clear:
		for child in body.get_children():
			body.remove_child(child)
			child.queue_free()
	var c = card("Payment " + payment.id, "Cash date: " + payment.paid_date + (" · CANCELLED" if payment.cancelled else ""))
	var receipt_text = "PayTrack · " + payment.id + "\nCash date: " + payment.paid_date + "\n"
	for slip in payment.slips:
		var lines = [slip.name + " · " + slip.person_id, slip.start + " → " + slip.end, "Payroll start: " + slip.payroll_start_date]
		for row in slip.attendance:
			var parts = P.worker(int(row.rate),int(row.half_units),int(row.minutes))
			lines.append("%s · %s · %s → %s · %s shifts · %s minutes · rate %s" % [row.get("mill_name",row.mill_id),row.role,row.start,row.end,str(int(row.half_units)/2.0),row.minutes,P.money(int(row.rate))])
			if row.role != "BM":
				lines.append("Attendance " + P.money(parts.attendance) + " + hours " + P.money(parts.hours))
				if int(row.get("split_adjustment",0)) != 0: lines.append("Split rounding adjustment " + P.money(int(row.split_adjustment)) + " · preserves original range total")
		if not slip.bm.is_empty():
			lines.append("BM salary " + P.money(int(slip.bm.salary)) + " · " + str(slip.bm.days) + " days · base " + P.money(int(slip.bm.base)) + " + extra " + P.money(int(slip.bm.extra)))
		for key in ["earnings","jama","kharchi","recovery","net","cash","new_jama","shortfall"]:
			lines.append(key.replace("_"," ").capitalize() + "   " + P.money(int(slip.totals[key])))
		lines.append("Remaining advance   " + P.money(int(slip.remaining_advance)))
		for line in lines:
			var row_label = label(line,16)
			row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.add_child(row_label)
		receipt_text += "\n" + "\n".join(lines) + "\n"
	if payment.slips.size() > 1:
		c.add_child(label("Family totals",22))
		receipt_text += "\nFamily totals\n"
		for field in ["earnings","jama","kharchi","recovery","net","new_jama","shortfall"]:
			var sum_value = 0
			for slip in payment.slips: sum_value += int(slip.totals[field])
			var line = field.replace("_"," ").capitalize() + "   " + P.money(sum_value)
			c.add_child(label(line,18))
			receipt_text += line + "\n"
	c.add_child(label("Combined cash   " + P.money(int(payment.cash)),26))
	button(c,"Download printable receipt",func():
		var escaped = receipt_text.xml_escape()
		download("<!doctype html><meta charset='utf-8'><title>PayTrack receipt</title><style>body{font:16px system-ui;max-width:760px;margin:40px auto}pre{white-space:pre-wrap;line-height:1.6}</style><h1>PayTrack</h1><pre>" + escaped + "</pre><button onclick='print()'>Print receipt</button>","paytrack-receipt.html","text/html"))
	if payment.id != "PREVIEW" and not payment.cancelled:
		button(c,"Cancel latest payment",func(): confirm("Cancel this latest payment and restore its allocations? Later account changes block reversal.",func():
			if service.cancel_latest(payment.id,true): show_page("Pay")
			else: status.text = service.error))

func families_page():
	var c = card("Pay a family together", "Members need aligned dates and resolved attendance, jama, kharchi and advances before joining.")
	var name = input(c,"Family name")
	var members = []
	for who in repo.data.persons:
		if who.family_id.is_empty():
			var check = CheckBox.new()
			check.text = who.name + " · " + who.id
			c.add_child(check)
			members.append([check,who.id])
	button(c,"Create family",func(): transact(func():
		var ids = []
		for member in members:
			if member[0].button_pressed: ids.append(member[1])
		return service.family(name.text,ids)))
	for family in repo.data.families:
		var group = card(family.name, " · ".join(family.members))
		group.add_child(label("Active" if family.active else "Dissolved"))
		if family.active:
			var edit_name = input(group,"Family name",family.name)
			var members_input = input(group,"Member IDs · comma separated",",".join(family.members))
			button(group,"Update membership",func(): transact(func():
				var ids = []
				for item in members_input.text.split(",",false): ids.append(item.strip_edges())
				return service.family_change(family.id,edit_name.text,ids)))
			button(group,"Dissolve family",func(): confirm("Dissolve this family once all balances are resolved?",func(): transact(func(): return service.family_change(family.id,family.name,[]))))

func settings_page():
	var c = card("This device, your records", "Local testing data — not synced between devices. Browser clearing or private browsing can erase records. A backup moves data between devices.")
	c.add_child(label("Persistent storage reported: " + str(OS.is_userfs_persistent()) + " (browser policies can still clear it)",14))
	backup_reminder()
	button(c,"Download JSON backup",func():
		repo.data.settings.last_backup_at = Time.get_datetime_string_from_system(true)
		repo.save()
		download(repo.backup(),"paytrack-backup.json","application/json")
		status.text = "Backup download requested. Keep the downloaded file safely.")
	button(c,"Restore JSON backup",import_backup)
	for collection in ["persons","attendance","ledger","settlements"]:
		button(c,"Export " + collection + " CSV",func(): export_csv(collection))
	var m = card("Mills and rates", "Changes are effective-dated. Existing attendance keeps its saved rate.")
	for mill in repo.data.mills:
		m.add_child(label(mill.name + " · " + mill.id + (" · Inactive" if not mill.active else ""),18))
		for role in ["F","H"]:
			var value = service.effective("rates","mill_id",mill.id,today(),role)
			m.add_child(label(role + "  " + P.money(int(value.get("amount",0))),14))
		button(m,"Deactivate " + mill.name if mill.active else "Reactivate " + mill.name,func(): transact(func():
			mill.active = not mill.active
			return true))
	var new_name = input(m,"New mill name")
	button(m,"Add mill",func(): transact(func(): return service.mill(new_name.text)))
	var mill = select(m,"Mill to update",repo.data.mills)
	var rename = input(m,"Rename selected mill")
	button(m,"Rename mill",func(): transact(func():
		var selected_mill = repo.find("mills",selected(mill))
		if selected_mill.is_empty() or rename.text.strip_edges().is_empty(): return service.fail("Select a mill and enter its name.")
		for other in repo.data.mills:
			if other.id != selected_mill.id and other.name.to_lower() == rename.text.strip_edges().to_lower(): return service.fail("Mill name already exists.")
		service.audit("mill renamed",{"id":selected_mill.id,"old":selected_mill.name,"new":rename.text.strip_edges()})
		selected_mill.name = rename.text.strip_edges()
		return true))
	var role = choice(m,"Role",["F","H"])
	var rate = input(m,"Whole rupees per attendance","0")
	var effective = input(m,"Effective from",today())
	var reason = input(m,"Reason / note")
	button(m,"Save new rate",func(): transact(func():
		if not rate.text.is_valid_int(): return service.fail("Enter whole rupees.")
		return service.rate(selected(mill),role.get_item_text(role.selected),int(rate.text),effective.text,reason.text)))
	button(m,"Preview updating unpaid rows",func():
		if not rate.text.is_valid_int() or int(rate.text) < 0 or int(rate.text) > P.MAX_VALUE or not P.valid_date(effective.text):
			status.text = "Enter a valid rate and effective date."
			return
		var value = service.reprice_preview(selected(mill),role.get_item_text(role.selected),effective.text,int(rate.text))
		if value.has("error"):
			status.text = value.error
			return
		confirm("Rows: " + str(value.rows) + "\nOld: " + P.money(value.old) + " → New: " + P.money(value.new) + "\nPaid snapshots stay frozen.",func(): transact(func(): return service.reprice(value,reason.text))))
	var bm = card("Boiler master salary", "Salary effective on the slip's end date applies. Zero disables BM eligibility. Paid slips stay frozen.")
	for person in repo.data.persons:
		var current_salary = service.effective("salaries","person_id",person.id,today())
		if not current_salary.is_empty(): bm.add_child(label(person.name + " · " + P.money(int(current_salary.amount)),15))
	var who = select(bm,"Person",repo.data.persons)
	var salary = input(bm,"Monthly salary · whole rupees","0")
	var from = input(bm,"Effective from",today())
	var note = input(bm,"Reason / note")
	button(bm,"Preview salary change",func():
		if not salary.text.is_valid_int():
			status.text = "Enter whole rupees."
			return
		var person_id = selected(who)
		var value = service.salary_comparison(person_id,int(salary.text),from.text,today())
		if value.has("error"):
			status.text = value.error
			return
		confirm(value.note + "\nOld earnings: " + P.money(int(value.old)) + " → New: " + P.money(int(value.new)),func(): transact(func(): return service.salary(person_id,int(salary.text),from.text,note.text))))
	var correction = card("Correct an unpaid attendance rate")
	var available = []
	for row in repo.data.attendance:
		if row.settlement_id.is_empty() and row.role != "BM": available.append({"id":row.id,"name":row.person_id + " · " + row.role + " · " + P.money(int(row.rate))})
	var selected_row = select(correction,"Attendance row",available)
	var corrected = input(correction,"Correct rate","0")
	var correction_reason = input(correction,"Required edit reason")
	button(correction,"Save correction",func(): transact(func():
		if not corrected.text.is_valid_int(): return service.fail("Enter whole rupees.")
		return service.correct_rate(selected(selected_row),int(corrected.text),correction_reason.text)))
	var history = card("Rate and salary history")
	for collection in ["rates","salaries"]:
		for row in repo.data[collection]:
			history.add_child(label(row.get("mill_id",row.get("person_id","")) + " · " + row.get("role","BM") + " · " + row.effective_from + " · " + P.money(int(row.amount)) + " · " + row.reason,14))

func backup_reminder():
	var last = repo.data.settings.get("last_backup_at","")
	text("Last backup: " + ("Never — download one after entering records." if last.is_empty() else last),14)
	if last.is_empty() or P.day(today()) - P.day(last.left(10)) >= 7:
		text("Backup reminder: keep a fresh JSON copy at least every 7 days and after payments.",14)

func download(content: String, filename: String, mime: String):
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(),filename,mime)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.current_file = filename
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			var file = FileAccess.open(path,FileAccess.WRITE)
			if file: file.store_string(content)
			dialog.queue_free())
		dialog.popup_centered_ratio(0.7)

func import_backup():
	if OS.has_feature("web"):
		import_callback = JavaScriptBridge.create_callback(func(args): preview_restore(str(args[0])))
		var window = JavaScriptBridge.get_interface("window")
		window.paytrackImport = import_callback
		JavaScriptBridge.eval("var pick=document.createElement('input');pick.type='file';pick.accept='.json,application/json';pick.onchange=async()=>{if(pick.files[0])window.paytrackImport(await pick.files[0].text())};pick.click();",true)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.json ; JSON backup"])
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			preview_restore(FileAccess.get_file_as_string(path))
			dialog.queue_free())
		dialog.popup_centered_ratio(0.7)

func preview_restore(content: String):
	var result = repo.inspect_backup(content)
	if result.has("error"):
		status.text = result.error
		return
	pending_backup = content
	confirm("Replace local records? Backup contains %d people and %d payments. A local safety copy is retained." % [result.people,result.payments],func():
		if repo.restore(pending_backup):
			show_page("Home")
			status.text = "Backup restored and validated."
		else: status.text = repo.error)

func export_csv(collection: String):
	var rows: Array = repo.data[collection]
	if rows.is_empty():
		status.text = "No records to export."
		return
	var keys = rows[0].keys()
	keys.erase("before")
	var output = ",".join(keys) + "\n"
	for row in rows:
		var values = []
		for key in keys:
			var value = str(row.get(key,""))
			if value.begins_with("=") or value.begins_with("+") or value.begins_with("-") or value.begins_with("@"): value = "'" + value
			values.append('"' + value.replace('"','""') + '"')
		output += ",".join(values) + "\n"
	download(output,"paytrack-" + collection + ".csv","text/csv")

func read_member_overrides() -> Dictionary:
	var result = {}
	for key in member_overrides:
		var row = member_overrides[key]
		result[key] = {"recovery": -1 if row.recovery.text.is_empty() else int(row.recovery.text), "cash": -1 if row.cash.text.is_empty() else int(row.cash.text)}
	return result
