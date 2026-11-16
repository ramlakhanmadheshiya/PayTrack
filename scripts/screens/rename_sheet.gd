class_name RenameSheet
extends Sheet
## Rename a person (names must stay unique) and set how the name is written
## in Hindi.

var person_id := ""
var field: TextField
var hi_field: TextField
var _err: Label


static func open(pid: String) -> void:
	var s := RenameSheet.new(Lang.t("rename"), Lang.t("save"))
	s.person_id = pid
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 10)
	var p := DB.person(person_id)
	body.add_child(UI.label(Lang.t("edit_name"), UI.S_CAP, UI.TEXT2, 600))
	field = UI.text_field(Lang.t("name_ph"), p.name, Lang.t("name"))
	body.add_child(field)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	hi_field = hindi_field(body, String(p.get("hi", "")), field)
	(func(): if is_instance_valid(field): UI.app.numpad_open(field)).call_deferred()


static func hindi_field(box: VBoxContainer, spelling: String, name_field: TextField) -> TextField:
	## "Name in Hindi": typed in English letters, with the Hindi shown live.
	box.add_child(UI.spacer(4))
	box.add_child(UI.label(Lang.t("hindi_name"), UI.S_CAP, UI.TEXT2, 600))
	var f := UI.text_field(Lang.t("hindi_name_ph"), spelling, Lang.t("hindi_name"))
	f.capitalize_words = false
	box.add_child(f)
	var preview := UI.label("", UI.S_TITLE, UI.TEXT, 600)
	preview.set_meta("raw", true)
	box.add_child(preview)
	var upd := func(_t = ""):
		if is_instance_valid(preview):
			preview.text = Lang.name_hi(name_field.text.strip_edges(), f.text)
	f.text_changed.connect(upd)
	name_field.text_changed.connect(upd)
	upd.call()
	box.add_child(UI.wrapped(UI.label(Lang.t("hindi_name_help"), UI.S_CAP, UI.TEXT2)))
	return f


func _save() -> void:
	UI.app.numpad_close()
	var n := field.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	if DB.person_name_taken(n, person_id):
		_err.text = Lang.t("err_person_exists", [n])
		return
	DB.set_hindi_spelling("person", person_id, hi_field.text)
	DB.rename_person(person_id, n)
	close()
