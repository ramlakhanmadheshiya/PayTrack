class_name OpeningSheet
extends Sheet
## Starting balance (jama or advance from before PayTrack), until the first payment.

var khata_id := ""
var kind := 0
var amount := 0.0
var _holder: VBoxContainer


static func open(kid: String) -> void:
	var s := OpeningSheet.new(Lang.t("opening_balance"), Lang.t("save"))
	s.khata_id = kid
	var cur: int = int(DB.khata(kid).get("opening", 0))
	s.kind = 1 if cur > 0 else (2 if cur < 0 else 0)
	s.amount = float(absi(cur))
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 12)
	body.add_child(UI.wrapped(UI.label(Lang.t("opening_help_long"), UI.S_SUB, UI.TEXT2)))
	_holder = UI.vbox(12)
	body.add_child(_holder)
	_draw()


func _draw() -> void:
	UI.clear(_holder)
	_holder.add_child(UI.segmented([Lang.t("none"), Lang.t("has_jama"), Lang.t("has_advance")], kind, func(i): kind = i; _draw()))
	if kind > 0:
		var c := UI.card()
		var f := NumField.make(amount, Lang.t("opening_balance"), false, true, 130)
		f.value_changed.connect(func(v): amount = v)
		UI.add_rows(c, [UI.row(Lang.t("amount"), Lang.t("opening_jama_help") if kind == 1 else Lang.t("opening_advance_help"), f, Callable(), false)])
		_holder.add_child(c)


func _save() -> void:
	UI.app.numpad_close()
	var a := int(amount)
	DB.set_opening_balance(khata_id, 0 if kind == 0 else (a if kind == 1 else -a))
	close()
	UI.app.toast(Lang.t("saved"))
