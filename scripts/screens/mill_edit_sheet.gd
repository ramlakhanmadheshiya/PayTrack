class_name MillEditSheet
extends Sheet
## Add a mill (name + F/H rates) or rename one.

var mill_id := ""
var name_box: TextField
var f_rate := 0.0
var h_rate := 0.0
var _err: Label


static func open(mid: String) -> void:
	var s := MillEditSheet.new(Lang.t("add_mill") if mid == "" else Lang.t("rename_mill"), Lang.t("save"))
	s.mill_id = mid
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 8)
	body.add_child(UI.label(Lang.t("mill_name"), UI.S_CAP, UI.TEXT2, 600))
	name_box = UI.text_field(Lang.t("mill_name_ph"), DB.mill(mill_id).get("name", ""), Lang.t("mill_name"))
	body.add_child(name_box)
	if mill_id == "":
		body.add_child(UI.spacer(8))
		var c := UI.card()
		var rf := NumField.make(0, Lang.t("rate_f_caption"), false, true, 110)
		rf.value_changed.connect(func(v): f_rate = v)
		var rh := NumField.make(0, Lang.t("rate_h_caption"), false, true, 110)
		rh.value_changed.connect(func(v): h_rate = v)
		UI.add_rows(c, [
			UI.row(Lang.t("rate_f"), Lang.t("per_attendance"), rf, Callable(), false, UI.badge("F")),
			UI.row(Lang.t("rate_h"), Lang.t("per_attendance"), rh, Callable(), false, UI.badge("H")),
		])
		c.get_child(0).add_theme_constant_override("separation", 0)
		body.add_child(UI.label(Lang.t("rates"), UI.S_CAP, UI.TEXT2, 600))
		body.add_child(UI.margin(c, 0, 0, 0, 0))
		body.add_child(UI.wrapped(UI.label(Lang.t("rates_help"), UI.S_CAP, UI.TEXT2)))
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	_open_keyboard.call_deferred()


func _open_keyboard() -> void:
	if is_instance_valid(name_box):
		UI.app.numpad_open(name_box)


func _save() -> void:
	var n := name_box.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	if DB.mill_name_taken(n, mill_id):
		_err.text = Lang.t("err_mill_exists")
		return
	UI.app.numpad_close()
	if mill_id == "":
		if f_rate <= 0 or h_rate <= 0:
			_err.text = Lang.t("err_rates")
			return
		var m := DB.add_mill(n, int(f_rate), int(h_rate))
		close()
		UI.app.toast(Lang.t("mill_added", [n]))
		Screens.open_mill(m.id)
	else:
		DB.rename_mill(mill_id, n)
		close()
		UI.app.toast(Lang.t("saved"))
