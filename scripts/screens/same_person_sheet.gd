class_name SamePersonSheet
extends Sheet
## "Munna already exists. Same person?" — Yes uses the existing person,
## No goes back so a tag can be added to the name (e.g. "Munna Best").


static func ask(name: String, on_same: Callable, on_different: Callable) -> void:
	var existing := DB.find_person_by_name(name)
	var s := SamePersonSheet.new(Lang.t("name_exists_title", [existing.name]))
	UI.app.present(s)
	var v := UI.vbox(12)
	v.add_child(UI.wrapped(UI.label(Lang.t("name_exists_body", [existing.name, existing.name]), UI.S_BODY, UI.TEXT2)))
	v.add_child(UI.button(Lang.t("same_person_yes", [existing.name]), "primary", func(): s.close(); on_same.call()))
	v.add_child(UI.button(Lang.t("same_person_no"), "secondary", func(): s.close(); on_different.call()))
	s.body.add_child(v)
