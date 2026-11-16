class_name Bill
extends RefCounted
## The payment bill: shown on screen and shared as a photo (1 page) or PDF (more pages).

const PAGE_RATIO := 1.4142  # A4
const EXPORT_W := 1080


static func make(pay: Dictionary, k := 1.0) -> PanelContainer:
	## k scales every size (1 on screen, 1.5 for the shared image).
	var root := PanelContainer.new()
	var st := UI.box(Color.WHITE, int(16 * k))
	UI.pad(st, 22 * k, 22 * k)
	root.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(int(10 * k))
	root.add_child(v)
	var lines: Array = []
	root.set_meta("lines", lines)
	var S := func(n: float) -> int: return int(round(n * k))

	# Header.
	var head := UI.hbox(S.call(12))
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(40, 40) * k
	head.add_child(logo)
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label(Lang.t("payment_bill"), S.call(20), UI.TEXT, 700))
	hv.add_child(UI.label("PayTrack", S.call(13), UI.TEXT2, 500))
	head.add_child(hv)
	var dv := UI.vbox(0)
	var d1 := UI.label(Lang.date_full(pay.date), S.call(15), UI.TEXT, 600, true)
	d1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(d1)
	var d2 := UI.label(Lang.t("payment_date"), S.call(12), UI.TEXT2, 500)
	d2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(d2)
	head.add_child(dv)
	v.add_child(head)
	v.add_child(_rule(k, 2))

	# Who and period.
	var members: Array = pay.get("members", [])
	v.add_child(UI.label(pay.payee_name, S.call(24), UI.TEXT, 700))
	if members.size() > 1:
		var others := []
		for m in members:
			if m.name != pay.payee_name:
				others.append(m.name)
		v.add_child(UI.wrapped(UI.label(Lang.t("family_with", [", ".join(others)]), S.call(14), UI.TEXT2, 500)))
	v.add_child(_kv(Lang.t("work_period"), Lang.period(pay.from, pay.upto), k, UI.TEXT, 600))
	lines.append(v.get_child(v.get_child_count() - 1))

	# Work rows grouped by person.
	v.add_child(UI.spacer(4 * k))
	v.add_child(_section(Lang.t("work_done"), k))
	var family := members.size() > 1
	var last := ""
	for r in pay.rows:
		if family and r.person_id != last:
			v.add_child(UI.label(r.get("person_name", ""), S.call(15), UI.TEXT, 700))
			last = r.person_id
		v.add_child(_work_line(r, k))
		lines.append(v.get_child(v.get_child_count() - 1))
	if pay.rows.is_empty():
		v.add_child(UI.label(Lang.t("no_work_this_time"), S.call(14), UI.TEXT2))
	v.add_child(_rule(k))
	v.add_child(_kv(Lang.t("earnings"), "₹" + Money.group(pay.earnings), k, UI.TEXT, 700))
	lines.append(v.get_child(v.get_child_count() - 1))

	# Deductions.
	v.add_child(UI.spacer(4 * k))
	v.add_child(_section(Lang.t("hisab"), k))
	if int(pay.prev_balance) != 0:
		v.add_child(_kv(Lang.t("prev_jama") if pay.prev_balance > 0 else Lang.t("prev_advance"), ("+ " if pay.prev_balance > 0 else "− ") + "₹" + Money.group(absi(pay.prev_balance)), k, UI.GREEN if pay.prev_balance > 0 else UI.RED))
	var entries: Array = DB.payment_entries(pay)
	if int(pay.kharchi) > 0:
		v.add_child(_kv(Lang.t("kharchi_n", [int(pay.count_kharchi)]), "− ₹" + Money.group(pay.kharchi), k))
		lines.append(v.get_child(v.get_child_count() - 1))
		var col := UI.vbox(S.call(2))
		for e in entries:
			if e.type != "kharchi":
				continue
			var who: String = (DB.person(e.person_id).get("name", "") + " · ") if family else ""
			var line := _kv("    " + who + Lang.date_short(e.date) + (" · " + e.note if e.note != "" else ""), "₹" + Money.group(e.amount), k, UI.TEXT2, 400, 13)
			col.add_child(line)
		v.add_child(col)
		for c in col.get_children():
			lines.append(c)
	for t in ["advance", "payout", "received"]:
		var amt := int(pay.get(t, 0))
		if amt > 0:
			var sign := "+ " if t == "received" else "− "
			v.add_child(_kv(Lang.t("advance_given") if t == "advance" else Lang.entry_type(t), sign + "₹" + Money.group(amt), k, UI.RED if t == "advance" else UI.TEXT))
			lines.append(v.get_child(v.get_child_count() - 1))
			for e in entries:
				if e.type == t:
					v.add_child(_kv("    " + Lang.date_short(e.date) + (" · " + e.note if e.note != "" else ""), "₹" + Money.group(e.amount), k, UI.TEXT2, 400, 13))
					lines.append(v.get_child(v.get_child_count() - 1))
	if int(pay.adjust) != 0:
		v.add_child(_kv(Lang.t("carried_in"), ("+ " if pay.adjust > 0 else "− ") + "₹" + Money.group(absi(pay.adjust)), k))
	v.add_child(_rule(k))
	var due: int = pay.due
	v.add_child(_kv(Lang.t("total_due") if due >= 0 else Lang.t("total_owed"), "₹" + Money.group(absi(due)), k, UI.TEXT if due >= 0 else UI.RED, 700, 17))
	lines.append(v.get_child(v.get_child_count() - 1))

	# Result box.
	var res := PanelContainer.new()
	var bal: int = pay.new_balance
	var soft := UI.GREEN_SOFT if bal > 0 else (UI.RED_SOFT if bal < 0 else UI.FILL)
	res.add_theme_stylebox_override("panel", UI.pad(UI.box(soft, int(12 * k)), 16 * k, 12 * k))
	var rv := UI.vbox(S.call(6))
	rv.add_child(_kv(Lang.t("cash_paid"), "₹" + Money.group(pay.paid), k, UI.TEXT, 700, 19))
	var bal_text := Lang.t("bill_jama", [Money.group(bal)]) if bal > 0 else (Lang.t("bill_advance", [Money.group(-bal)]) if bal < 0 else Lang.t("bill_clear"))
	rv.add_child(UI.wrapped(UI.label(bal_text, S.call(15), UI.GREEN if bal > 0 else (UI.RED if bal < 0 else UI.TEXT2), 600)))
	res.add_child(rv)
	v.add_child(UI.spacer(6 * k))
	v.add_child(res)
	lines.append(res)
	var foot := UI.label(Lang.t("bill_footer"), S.call(11), UI.TEXT3, 400)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	lines.append(foot)
	return root


static func _section(text: String, k: float) -> Control:
	return UI.label(text.to_upper() if Lang.lang == "en" else text, int(12 * k), UI.TEXT2, 700)


static func _rule(k: float, w := 1) -> Control:
	var r := ColorRect.new()
	r.color = UI.LINE if w == 1 else UI.TEXT
	r.custom_minimum_size.y = maxf(1.0, w * k)
	return r


static func _kv(left: String, right: String, k: float, col := UI.TEXT, weight := 500, size := 15) -> Control:
	var h := UI.hbox(int(10 * k))
	var l := UI.label(left, int(size * k), col if col != UI.TEXT else UI.TEXT, weight if weight < 700 else 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := UI.label(right, int(size * k), col, weight, true)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(r)
	return h


static func _work_line(r: Dictionary, k: float) -> Control:
	var v := UI.vbox(int(1 * k))
	var mill_name: String = r.get("mill_name", "")
	var title := "%s · %s" % [mill_name, Lang.post_name(r.post)]
	v.add_child(_kv(title, "₹" + Money.group(r.amount), k, UI.TEXT, 600))
	var detail := ""
	if r.post == "BM":
		if r.get("mode", "normal") == "split":
			var parts := []
			for mo in r.months:
				if float(mo.att) > 0:
					parts.append("%s: ₹%s × %s ÷ %d = ₹%s" % [Lang.month_short(Dates.month(mo.ym + "-01")), Money.group(mo.salary), Money.num(mo.att), mo.days, Money.group(mo.amount)])
			detail = "\n".join(parts)
		else:
			detail = "₹%s × %s ÷ %d %s" % [Money.group(r.rate), Money.num(r.att), r.days, Lang.t("days")]
	else:
		detail = "₹%s × %s %s" % [Money.group(r.rate), Money.num(r.att), Lang.t("att")]
		if float(r.hr) > 0:
			detail += "  +  ₹%s × %s %s ÷ 12" % [Money.group(r.rate), Money.num(r.hr), Lang.t("hr")]
	var d := UI.label(detail, int(13 * k), UI.TEXT2, 400, true)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return v


# ---------------------------------------------------------------------------
# Sharing
# ---------------------------------------------------------------------------

static func share_payment(pay_id: String) -> void:
	var pay := DB.payment(pay_id)
	if pay.is_empty():
		return
	UI.app.toast(Lang.t("preparing_bill"))
	var k := EXPORT_W / 720.0
	var vp := SubViewport.new()
	vp.size = Vector2i(EXPORT_W, 400)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(EXPORT_W, 20000)
	vp.add_child(bg)
	var bill := make(pay, k)
	var st := UI.box(Color.WHITE, 0)
	UI.pad(st, 48 * k / 1.5, 40 * k / 1.5)
	bill.add_theme_stylebox_override("panel", st)
	bill.theme = UI.app.theme
	bill.custom_minimum_size.x = EXPORT_W
	bill.size.x = EXPORT_W
	vp.add_child(bill)
	UI.app.add_child(vp)
	var tree := UI.app.get_tree()
	await tree.process_frame
	await tree.process_frame
	var h := int(ceil(bill.get_combined_minimum_size().y))
	bill.size = Vector2(EXPORT_W, h)
	vp.size = Vector2i(EXPORT_W, h)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var page_h := int(EXPORT_W * PAGE_RATIO)
	var base := "Bill-%s-%s" % [String(pay.payee_name).replace(" ", "-"), pay.date]
	var text := Lang.show(Lang.t("bill_share_text", [pay.payee_name, Lang.date_full(pay.date)]))
	if h <= int(page_h * 1.1):
		Platform.share_bytes(img.save_png_to_buffer(), base + ".png", "image/png", text)
	else:
		# Break pages between lines, never through one.
		var breaks: Array = []
		for c in bill.get_meta("lines", []):
			if is_instance_valid(c):
				breaks.append(int(c.get_global_rect().end.y - bill.get_global_rect().position.y) + 4)
		breaks.sort()
		var pages: Array = []
		var top := 0
		while top < h:
			var limit := top + page_h
			var cut := h
			if limit < h:
				cut = top
				for bpos in breaks:
					if bpos > top + 40 and bpos <= limit:
						cut = bpos
				if cut <= top:
					cut = limit
			var page := Image.create(EXPORT_W, page_h, false, Image.FORMAT_RGB8)
			page.fill(Color.WHITE)
			var part := img.get_region(Rect2i(0, top, EXPORT_W, cut - top))
			part.convert(Image.FORMAT_RGB8)
			page.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(0, 24 if top > 0 else 0))
			pages.append(page)
			top = cut
		Platform.share_bytes(Pdf.from_images(pages), base + ".pdf", "application/pdf", text)
	vp.queue_free()
