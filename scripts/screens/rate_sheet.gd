class_name RateSheet
extends Sheet
## New F/H rate for a mill (from a date), or new monthly salary for a master.

var mill_id := ""
var person_id := ""
var from := ""
var f_rate := 0.0
var h_rate := 0.0
var salary := 0.0
var _err: Label


static func open_mill(mid: String) -> void:
	var s := RateSheet.new(Lang.t("edit_rates"), Lang.t("save"))
	s.mill_id = mid
	s.action_cb = s._save
	var today := Dates.today()
	s.f_rate = DB.mill_rate(mid, "F", today)
	s.h_rate = DB.mill_rate(mid, "H", today)
	s.from = Dates.first_of_month(today)
	UI.app.present(s)


static func open_salary(pid: String) -> void:
	var s := RateSheet.new(Lang.t("edit_salary"), Lang.t("save"))
	s.person_id = pid
	s.action_cb = s._save
	s.salary = DB.salary_on(pid, Dates.today())
	s.from = Dates.first_of_month(Dates.today())
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	var c := UI.card()
	if mill_id != "":
		var rf := NumField.make(f_rate, Lang.t("rate_f_caption"), false, true, 110)
		rf.value_changed.connect(func(v): f_rate = v)
		var rh := NumField.make(h_rate, Lang.t("rate_h_caption"), false, true, 110)
		rh.value_changed.connect(func(v): h_rate = v)
		UI.add_rows(c, [
			UI.row(Lang.t("rate_f"), Lang.t("per_attendance"), rf, Callable(), false, UI.badge("F")),
			UI.row(Lang.t("rate_h"), Lang.t("per_attendance"), rh, Callable(), false, UI.badge("H")),
		])
	else:
		var sf := NumField.make(salary, Lang.t("monthly_salary"), false, true, 130)
		sf.value_changed.connect(func(v): salary = v)
		UI.add_rows(c, [UI.row(Lang.t("monthly_salary"), DB.person(person_id).get("name", ""), sf, Callable(), false, UI.badge("BM"))])
	body.add_child(c)
	var dc := UI.card()
	var today := Dates.today()
	UI.add_rows(dc, [UI.row(Lang.t("starts_from"), "", Lang.date_full(from), func():
		DateSheet.open(Lang.t("starts_from"), from, func(d): from = d; build(), [
			[Lang.t("this_month"), Dates.first_of_month(today)],
			[Lang.t("next_month"), Dates.add_months(Dates.first_of_month(today), 1)],
			[Lang.t("today"), today]]))])
	body.add_child(dc)
	body.add_child(UI.wrapped(UI.label(Lang.t("rate_change_help", [Lang.date_full(from)]), UI.S_CAP, UI.TEXT2)))
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)


func _save() -> void:
	UI.app.numpad_close()
	if mill_id != "":
		if f_rate <= 0 or h_rate <= 0:
			_err.text = Lang.t("err_rates")
			return
		DB.add_mill_rate(mill_id, from, int(f_rate), int(h_rate))
	else:
		if salary <= 0:
			_err.text = Lang.t("err_salary")
			return
		DB.add_salary(person_id, from, int(salary))
	close()
	UI.app.toast(Lang.t("saved"))
