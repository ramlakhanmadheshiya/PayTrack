class_name AddPersonSheet
extends Sheet
## New person: just the name and (optionally) a starting balance.
## Which mill and post they work is set later, from the mill ("Add worker").

var name_field: TextField
var opening_kind := 0       # 0 none, 1 jama, 2 advance
var opening_amount := 0.0
var on_created: Callable    # on_created(person_id)
var _err: Label
var _amount_holder: VBoxContainer


static func open(prefill := "", cb: Callable = Callable()) -> void:
	var s := AddPersonSheet.new(Lang.t("new_person"), Lang.t("save"))
	s.action_cb = s._save
	s.on_created = cb
	s.set_meta("prefill", prefill)
	UI.app.present(s)


func build() -> void:
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.label(Lang.t("name"), UI.S_CAP, UI.TEXT2, 600))
	name_field = UI.text_field(Lang.t("name_ph"), get_meta("prefill", ""), Lang.t("name"))
	name_field.text_changed.connect(func(_t): _check())
	body.add_child(name_field)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	body.add_child(UI.spacer(4))
	body.add_child(UI.label(Lang.t("opening_balance"), UI.S_CAP, UI.TEXT2, 600))
	_amount_holder = UI.vbox(8)
	body.add_child(_amount_holder)
	_rebuild_amount()
	body.add_child(UI.wrapped(UI.label(Lang.t("add_person_help"), UI.S_CAP, UI.TEXT2)))
	_check()
	_open_keyboard.call_deferred()


func _open_keyboard() -> void:
	if is_instance_valid(name_field):
		UI.app.numpad_open(name_field)


func _rebuild_amount() -> void:
	## The toggle is redrawn too, so the chosen option shows as selected.
	UI.clear(_amount_holder)
	_amount_holder.add_child(UI.segmented([Lang.t("none"), Lang.t("has_jama"), Lang.t("has_advance")], opening_kind, func(i):
		opening_kind = i
		_rebuild_amount()))
	if opening_kind == 0:
		return
	var c := UI.card()
	var f := NumField.make(opening_amount, Lang.t("opening_balance"), false, true, 130)
	f.value_changed.connect(func(v): opening_amount = v)
	UI.add_rows(c, [UI.row(Lang.t("amount"), Lang.t("opening_jama_help") if opening_kind == 1 else Lang.t("opening_advance_help"), f, Callable(), false)])
	_amount_holder.add_child(c)


func _check() -> void:
	var n := name_field.text.strip_edges()
	var existing := DB.find_person_by_name(n)
	_err.text = Lang.t("name_exists_hint", [existing.name, existing.name]) if n != "" and not existing.is_empty() else ""


func _save() -> void:
	UI.app.numpad_close()
	var n := name_field.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	if DB.person_name_taken(n):
		SamePersonSheet.ask(n, func(): close(); Screens.open_person(DB.find_person_by_name(n).id), func(): _open_keyboard())
		return
	var p := DB.add_person(n)
	if opening_kind > 0 and opening_amount > 0:
		DB.set_opening_balance(p.khata_id, int(opening_amount) * (1 if opening_kind == 1 else -1))
	close()
	UI.app.toast(Lang.t("person_added", [n]))
	if on_created.is_valid():
		on_created.call(p.id)
	else:
		Screens.open_person(p.id)
