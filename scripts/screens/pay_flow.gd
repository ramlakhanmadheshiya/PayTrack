class_name PayFlow
extends Page
## Paying people. Step 0 (mill only): choose who; 1: attendance; 2: hisab; 3: done.

var mill_id := ""
var khata_ids: Array = []
var step := 1
var pay_date := ""
var drafts: Array = []
var selected := {}
var saved: Array = []
var _expanded := {}
var _errors := {}
var _amount_labels := {}
var _month_labels := {}
var _draft_total_labels := {}
var _total_label: Label
var _hisab_labels := {}
var _cash_labels: Array = []
var correcting: Array = []   # drafts of payments that were undone to be corrected


func _init() -> void:
	super._init()
	show_large_title = false


func setup() -> void:
	if pay_date == "":
		pay_date = Dates.today()
	if step == 0:
		for k in _mill_khatas():
			selected[k] = false
	elif drafts.is_empty():
		_make_drafts()
	super.setup()


func on_shown() -> void:
	refresh()


func on_data_changed() -> void:
	# Someone edited data elsewhere (e.g. added work from this screen): keep typed numbers.
	if step == 1 or step == 2:
		for d in drafts:
			DB.rebuild_rows(d)
	refresh()


func _mill_khatas() -> Array:
	var out := []
	for p in DB.mill_workers(mill_id):
		var kid: String = DB.khata_of(p.id).id
		if not kid in out:
			out.append(kid)
	out.sort_custom(func(a, b): return DB.khata_title(a).naturalnocasecmp_to(DB.khata_title(b)) < 0)
	return out


func _make_drafts() -> void:
	drafts.clear()
	for kid in khata_ids:
		var d := DB.make_draft(kid, pay_date, "", mill_id)
		d.upto_custom = false
		drafts.append(d)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func on_back() -> void:
	UI.app.numpad_close()
	if step == 2:
		step = 1
		scroll_top()
		refresh()
	elif step == 1 and mill_id != "":
		step = 0
		scroll_top()
		refresh()
	elif not correcting.is_empty():
		UI.app.confirm(Lang.t("correct_leave_title"), Lang.t("correct_leave_body"), Lang.t("keep_old_payment"), func():
			for d in correcting:
				DB.commit_payment(d)
			correcting.clear()
			UI.app.pop()
			UI.app.toast(Lang.t("old_payment_kept")))
	elif step == 1 and _has_typed():
		UI.app.confirm(Lang.t("discard_title"), Lang.t("discard_body"), Lang.t("discard"), func(): UI.app.pop(), true)
	else:
		UI.app.pop()


func back_label() -> String:
	if step == 2:
		return Lang.t("step_attendance")
	if step == 1 and mill_id != "":
		return Lang.t("choose_people")
	return Lang.t("back")


func _has_typed() -> bool:
	for d in drafts:
		for r in d.rows:
			if Calc.row_has_work(r):
				return true
	return false


func build(b: VBoxContainer) -> void:
	title = Lang.t("pay") if mill_id == "" else Lang.t("pay_mill_title", [DB.mill(mill_id).get("name", "")])
	_amount_labels.clear()
	_month_labels.clear()
	_draft_total_labels.clear()
	_hisab_labels.clear()
	_cash_labels.clear()
	if step < 3:
		b.add_child(_steps())
	match step:
		0:
			_build_choose(b)
		1:
			_build_attendance(b)
		2:
			_build_hisab(b)
		3:
			_build_done(b)


func _steps() -> Control:
	var h := UI.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var names := [Lang.t("step_attendance"), Lang.t("step_hisab"), Lang.t("step_done")]
	for i in 3:
		var n := i + 1
		var on := step == n or (step == 0 and n == 1)
		var done := step > n
		var circle := PanelContainer.new()
		circle.add_theme_stylebox_override("panel", UI.box(UI.ACCENT if (on or done) else UI.FILL, 11))
		circle.custom_minimum_size = Vector2(22, 22)
		var cc := CenterContainer.new()
		if done:
			cc.add_child(Icons.make("check", Color.WHITE, 14))
		else:
			cc.add_child(UI.label(str(n), 12, Color.WHITE if on else UI.TEXT2, 700))
		circle.add_child(cc)
		h.add_child(circle)
		h.add_child(UI.label(names[i], UI.S_CAP, UI.TEXT if on else UI.TEXT2, 600 if on else 500))
		if i < 2:
			var line := ColorRect.new()
			line.color = UI.LINE
			line.custom_minimum_size = Vector2(18, 2)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(line)
	return UI.margin(h, 16, 2, 16, 12)


# ---------------------------------------------------------------------------
# Step 0: who is being paid today (mill)
# ---------------------------------------------------------------------------

func _build_choose(b: VBoxContainer) -> void:
	var list := _mill_khatas()
	for k in list:
		if not selected.has(k):
			selected[k] = false
	b.add_child(UI.margin(UI.wrapped(UI.label(Lang.t("choose_help"), UI.S_SUB, UI.TEXT2)), 16, 0, 16, 10))
	var all_on := true
	for k in list:
		if not selected[k]:
			all_on = false
	b.add_child(UI.margin(UI.small_button(Lang.t("select_none") if all_on else Lang.t("select_all"), "tinted", func():
		for k in list:
			selected[k] = not all_on
		refresh()), 16, 0, 16, 10))
	var c := UI.card()
	var rows := []
	for kid in list:
		var on: bool = selected[kid]
		var from := DB.next_work_from(kid)
		var sub := Lang.t("work_from", [Lang.date_smart(from)]) if from != "" else Lang.t("first_payment")
		if DB.is_family(kid):
			sub = Lang.t("family_with", [DB.khata_subtitle(kid)]) + " · " + sub
		var lead := Icons.make("check_circle" if on else "circle", UI.ACCENT if on else UI.TEXT3, 26)
		var k2: String = kid
		rows.append(UI.row(DB.khata_title(kid), sub, UI.balance_label(DB.live_balance(kid)), func(): selected[k2] = not selected[k2]; refresh(), false, lead))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("family_note")))


func _selected_list() -> Array:
	var out := []
	for k in _mill_khatas():
		if selected.get(k, false):
			out.append(k)
	return out


# ---------------------------------------------------------------------------
# Step 1: attendance
# ---------------------------------------------------------------------------

func _build_attendance(b: VBoxContainer) -> void:
	# Payment date and work up to.
	var hc := UI.card()
	var uptos := {}
	for d in drafts:
		uptos[d.upto] = true
	var upto_text: String = Lang.date_full(drafts[0].upto) if uptos.size() == 1 and not drafts.is_empty() else Lang.t("different")
	UI.add_rows(hc, [
		UI.row(Lang.t("payment_date"), "", Lang.date_full(pay_date), _pick_pay_date, true, Icons.make("calendar", UI.ACCENT, 22)),
		UI.row(Lang.t("work_upto"), "", upto_text, _pick_upto_all, true, Icons.make("history", UI.ACCENT, 22)),
	])
	b.add_child(UI.margin(hc, 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("hold_note", [Lang.date_short(Dates.add_days(drafts[0].upto, 1)) if not drafts.is_empty() else ""]) if not drafts.is_empty() and drafts[0].upto < pay_date else ""))
	for i in drafts.size():
		b.add_child(UI.margin(_attendance_card(i), 16, 14, 16, 0))


func _attendance_card(i: int) -> Control:
	var d: Dictionary = drafts[i]
	var kid: String = d.khata_id
	var c := UI.card()
	var v := UI.card_body(c)
	# Header.
	var head := UI.hbox(10)
	head.add_child(UI.avatar(DB.khata_title(kid), 38))
	var hv := UI.vbox(1)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.ellipsis(UI.label(DB.khata_title(kid), UI.S_HEAD, UI.TEXT, 700)))
	if DB.is_family(kid):
		hv.add_child(UI.ellipsis(UI.label(Lang.t("family_with", [DB.khata_subtitle(kid)]), UI.S_CAP, UI.TEXT2)))
	head.add_child(hv)
	var per := Tap.new()
	per.set_styles(UI.pad(UI.box(UI.ACCENT_SOFT, 10), 10, 6), UI.pad(UI.box(Color("#D9E3F7"), 10), 10, 6))
	var pv := UI.vbox(0)
	pv.add_child(UI.label(Lang.t("work"), 11, UI.ACCENT, 600))
	pv.add_child(UI.label(Lang.period(d.from, d.upto), UI.S_CAP, UI.ACCENT, 700))
	per.add_child_ignoring(pv)
	per.tapped.connect(func(): _edit_period(i))
	head.add_child(per)
	v.add_child(UI.margin(head, 14, 12, 14, 10))
	if _errors.has(i):
		v.add_child(UI.margin(UI.wrapped(UI.label(Lang.t(_errors[i]), UI.S_SUB, UI.RED, 600)), 14, 0, 14, 8))
	# Rows.
	var last_person := ""
	var family := DB.is_family(kid)
	if d.rows.is_empty():
		v.add_child(UI.line(0))
		v.add_child(UI.margin(UI.wrapped(UI.label(Lang.t("no_work_rows"), UI.S_SUB, UI.TEXT2)), 14, 12, 14, 4))
	for j in d.rows.size():
		var r: Dictionary = d.rows[j]
		if family and r.person_id != last_person:
			v.add_child(UI.line(0))
			v.add_child(UI.margin(UI.label(DB.person(r.person_id).name, UI.S_SUB, UI.TEXT, 700), 14, 10, 14, 0))
			last_person = r.person_id
		elif j > 0:
			v.add_child(UI.line(14))
		else:
			v.add_child(UI.line(0))
		v.add_child(_work_row(i, j))
	# Footer.
	v.add_child(UI.line(0))
	var foot := UI.hbox(8)
	foot.add_child(UI.link(Lang.t("add_work"), func(): _add_work(i), UI.ACCENT, UI.S_SUB))
	foot.add_child(UI.flex())
	foot.add_child(UI.label(Lang.t("earnings"), UI.S_SUB, UI.TEXT2, 500))
	var tl := UI.label("", UI.S_HEAD, UI.TEXT, 700, true)
	_draft_total_labels[i] = tl
	foot.add_child(tl)
	v.add_child(UI.margin(foot, 8, 4, 14, 6))
	_update_draft_total(i)
	return c


func _work_row(i: int, j: int) -> Control:
	var d: Dictionary = drafts[i]
	var r: Dictionary = d.rows[j]
	var v := UI.vbox(8)
	var who: String = DB.person(r.person_id).get("name", "")
	var mname: String = DB.mill(r.mill_id).get("name", "?")
	# Line 1: badge, mill, rate, amount.
	var top := UI.hbox(8)
	top.add_child(UI.badge(r.post))
	var t1 := UI.vbox(0)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1.add_child(UI.ellipsis(UI.label(mname, UI.S_BODY, UI.TEXT, 600)))
	var rate_text := Lang.t("per_month", [Money.group(r.rate)]) if r.post == "BM" else Lang.t("per_att", [Money.group(r.rate)])
	if r.get("rate_custom", false):
		rate_text += " ✎"
	var rate_link := UI.link(rate_text, func(): _edit_rate(i, j), UI.TEXT2, UI.S_CAP)
	rate_link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rate_link.set_styles(UI.pad(StyleBoxEmpty.new(), 0, 2), UI.pad(UI.box(UI.FILL, 6), 0, 2))
	t1.add_child(rate_link)
	top.add_child(t1)
	var amt := UI.label("", UI.S_HEAD, UI.TEXT, 700, true)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount_labels["%d:%d" % [i, j]] = amt
	top.add_child(amt)
	v.add_child(top)
	var cap_prefix := "%s · %s %s" % [who, mname, r.post]
	if r.post != "BM":
		var fields := UI.hbox(10)
		fields.add_child(_field_with_caption(Lang.t("att"), r, "att", i, j, cap_prefix + " · " + Lang.t("attendance"), true))
		fields.add_child(_field_with_caption(Lang.t("hr"), r, "hr", i, j, cap_prefix + " · " + Lang.t("hours"), true))
		fields.add_child(UI.flex())
		v.add_child(fields)
	else:
		var months: Array = r.months
		if months.size() > 1:
			var sw := UI.hbox(8)
			sw.add_child(UI.label(Lang.t("normal"), UI.S_SUB, UI.TEXT if r.mode == "normal" else UI.TEXT3, 600))
			sw.add_child(UI.switch(r.mode == "split", func(on):
				UI.app.numpad_close()
				r.mode = "split" if on else "normal"
				refresh()))
			sw.add_child(UI.label(Lang.t("split"), UI.S_SUB, UI.TEXT if r.mode == "split" else UI.TEXT3, 600))
			sw.add_child(UI.flex())
			v.add_child(sw)
		if r.mode == "split" and months.size() > 1:
			for m in months.size():
				var mo: Dictionary = months[m]
				var mh := UI.hbox(10)
				var mv := UI.vbox(0)
				mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var ym: String = mo.ym + "-01"
				mv.add_child(UI.label("%s %d" % [Lang.month_long(Dates.month(ym)), Dates.year(ym)], UI.S_SUB, UI.TEXT, 600))
				mv.add_child(UI.label(Lang.t("days_salary", [mo.days, Money.group(mo.salary)]), UI.S_CAP, UI.TEXT2, 400, true))
				mh.add_child(mv)
				var f := NumField.make(mo.att, cap_prefix + " · " + Lang.month_short(Dates.month(ym)) + " · " + Lang.t("attendance"), true, false, 70)
				f.value_changed.connect(func(val): mo.att = val; _update_row(i, j))
				mh.add_child(f)
				var ml := UI.label("", UI.S_SUB, UI.TEXT2, 600, true)
				ml.custom_minimum_size.x = 76
				ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				_month_labels["%d:%d:%d" % [i, j, m]] = ml
				mh.add_child(ml)
				v.add_child(mh)
		else:
			var fields := UI.hbox(10)
			fields.add_child(_field_with_caption(Lang.t("att"), r, "att", i, j, cap_prefix + " · " + Lang.t("attendance"), true))
			var dl := UI.link(Lang.t("divide_days", [r.days, Lang.month_short(Dates.month(d.from))]), func(): _edit_days(i, j), UI.TEXT2, UI.S_SUB)
			dl.size_flags_vertical = Control.SIZE_SHRINK_END
			fields.add_child(dl)
			fields.add_child(UI.flex())
			v.add_child(fields)
	_update_row_label(i, j)
	return UI.margin(v, 14, 10, 14, 12)


func _field_with_caption(cap: String, r: Dictionary, key: String, i: int, j: int, np_caption: String, decimals: bool) -> Control:
	var v := UI.vbox(3)
	v.add_child(UI.label(cap, 11, UI.TEXT2, 600))
	var f := NumField.make(float(r.get(key, 0.0)), np_caption, decimals, false, 76)
	f.value_changed.connect(func(val): r[key] = val; _update_row(i, j))
	v.add_child(f)
	return v


func _update_row(i: int, j: int) -> void:
	_errors.erase(i)
	_update_row_label(i, j)
	_update_draft_total(i)


func _update_row_label(i: int, j: int) -> void:
	var r: Dictionary = drafts[i].rows[j]
	var key := "%d:%d" % [i, j]
	if _amount_labels.has(key) and is_instance_valid(_amount_labels[key]):
		var amt := Calc.row_amount(r)
		var l: Label = _amount_labels[key]
		l.text = "₹" + Money.group(amt) if Calc.row_has_work(r) else "—"
		l.add_theme_color_override("font_color", UI.TEXT if Calc.row_has_work(r) else UI.TEXT3)
	if r.post == "BM":
		var amounts := Calc.month_amounts(r.months)
		for m in r.months.size():
			var mk := "%d:%d:%d" % [i, j, m]
			if _month_labels.has(mk) and is_instance_valid(_month_labels[mk]):
				_month_labels[mk].text = "₹" + Money.group(amounts[m]) if float(r.months[m].att) > 0 else "—"


func _update_draft_total(i: int) -> void:
	var total := 0
	for r in drafts[i].rows:
		total += Calc.row_amount(r)
	if _draft_total_labels.has(i) and is_instance_valid(_draft_total_labels[i]):
		_draft_total_labels[i].text = "₹" + Money.group(total)
	if _total_label and is_instance_valid(_total_label):
		_total_label.text = "₹" + Money.group(_all_earnings())


func _all_earnings() -> int:
	var t := 0
	for d in drafts:
		for r in d.rows:
			t += Calc.row_amount(r)
	return t


func _pick_pay_date() -> void:
	var today := Dates.today()
	DateSheet.open(Lang.t("payment_date"), pay_date, func(dt):
		pay_date = dt
		for d in drafts:
			d.date = dt
			if not d.get("upto_custom", false):
				d.upto = Calc.default_upto(dt, d.from)
			DB.rebuild_rows(d)
		refresh(), [[Lang.t("today"), today], [Lang.t("yesterday"), Dates.add_days(today, -1)]], "", today)


func _pick_upto_all() -> void:
	var q := [[Lang.t("end_last_month"), Dates.last_of_previous_month(pay_date)], [Lang.t("payment_date"), pay_date]]
	DateSheet.open(Lang.t("work_upto"), drafts[0].upto if not drafts.is_empty() else pay_date, func(dt):
		for d in drafts:
			d.upto = dt
			d.upto_custom = dt != Calc.default_upto(pay_date, d.from)
			DB.rebuild_rows(d)
		_errors.clear()
		refresh(), q, "", pay_date)


func _edit_period(i: int) -> void:
	var d: Dictionary = drafts[i]
	var s := Sheet.new(Lang.t("work_period"))
	UI.app.present(s)
	var holder := UI.vbox(12)
	s.body.add_child(holder)
	var draw := func(me: Callable) -> void:
		UI.clear(holder)
		holder.add_child(UI.wrapped(UI.label(Lang.t("period_help", [DB.khata_title(d.khata_id)]), UI.S_SUB, UI.TEXT2)))
		var c := UI.card()
		var from_cb := Callable()
		if not d.get("from_locked", false):
			from_cb = func(): DateSheet.open(Lang.t("work_from_label"), d.from, func(dt): d.from = dt; DB.rebuild_rows(d); me.call(me), [], "", pay_date)
		UI.add_rows(c, [
			UI.row(Lang.t("work_from_label"), Lang.t("from_auto") if d.get("from_locked", false) else Lang.t("from_first"), Lang.date_full(d.from), from_cb, from_cb.is_valid()),
			UI.row(Lang.t("work_upto"), "", Lang.date_full(d.upto), func():
				DateSheet.open(Lang.t("work_upto"), d.upto, func(dt):
					d.upto = dt
					d.upto_custom = true
					DB.rebuild_rows(d)
					me.call(me), [[Lang.t("end_last_month"), Dates.last_of_previous_month(pay_date)], [Lang.t("payment_date"), pay_date]], d.from, pay_date), true),
		])
		holder.add_child(c)
		holder.add_child(UI.button(Lang.t("done"), "primary", func(): s.close(); _errors.erase(i); refresh()))
	draw.call(draw)
	s.closed.connect(func(): refresh())


func _edit_rate(i: int, j: int) -> void:
	var r: Dictionary = drafts[i].rows[j]
	var s := Sheet.new(Lang.t("rate_this_payment"), Lang.t("save"))
	var state := {"v": float(r.rate)}
	s.action_cb = func():
		UI.app.numpad_close()
		if state.v > 0:
			r.rate = int(state.v)
			r.rate_custom = true
			if r.post == "BM":
				for mo in r.months:
					mo.salary = int(state.v)
		s.close()
		refresh()
	UI.app.present(s)
	var c := UI.card()
	var f := NumField.make(r.rate, Lang.t("rate"), false, true, 120)
	f.value_changed.connect(func(v): state.v = v)
	UI.add_rows(c, [UI.row(Lang.t("monthly_salary") if r.post == "BM" else Lang.t("rate_per_att"), DB.mill(r.mill_id).get("name", ""), f, Callable(), false, UI.badge(r.post))])
	s.body.add_theme_constant_override("separation", 10)
	s.body.add_child(c)
	s.body.add_child(UI.wrapped(UI.label(Lang.t("rate_this_help"), UI.S_CAP, UI.TEXT2)))


func _edit_days(i: int, j: int) -> void:
	var r: Dictionary = drafts[i].rows[j]
	var s := Sheet.new(Lang.t("days_in_month"), Lang.t("save"))
	var state := {"v": float(r.days)}
	s.action_cb = func():
		UI.app.numpad_close()
		if state.v >= 1:
			r.days = int(state.v)
			r.days_custom = true
		s.close()
		refresh()
	UI.app.present(s)
	var c := UI.card()
	var f := NumField.make(r.days, Lang.t("days_in_month"), false, false, 90)
	f.value_changed.connect(func(v): state.v = v)
	UI.add_rows(c, [UI.row(Lang.t("days_in_month"), "", f, Callable(), false)])
	s.body.add_theme_constant_override("separation", 10)
	s.body.add_child(c)
	s.body.add_child(UI.wrapped(UI.label(Lang.t("days_help"), UI.S_CAP, UI.TEXT2)))


func _add_work(i: int) -> void:
	var d: Dictionary = drafts[i]
	var members := DB.khata_members(d.khata_id)
	if members.size() == 1:
		WorkSheet.open(members[0].id, "", func(): DB.rebuild_rows(d); refresh())
	else:
		var items := []
		for p in members:
			var pid: String = p.id
			items.append([p.name, "person", func(): WorkSheet.open(pid, "", func(): DB.rebuild_rows(d); refresh())])
		UI.app.menu(Lang.t("whose_work"), items)


# ---------------------------------------------------------------------------
# Step 2: hisab
# ---------------------------------------------------------------------------

func _go_hisab() -> void:
	UI.app.numpad_close()
	_errors.clear()
	for i in drafts.size():
		var err := DB.validate_draft(drafts[i])
		if err != "":
			_errors[i] = err
	if not _errors.is_empty():
		refresh()
		UI.app.toast(Lang.t("fix_errors"), "error")
		return
	for d in drafts:
		var h := DB.draft_hisab(d)
		if not d.has("choice_set"):
			d.choice = "full" if h.due > 0 else "keep"
	step = 2
	scroll_top()
	refresh()


func _build_hisab(b: VBoxContainer) -> void:
	var cash := PanelContainer.new()
	cash.add_theme_stylebox_override("panel", UI.pad(UI.box(UI.ACCENT, 18), 18, 14))
	var cv := UI.vbox(2)
	cv.add_child(UI.label(Lang.t("cash_needed"), UI.S_SUB, Color(1, 1, 1, 0.85), 600))
	var cl := UI.label("", UI.S_MONEY_BIG, Color.WHITE, 700, true)
	_cash_labels.append(cl)
	cv.add_child(cl)
	cv.add_child(UI.label(Lang.t("n_khatas", [drafts.size()]) + " · " + Lang.date_full(pay_date), UI.S_CAP, Color(1, 1, 1, 0.8), 500))
	cash.add_child(cv)
	b.add_child(UI.margin(cash, 16, 0, 16, 4))
	for i in drafts.size():
		b.add_child(UI.margin(_hisab_card(i), 16, 14, 16, 0))
	_update_cash()


func _hisab_card(i: int) -> Control:
	var d: Dictionary = drafts[i]
	var kid: String = d.khata_id
	var h := DB.draft_hisab(d)
	var c := UI.card()
	var v := UI.card_body(c)
	var head := UI.hbox(10)
	head.add_child(UI.avatar(DB.khata_title(kid), 38))
	var hv := UI.vbox(1)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.ellipsis(UI.label(DB.khata_title(kid), UI.S_HEAD, UI.TEXT, 700)))
	hv.add_child(UI.ellipsis(UI.label(Lang.t("work_period_short", [Lang.period(d.from, d.upto)]), UI.S_CAP, UI.TEXT2)))
	head.add_child(hv)
	v.add_child(UI.margin(head, 14, 12, 14, 8))
	var lines := UI.vbox(6)
	var family := DB.is_family(kid)
	for r in d.rows:
		if not Calc.row_has_work(r):
			continue
		lines.add_child(_hisab_line(_row_text(r, family), Money.group(Calc.row_amount(r)), UI.TEXT2))
	lines.add_child(_hisab_sep())
	lines.add_child(_hisab_line(Lang.t("earnings"), Money.group(h.earnings), UI.TEXT, 600))
	if h.prev_balance != 0:
		lines.add_child(_hisab_line(Lang.t("prev_jama") if h.prev_balance > 0 else Lang.t("prev_advance"), ("+ " if h.prev_balance > 0 else "− ") + Money.group(absi(h.prev_balance)), UI.GREEN if h.prev_balance > 0 else UI.RED))
	var entries := DB.open_entries(kid, d.date)
	if h.kharchi > 0:
		var kt := Tap.new()
		kt.set_styles(StyleBoxEmpty.new(), UI.box(UI.FILL, 6))
		var kh := _hisab_line(Lang.t("kharchi_n", [h.count_kharchi]) + ("  ▴" if _expanded.get(i, false) else "  ▾"), "− " + Money.group(h.kharchi), UI.TEXT)
		kt.add_child_ignoring(kh)
		kt.tapped.connect(func(): _expanded[i] = not _expanded.get(i, false); UI.app.numpad_close(); refresh())
		lines.add_child(kt)
		if _expanded.get(i, false):
			for e in entries:
				if e.type == "kharchi":
					var who: String = (DB.person(e.person_id).name + " · ") if family else ""
					lines.add_child(_hisab_line("    " + who + Lang.date_short(e.date), Money.group(e.amount), UI.TEXT3, 400, UI.S_CAP))
	if h.advance > 0:
		lines.add_child(_hisab_line(Lang.t("advance_given"), "− " + Money.group(h.advance), UI.RED))
	if h.payout > 0:
		lines.add_child(_hisab_line(Lang.t("type_payout"), "− " + Money.group(h.payout), UI.TEXT))
	if h.received > 0:
		lines.add_child(_hisab_line(Lang.t("type_received"), "+ " + Money.group(h.received), UI.GREEN))
	if h.adjust != 0:
		lines.add_child(_hisab_line(Lang.t("carried_in"), ("+ " if h.adjust > 0 else "− ") + Money.group(absi(h.adjust)), UI.TEXT))
	lines.add_child(_hisab_sep())
	var due_l := UI.hbox(8)
	var due_cap := Lang.t("due_to", [DB.khata_title(kid)]) if h.due >= 0 else Lang.t("owes_you", [DB.khata_title(kid)])
	due_l.add_child(UI.ellipsis(UI.label(due_cap, UI.S_BODY, UI.TEXT, 700)))
	var dv := UI.label("₹" + Money.group(absi(h.due)), UI.S_TITLE, UI.TEXT if h.due >= 0 else UI.RED, 700, true)
	due_l.add_child(dv)
	lines.add_child(due_l)
	v.add_child(UI.margin(lines, 14, 0, 14, 12))
	# Choice.
	v.add_child(UI.line(0))
	var choice_box := UI.vbox(10)
	var opts: Array
	var keys: Array
	if h.due > 0:
		opts = [Lang.t("pay_full"), Lang.t("pay_part"), Lang.t("keep_jama")]
		keys = ["full", "custom", "keep"]
	else:
		opts = [Lang.t("carry_forward"), Lang.t("pay_part")]
		keys = ["keep", "custom"]
	var cur: String = d.get("choice", "full")
	if not cur in keys:
		cur = keys[0]
		d.choice = cur
	choice_box.add_child(UI.segmented(opts, keys.find(cur), func(idx):
		d.choice = keys[idx]
		d.choice_set = true
		UI.app.numpad_close()
		refresh()))
	if cur == "custom":
		var ch := UI.hbox(10)
		ch.add_child(UI.expand(UI.label(Lang.t("cash_now"), UI.S_BODY, UI.TEXT, 500)))
		var f := NumField.make(d.get("custom", 0), Lang.t("cash_for", [DB.khata_title(kid)]), false, true, 130)
		f.value_changed.connect(func(val): d.custom = int(val); _update_hisab(i))
		ch.add_child(f)
		choice_box.add_child(ch)
	var res := UI.hbox(8)
	var pay_l := UI.label("", UI.S_BODY, UI.TEXT, 700, true)
	var bal_l := UI.label("", UI.S_SUB, UI.TEXT2, 600, true)
	bal_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	res.add_child(UI.expand(pay_l))
	res.add_child(bal_l)
	choice_box.add_child(res)
	_hisab_labels[i] = [pay_l, bal_l]
	v.add_child(UI.margin(choice_box, 14, 12, 14, 14))
	_update_hisab(i)
	return c


func _row_text(r: Dictionary, family: bool) -> String:
	var who: String = (DB.person(r.person_id).name + " · ") if family else ""
	var mill_name: String = DB.mill(r.mill_id).get("name", "?")
	if r.post == "BM":
		if r.mode == "split":
			var parts := []
			for mo in r.months:
				if float(mo.att) > 0:
					parts.append("%s %s/%d" % [Lang.month_short(Dates.month(mo.ym + "-01")), Money.num(mo.att), mo.days])
			return "%s%s BM · %s" % [who, mill_name, ", ".join(parts)]
		return "%s%s BM · %s ÷ %d" % [who, mill_name, Lang.t("n_att", [Money.num(r.att)]), r.days]
	var s := "%s%s %s · %s" % [who, mill_name, r.post, Lang.t("n_att", [Money.num(r.att)])]
	if float(r.hr) > 0:
		s += " + " + Lang.t("n_hr", [Money.num(r.hr)])
	return s


func _hisab_line(left: String, right: String, col: Color, weight := 400, size := UI.S_SUB) -> Control:
	var h := UI.hbox(8)
	var l := UI.label(left, size, col if col != UI.TEXT2 else UI.TEXT2, weight)
	UI.ellipsis(l)
	h.add_child(l)
	var r := UI.label(right, size, col, weight if weight > 400 else 500, true)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h


func _hisab_sep() -> Control:
	var r := ColorRect.new()
	r.color = UI.LINE
	r.custom_minimum_size.y = 1
	return r


func _update_hisab(i: int) -> void:
	var h := DB.draft_hisab(drafts[i])
	if _hisab_labels.has(i):
		var pay_l: Label = _hisab_labels[i][0]
		var bal_l: Label = _hisab_labels[i][1]
		if is_instance_valid(pay_l):
			pay_l.text = Lang.t("pay_now", [Money.group(h.paid)]) if h.paid > 0 else Lang.t("no_cash_now")
		if is_instance_valid(bal_l):
			bal_l.text = Lang.t("after_x", [UI.balance_text(h.new_balance)])
			bal_l.add_theme_color_override("font_color", UI.GREEN if h.new_balance > 0 else (UI.RED if h.new_balance < 0 else UI.TEXT2))
	_update_cash()


func _cash_total() -> int:
	var t := 0
	for d in drafts:
		t += int(DB.draft_hisab(d).paid)
	return t


func _update_cash() -> void:
	var t := _cash_total()
	for l in _cash_labels:
		if is_instance_valid(l):
			l.text = "₹" + Money.group(t)


func _confirm_save() -> void:
	UI.app.numpad_close()
	var total := _cash_total()
	var details := UI.card()
	var rows := []
	for d in drafts:
		var h := DB.draft_hisab(d)
		rows.append(UI.row(DB.khata_title(d.khata_id), Lang.t("after_x", [UI.balance_text(h.new_balance)]), UI.label("₹" + Money.group(h.paid), UI.S_BODY, UI.TEXT, 600, true), Callable(), false))
	UI.add_rows(details, rows)
	UI.app.confirm(Lang.t("confirm_title"), Lang.t("confirm_body", [drafts.size(), Money.group(total)]), Lang.t("save_payments"), _save_all, false, details)


func _save_all() -> void:
	for d in drafts:
		var err := DB.validate_draft(d)
		if err != "":
			UI.app.toast(Lang.t(err), "error")
			step = 1
			refresh()
			return
	saved.clear()
	correcting.clear()
	for d in drafts:
		var p := DB.commit_payment(d)
		if p.has("error"):
			UI.app.toast(Lang.t(p.error), "error")
			continue
		saved.append(p.id)
	step = 3
	scroll_top()
	refresh()


# ---------------------------------------------------------------------------
# Step 3: done
# ---------------------------------------------------------------------------

func _build_done(b: VBoxContainer) -> void:
	var v := UI.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", UI.box(UI.GREEN_SOFT, 40))
	circle.custom_minimum_size = Vector2(80, 80)
	var cc := CenterContainer.new()
	cc.add_child(Icons.make("check", UI.GREEN, 40))
	circle.add_child(cc)
	var ch := CenterContainer.new()
	ch.add_child(circle)
	v.add_child(UI.spacer(10))
	v.add_child(ch)
	var total := 0
	for id in saved:
		total += int(DB.payment(id).get("paid", 0))
	var t := UI.label(Lang.t("saved_n", [saved.size()]), UI.S_TITLE, UI.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.label(Lang.t("cash_given", [Money.group(total)]), UI.S_BODY, UI.TEXT2, 500, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	b.add_child(v)
	b.add_child(UI.section_title(Lang.t("bills")))
	var c := UI.card()
	var rows := []
	for id in saved:
		var p := DB.payment(id)
		if p.is_empty():
			continue
		var pid: String = id
		var right := UI.hbox(8)
		right.add_child(UI.small_button(Lang.t("correct"), "secondary", func(): Screens.correct_payment(pid)))
		right.add_child(UI.small_button(Lang.t("share"), "tinted", func(): Bill.share_payment(pid), "share"))
		rows.append(UI.row(p.payee_name, Lang.t("paid_x", [Money.group(p.paid)]) + " · " + UI.balance_text(p.new_balance), right, func(): Screens.open_payment(pid), true, UI.avatar(p.payee_name, 36, UI.GREEN_SOFT, UI.GREEN)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))


# ---------------------------------------------------------------------------
# Bottom bar
# ---------------------------------------------------------------------------

func bottom_bar() -> Control:
	match step:
		0:
			var n := _selected_list().size()
			var btn := UI.button(Lang.t("continue_n", [n]), "primary", func():
				khata_ids = _selected_list()
				_make_drafts()
				step = 1
				scroll_top()
				refresh())
			btn.enabled = n > 0
			return btn
		1:
			var h := UI.hbox(12)
			var v := UI.vbox(0)
			v.add_child(UI.label(Lang.t("total_earnings"), UI.S_CAP, UI.TEXT2, 600))
			_total_label = UI.label("₹" + Money.group(_all_earnings()), UI.S_TITLE, UI.TEXT, 700, true)
			v.add_child(_total_label)
			h.add_child(v)
			h.add_child(UI.flex())
			var btn := UI.button(Lang.t("next_hisab"), "primary", _go_hisab, "")
			btn.custom_minimum_size.x = 170
			h.add_child(btn)
			return h
		2:
			var h := UI.hbox(12)
			var v := UI.vbox(0)
			v.add_child(UI.label(Lang.t("cash_needed"), UI.S_CAP, UI.TEXT2, 600))
			var l := UI.label("", UI.S_TITLE, UI.TEXT, 700, true)
			_cash_labels.append(l)
			v.add_child(l)
			h.add_child(v)
			h.add_child(UI.flex())
			var btn := UI.button(Lang.t("save_payments"), "primary", _confirm_save)
			btn.custom_minimum_size.x = 170
			h.add_child(btn)
			_update_cash.call_deferred()
			return h
		3:
			return UI.button(Lang.t("done"), "primary", func(): UI.app.pop())
	return null
