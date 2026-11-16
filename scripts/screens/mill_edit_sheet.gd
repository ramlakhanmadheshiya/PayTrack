class_name MillEditSheet
extends Sheet
## Add a mill, or edit one: name, F and H rates, hide, delete. Nothing else.

var mill_id := ""
var name_box: TextField
var f_rate := 0.0
var h_rate := 0.0
var _err: Label
var hi_field: TextField


static func open(mid: String) -> void:
	var s := MillEditSheet.new(Lang.t("add_mill") if mid == "" else Lang.t("edit_mill"), Lang.t("save"))
	s.mill_id = mid
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 8)
	var today := Dates.today()
	if mill_id != "":
		f_rate = DB.mill_rate(mill_id, "F", today)
		h_rate = DB.mill_rate(mill_id, "H", today)
	body.add_child(UI.label(Lang.t("mill_name"), UI.S_CAP, UI.TEXT2, 600))
	name_box = UI.text_field(Lang.t("mill_name_ph"), DB.mill(mill_id).get("name", ""), Lang.t("mill_name"))
	body.add_child(name_box)
	hi_field = RenameSheet.hindi_field(body, String(DB.mill(mill_id).get("hi", "")), name_box)
	body.add_child(UI.spacer(8))
	var c := UI.card()
	var rf := NumField.make(f_rate, Lang.t("rate_f_caption"), false, true, 110)
	rf.value_changed.connect(func(v): f_rate = v)
	var rh := NumField.make(h_rate, Lang.t("rate_h_caption"), false, true, 110)
	rh.value_changed.connect(func(v): h_rate = v)
	UI.add_rows(c, [
		UI.row(Lang.t("rate_f"), Lang.t("per_attendance"), rf, Callable(), false, UI.badge("F")),
		UI.row(Lang.t("rate_h"), Lang.t("per_attendance"), rh, Callable(), false, UI.badge("H")),
	])
	body.add_child(UI.label(Lang.t("rates"), UI.S_CAP, UI.TEXT2, 600))
	body.add_child(c)
	body.add_child(UI.wrapped(UI.label(Lang.t("rates_help") if mill_id == "" else Lang.t("rate_change_note"), UI.S_CAP, UI.TEXT2)))
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	body.add_child(UI.spacer(8))
	if mill_id != "":
		var archived: bool = DB.mill(mill_id).get("archived", false)
		var hc := UI.card()
		UI.add_rows(hc, [UI.row(Lang.t("hide_mill"), Lang.t("hide_mill_help2"), UI.switch(archived, func(v):
			DB.set_mill_archived(mill_id, v)
			close()
			UI.app.toast(Lang.t("saved"))), Callable(), false)])
		body.add_child(hc)
		if Sync.is_admin():
			body.add_child(UI.spacer(6))
			body.add_child(UI.button(Lang.t("delete_mill"), "danger", _delete, "trash"))
	else:
		_open_keyboard.call_deferred()


func _open_keyboard() -> void:
	if is_instance_valid(name_box):
		UI.app.numpad_open(name_box)


func _save() -> void:
	UI.app.numpad_close()
	var n := name_box.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	if DB.mill_name_taken(n, mill_id):
		_err.text = Lang.t("err_mill_exists")
		return
	if f_rate <= 0 or h_rate <= 0:
		_err.text = Lang.t("err_rates")
		return
	if mill_id == "":
		var nm: Dictionary = DB.add_mill(n, int(f_rate), int(h_rate))
		DB.set_hindi_spelling("mill", nm.id, hi_field.text)
		close()
		UI.app.toast(Lang.t("mill_added", [n]))
	else:
		DB.set_hindi_spelling("mill", mill_id, hi_field.text)
		DB.rename_mill(mill_id, n)
		DB.set_mill_rates(mill_id, int(f_rate), int(h_rate))
		close()
		UI.app.toast(Lang.t("saved"))


func _delete() -> void:
	var m := DB.mill(mill_id)
	var n := DB.mill_workers(mill_id).size()
	var msg := Lang.t("delete_mill_q", [m.name]) if n == 0 else Lang.t("delete_mill_q_workers", [m.name, n])
	var mid := mill_id
	UI.app.confirm(Lang.t("delete_mill"), msg, Lang.t("delete_mill"), func():
		var name: String = m.name
		DB.delete_mill(mid)
		close()
		UI.app.toast(Lang.t("mill_deleted", [name])), true)
