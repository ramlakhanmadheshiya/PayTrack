class_name PickPersonSheet
extends Sheet
## Choose one person.

var on_pick: Callable
var exclude: Array = []


static func open(t: String, cb: Callable, excluded: Array = []) -> void:
	var s := PickPersonSheet.new(t)
	s.on_pick = cb
	s.exclude = excluded
	UI.app.present(s)


func build() -> void:
	var l := PersonList.new()
	l.exclude = exclude
	l.on_pick = func(pid):
		close()
		on_pick.call(pid)
	body.add_child(l)
