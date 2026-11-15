class_name RenameSheet
extends Sheet
## Rename a person (names must stay unique).

var person_id := ""
var field: TextField
var _err: Label


static func open(pid: String) -> void:
	var s := RenameSheet.new(Lang.t("rename"), Lang.t("save"))
	s.person_id = pid
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 10)
	field = UI.text_field(Lang.t("name_ph"), DB.person(person_id).name, Lang.t("name"))
	body.add_child(field)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	(func(): if is_instance_valid(field): UI.app.numpad_open(field)).call_deferred()


func _save() -> void:
	UI.app.numpad_close()
	var n := field.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	if DB.person_name_taken(n, person_id):
		_err.text = Lang.t("err_person_exists", [n])
		return
	DB.rename_person(person_id, n)
	close()
