class_name AddWorkSheet
extends Sheet
## Add a new person (name, work, opening balance) or add work to someone.
## Work = which mill and which post (BM master / F fireman / H helper).

var fixed_mill := ""        # adding from a mill page
var person_id := ""         # "" = new person
var new_name := ""
var stage := "details"      # "pick" | "details"
var selected := {}          # mill_id -> [posts]
var salary := 0.0
var opening_kind := 0       # 0 none, 1 jama, 2 advance
var opening_amount := 0.0
var on_done: Callable
var _name_box: LineEdit
var _err: Label


static func open_new_person(prefill := "") -> void:
	var s := AddWorkSheet.new(Lang.t("new_person"), Lang.t("save"))
	s.new_name = prefill
	s.action_cb = s._save
	UI.app.present(s)


static func open_for_mill(mid: String) -> void:
	var s := AddWorkSheet.new(Lang.t("add_worker"))
	s.fixed_mill = mid
	s.stage = "pick"
	UI.app.present(s)


static func open_for_person(pid: String, cb: Callable = Callable()) -> void:
	var s := AddWorkSheet.new(Lang.t("add_work"), Lang.t("save"))
	s.person_id = pid
	s.action_cb = s._save
	s.on_done = cb
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	UI.clear(footer)
	body.add_theme_constant_override("separation", 10)
	if stage == "pick":
		var exclude := []
		for p in DB.mill_workers(fixed_mill):
			exclude.append(p.id)
		body.add_child(UI.wrapped(UI.label(Lang.t("pick_or_new", [DB.mill(fixed_mill).name]), UI.S_SUB, UI.TEXT2)))
		var l := PersonList.new()
		l.exclude = exclude
		l.allow_add = true
		l.show_recent = false
		l.on_pick = func(pid):
			person_id = pid
			_to_details()
		l.on_add = func(n):
			new_name = n
			_to_details()
		body.add_child(l)
		return
	if fixed_mill != "" and selected.is_empty():
		selected[fixed_mill] = []
	# Name (new person).
	if person_id == "":
		body.add_child(UI.label(Lang.t("name"), UI.S_CAP, UI.TEXT2, 600))
		_name_box = UI.text_field(Lang.t("name_ph"), new_name)
		_name_box.text_changed.connect(func(t): new_name = t; _check_name())
		body.add_child(_name_box)
		_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
		body.add_child(_err)
		_check_name()
	else:
		var pc := UI.card()
		var pn: String = DB.person(person_id).name
		UI.add_rows(pc, [UI.row(pn, Screens.person_work_summary(person_id), null, Callable(), false, UI.avatar(pn, 38))])
		body.add_child(pc)
		_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	# Work.
	body.add_child(UI.spacer(4))
	body.add_child(UI.label(Lang.t("work_at"), UI.S_CAP, UI.TEXT2, 600))
	var mills: Array = DB.mills_list()
	if fixed_mill != "":
		mills = [DB.mill(fixed_mill)]
	if mills.is_empty():
		body.add_child(UI.wrapped(UI.label(Lang.t("no_mills_for_work"), UI.S_SUB, UI.TEXT2)))
	else:
		var c := UI.card()
		var rows := []
		for m in mills:
			rows.append(_mill_posts_row(m))
		UI.add_rows(c, rows)
		body.add_child(c)
		body.add_child(UI.wrapped(UI.label(Lang.t("posts_help"), UI.S_CAP, UI.TEXT2)))
	# Salary for masters.
	if _any_bm() and (person_id == "" or DB.person(person_id).get("salaries", []).is_empty()):
		var sc := UI.card()
		var sf := NumField.make(salary, Lang.t("monthly_salary"), false, true, 130)
		sf.value_changed.connect(func(v): salary = v)
		UI.add_rows(sc, [UI.row(Lang.t("monthly_salary"), Lang.t("master_salary_help"), sf, Callable(), false, UI.badge("BM"))])
		body.add_child(sc)
	# Opening balance for a new person.
	if person_id == "":
		body.add_child(UI.spacer(4))
		body.add_child(UI.label(Lang.t("opening_balance"), UI.S_CAP, UI.TEXT2, 600))
		body.add_child(UI.segmented([Lang.t("none"), Lang.t("has_jama"), Lang.t("has_advance")], opening_kind, func(i): opening_kind = i; build()))
		if opening_kind > 0:
			var oc := UI.card()
			var of := NumField.make(opening_amount, Lang.t("opening_balance"), false, true, 130)
			of.value_changed.connect(func(v): opening_amount = v)
			UI.add_rows(oc, [UI.row(Lang.t("amount"), Lang.t("opening_jama_help") if opening_kind == 1 else Lang.t("opening_advance_help"), of, Callable(), false)])
			body.add_child(oc)
	if action_text == "":
		footer.add_child(UI.margin(UI.button(Lang.t("save"), "primary", _save), 16, 10, 16, 10))


func _to_details() -> void:
	stage = "details"
	build()


func _any_post_selected() -> bool:
	for mid in selected:
		if not selected[mid].is_empty():
			return true
	return false


func _any_bm() -> bool:
	for mid in selected:
		if "BM" in selected[mid]:
			return true
	return false


func _mill_posts_row(m: Dictionary) -> Control:
	var h := UI.hbox(6)
	for post in ["BM", "F", "H"]:
		var have := person_id != "" and DB.has_post(person_id, m.id, post)
		var on: bool = have or (selected.has(m.id) and post in selected[m.id])
		var t := Tap.new()
		var bg := UI.ACCENT if on else UI.FILL
		t.set_styles(UI.pad(UI.box(bg, 9), 10, 6), UI.pad(UI.box(bg.darkened(0.1), 9), 10, 6))
		t.custom_minimum_size = Vector2(48, 36)
		var l := UI.label(post, UI.S_SUB, Color.WHITE if on else UI.TEXT, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_child_ignoring(l)
		t.enabled = not have
		var mid: String = m.id
		var p: String = post
		t.tapped.connect(func():
			if not selected.has(mid):
				selected[mid] = []
			if p in selected[mid]:
				selected[mid].erase(p)
			else:
				selected[mid].append(p)
			build())
		h.add_child(t)
	return UI.row(m.name, "", h, Callable(), false)


func _check_name() -> void:
	if _err == null:
		return
	var n := new_name.strip_edges()
	var existing := DB.find_person_by_name(n)
	if n != "" and not existing.is_empty():
		_err.text = Lang.t("name_exists_hint", [existing.name, existing.name])
	else:
		_err.text = ""


func _save() -> void:
	UI.app.numpad_close()
	var posts := []
	for mid in selected:
		for p in selected[mid]:
			posts.append({"mill_id": mid, "post": p})
	if person_id == "":
		var n := new_name.strip_edges()
		if n == "":
			_err.text = Lang.t("err_name_empty")
			return
		if DB.person_name_taken(n):
			_same_person_question(n)
			return
		if _any_bm() and salary <= 0:
			_err.text = Lang.t("err_salary")
			return
		var p := DB.add_person(n, posts, int(salary))
		if opening_kind > 0 and opening_amount > 0:
			DB.set_opening_balance(p.khata_id, int(opening_amount) * (1 if opening_kind == 1 else -1))
		close()
		UI.app.toast(Lang.t("person_added", [n]))
		if fixed_mill == "":
			Screens.open_person(p.id)
	else:
		if posts.is_empty():
			_err.text = Lang.t("err_pick_post")
			return
		if _any_bm() and DB.person(person_id).get("salaries", []).is_empty():
			if salary <= 0:
				_err.text = Lang.t("err_salary")
				return
			DB.add_salary(person_id, "2000-01-01", int(salary))
		for po in posts:
			DB.add_post(person_id, po.mill_id, po.post)
		close()
		UI.app.toast(Lang.t("saved"))
		if on_done.is_valid():
			on_done.call()


func _same_person_question(n: String) -> void:
	var existing := DB.find_person_by_name(n)
	var s := Sheet.new(Lang.t("name_exists_title", [existing.name]))
	UI.app.present(s)
	var v := UI.vbox(12)
	v.add_child(UI.wrapped(UI.label(Lang.t("name_exists_body", [existing.name, existing.name]), UI.S_BODY, UI.TEXT2)))
	v.add_child(UI.button(Lang.t("same_person_yes", [existing.name]), "primary", func():
		s.close()
		if not _any_post_selected():
			close()
			Screens.open_person(existing.id)
			return
		person_id = existing.id
		_save()))
	v.add_child(UI.button(Lang.t("same_person_no"), "secondary", func():
		s.close()
		if _name_box:
			_name_box.text = n + " "
			_name_box.caret_column = _name_box.text.length()
			_name_box.grab_focus()))
	s.body.add_child(v)
