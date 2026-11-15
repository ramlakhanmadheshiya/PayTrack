class_name AddWorkerSheet
extends Sheet
## From a mill: choose someone already in PayTrack, or type a new name.
## Then WorkSheet asks what they do at this mill.

var mill_id := ""


static func open(mid: String) -> void:
	var s := AddWorkerSheet.new(Lang.t("add_worker"))
	s.mill_id = mid
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.wrapped(UI.label(Lang.t("pick_or_new", [DB.mill(mill_id).name]), UI.S_SUB, UI.TEXT2)))
	var exclude := []
	for p in DB.mill_workers(mill_id):
		exclude.append(p.id)
	var l := PersonList.new()
	l.exclude = exclude
	l.allow_add = true
	l.show_recent = false
	l.on_pick = func(pid):
		close()
		WorkSheet.open(pid, mill_id)
	l.on_add = func(n: String):
		var p := DB.add_person(n)
		close()
		WorkSheet.open(p.id, mill_id)
	body.add_child(l)
	l.open_keyboard.call_deferred()
