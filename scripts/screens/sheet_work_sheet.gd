class_name SheetWorkSheet
extends Sheet
## What one person did at one mill in one month: Master / Fireman / Helper.

var sheet_id := ""
var mill_id := ""
var person_id := ""
var posts: Array = []
var salary := 0.0
var _err: Label


static func open(sid: String, mid: String, pid: String) -> void:
	var s := SheetWorkSheet.new(Lang.t("worker_options"), Lang.t("save"))
	s.sheet_id = sid
	s.mill_id = mid
	s.person_id = pid
	s.posts = DB.sheet_posts(sid, mid, pid).duplicate()
	if s.posts.is_empty():
		s.posts = DB.posts_at(pid, mid)
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	var p := DB.person(person_id)
	var pc := UI.card()
	UI.add_rows(pc, [UI.row(p.name, Lang.t("in_month", [DB.mill(mill_id).name, Lang.month_ym(DB.sheet(sheet_id).ym)]), null, Callable(), false, UI.avatar(p.name, 38))])
	body.add_child(pc)
	body.add_child(UI.label(Lang.t("does_at", [DB.mill(mill_id).get("name", "")]), UI.S_CAP, UI.TEXT2, 600))
	var c := UI.card()
	var rows := []
	for post in DB.POSTS:
		var on: bool = post in posts
		var pp: String = post
		rows.append(UI.row(Lang.post_name(post), "", UI.switch(on, func(v):
			if v and not pp in posts:
				posts.append(pp)
			elif not v:
				posts.erase(pp)
			build()), Callable(), false, UI.badge(post)))
	UI.add_rows(c, rows)
	body.add_child(c)
	if "BM" in posts and p.get("salaries", []).is_empty():
		var sc := UI.card()
		var sf := NumField.make(salary, Lang.t("monthly_salary"), false, true, 130)
		sf.value_changed.connect(func(v): salary = v)
		UI.add_rows(sc, [UI.row(Lang.t("monthly_salary"), Lang.t("master_salary_help"), sf, Callable(), false, UI.badge("BM"))])
		body.add_child(sc)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	if not DB.sheet_posts(sheet_id, mill_id, person_id).is_empty():
		body.add_child(UI.button(Lang.t("remove_from_list"), "danger", func():
			DB.sheet_set_worker(sheet_id, mill_id, person_id, [])
			close(), "trash"))


func _save() -> void:
	UI.app.numpad_close()
	if posts.is_empty():
		_err.text = Lang.t("err_pick_post")
		return
	if "BM" in posts and DB.person(person_id).get("salaries", []).is_empty():
		if salary <= 0:
			_err.text = Lang.t("err_salary")
			return
		DB.add_salary(person_id, "2000-01-01", int(salary))
	var is_new := DB.sheet_posts(sheet_id, mill_id, person_id).is_empty()
	DB.sheet_set_worker(sheet_id, mill_id, person_id, posts)
	close()
	UI.app.toast(Lang.t("worker_added", [DB.person(person_id).name]) if is_new else Lang.t("saved"))
