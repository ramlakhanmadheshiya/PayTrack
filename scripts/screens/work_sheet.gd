class_name WorkSheet
extends Sheet
## What one person does at one mill: Master (BM), Fireman (F), Helper (H).
## Opened from the payment page (Add work) and for Add master.
## With no mill given, it first asks which mill.

var person_id := ""
var mill_id := ""
var posts: Array = []
var salary := 0.0
var on_done: Callable
var preset: Array = []     # posts ticked when a mill is chosen (e.g. ["BM"] for Add master)
var _err: Label


static func open(pid: String, mid := "", cb: Callable = Callable(), preset_posts: Array = []) -> void:
	var s := WorkSheet.new(Lang.t("work_at_mill"), Lang.t("save"))
	s.person_id = pid
	s.mill_id = mid
	s.on_done = cb
	s.preset = preset_posts
	s.action_cb = s._save
	if mid != "":
		s.posts = DB.posts_at(pid, mid)
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	var p := DB.person(person_id)
	var pc := UI.card()
	UI.add_rows(pc, [UI.row(p.name, Screens.person_work_summary(person_id), null, Callable(), false, UI.avatar(p.name, 38))])
	body.add_child(pc)
	# Which mill.
	if mill_id == "":
		set_action_enabled(false)
		body.add_child(UI.label(Lang.t("which_mill"), UI.S_CAP, UI.TEXT2, 600))
		var mc := UI.card()
		var rows := []
		var have: Array = DB.mills_of(person_id)
		for m in DB.mills_list():
			var mid: String = m.id
			var sub := Lang.t("already_works_here") if mid in have else ""
			rows.append(UI.row(m.name, sub, null, func():
				mill_id = mid
				posts = DB.posts_at(person_id, mid)
				if posts.is_empty():
					posts = preset.duplicate()
				build(), true, Icons.make("mill", UI.ACCENT, 22)))
		if rows.is_empty():
			body.add_child(UI.wrapped(UI.label(Lang.t("no_mills_for_work"), UI.S_SUB, UI.TEXT2)))
		else:
			UI.add_rows(mc, rows)
			body.add_child(mc)
		return
	set_action_enabled(true)
	body.add_child(UI.label(Lang.t("does_at", [DB.mill(mill_id).get("name", "")]), UI.S_CAP, UI.TEXT2, 600))
	var c := UI.card()
	var rows2 := []
	for post in ["BM", "F", "H"]:
		var on: bool = post in posts
		var pp: String = post
		rows2.append(UI.row(Lang.post_name(post), _post_help(post), UI.switch(on, func(v):
			if v and not pp in posts:
				posts.append(pp)
			elif not v:
				posts.erase(pp)
			build()), Callable(), false, UI.badge(post)))
	UI.add_rows(c, rows2)
	body.add_child(c)
	if "BM" in posts and p.get("salaries", []).is_empty():
		var sc := UI.card()
		var sf := NumField.make(salary, Lang.t("monthly_salary"), false, true, 130)
		sf.value_changed.connect(func(v): salary = v)
		UI.add_rows(sc, [UI.row(Lang.t("monthly_salary"), Lang.t("master_salary_help"), sf, Callable(), false, UI.badge("BM"))])
		body.add_child(sc)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	if not DB.posts_at(person_id, mill_id).is_empty():
		body.add_child(UI.spacer(6))
		body.add_child(UI.button(Lang.t("remove_from_mill", [DB.mill(mill_id).name]), "danger", _remove, "trash"))
		body.add_child(UI.wrapped(UI.label(Lang.t("remove_work_help"), UI.S_CAP, UI.TEXT2)))


func _post_help(post: String) -> String:
	var today := Dates.today()
	if post == "BM":
		var s := DB.salary_on(person_id, today)
		return Lang.t("per_month", [Money.group(s)]) if s > 0 else Lang.t("monthly_salary")
	return Lang.t("per_att", [Money.group(DB.mill_rate(mill_id, post, today))])


func _save() -> void:
	UI.app.numpad_close()
	if mill_id == "":
		return
	if posts.is_empty():
		_err.text = Lang.t("err_pick_post")
		return
	if "BM" in posts and DB.person(person_id).get("salaries", []).is_empty():
		if salary <= 0:
			_err.text = Lang.t("err_salary")
			return
		DB.add_salary(person_id, "2000-01-01", int(salary))
	DB.set_posts_at(person_id, mill_id, posts)
	close()
	UI.app.toast(Lang.t("saved"))
	if on_done.is_valid():
		on_done.call()


func _remove() -> void:
	var mid := mill_id
	var pid := person_id
	UI.app.confirm(Lang.t("remove_from_mill", [DB.mill(mid).name]), Lang.t("remove_work_q"), Lang.t("remove"), func():
		DB.set_posts_at(pid, mid, [])
		close()
		if on_done.is_valid():
			on_done.call(), true)
