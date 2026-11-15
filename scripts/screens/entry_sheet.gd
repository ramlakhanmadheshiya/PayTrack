class_name EntrySheet
extends Sheet
## Give kharchi or advance, or note jama (money they give back to you).
## Also edits an entry. (Old "jama paid" entries still open and edit.)

const TYPES := ["kharchi", "advance", "received"]

var person_id := ""
var entry_id := ""
var type := "kharchi"
var amount := 0
var date := ""
var note := ""
var _amount_field: NumField
var _save_btn: Tap
var _locked := false


func build() -> void:
	if entry_id != "":
		var e := DB.entry(entry_id)
		person_id = e.person_id
		type = e.type
		amount = e.amount
		date = e.date
		note = e.note
		_locked = e.payment_id != ""
		title = Lang.t("edit_entry")
	else:
		title = Lang.t("new_entry")
	if date == "":
		date = Dates.today()
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	UI.clear(footer)
	body.add_theme_constant_override("separation", 14)
	if _locked:
		var info := UI.hbox(10)
		info.add_child(Icons.make("info", UI.TEXT2, 20))
		info.add_child(UI.wrapped(UI.label(Lang.t("entry_locked"), UI.S_SUB, UI.TEXT2)))
		body.add_child(info)
	# Type.
	if type != "adjust":
		var types: Array = TYPES.duplicate()
		if type == "payout":
			types.append("payout")
		var labels := []
		for t in types:
			labels.append(Lang.entry_type(t))
		body.add_child(UI.segmented(labels, types.find(type), func(i):
			if _locked: return
			type = types[i]
			_rebuild()))
		body.add_child(UI.wrapped(UI.label(Lang.t("type_help_" + type), UI.S_CAP, UI.TEXT2)))
	# Person.
	if person_id == "":
		var l := PersonList.new()
		l.on_pick = func(pid):
			person_id = pid
			_rebuild()
			_open_amount.call_deferred()
		body.add_child(l)
		return
	var p := DB.person(person_id)
	var pc := UI.card()
	var k := DB.khata_of(person_id)
	var sub := UI.balance_text(DB.balance(k.id))
	var kh := DB.open_kharchi(k.id)
	if kh > 0:
		sub += " · " + Lang.t("kharchi_open", [Money.group(kh)])
	if DB.is_family(k.id):
		sub = Lang.t("family_of", [DB.khata_title(k.id)]) + " · " + sub
	UI.add_rows(pc, [UI.row(p.name, sub, Lang.t("change") if entry_id == "" else "", (func(): person_id = ""; _rebuild()) if entry_id == "" else Callable(), false, UI.avatar(p.name, 40))])
	body.add_child(pc)
	# Amount.
	var ac := UI.card(16)
	var av := UI.card_body(ac)
	av.add_theme_constant_override("separation", 6)
	av.add_child(UI.label(Lang.t("amount"), UI.S_CAP, UI.TEXT2, 600))
	var h := UI.hbox(8)
	h.add_child(UI.label("₹", 30, UI.TEXT2, 500))
	_amount_field = NumField.make(amount, Lang.t("amount_for", [Lang.entry_type(type), p.name]), false, true, 160)
	_amount_field.font_size = 30
	_amount_field.align = HORIZONTAL_ALIGNMENT_LEFT
	_amount_field.placeholder = "0"
	_amount_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_field.enabled = not _locked
	_amount_field.value_changed.connect(func(v): amount = int(v); _update_save())
	h.add_child(_amount_field)
	av.add_child(h)
	body.add_child(ac)
	# Date and note.
	var dc := UI.card()
	var date_row := UI.row(Lang.t("date"), "", Lang.day_label(date), func():
		if _locked: return
		DateSheet.open(Lang.t("date"), date, func(d): date = d; _rebuild(), [[Lang.t("today"), Dates.today()], [Lang.t("yesterday"), Dates.add_days(Dates.today(), -1)]], "", Dates.today()))
	var note_box := TextField.make(note, Lang.t("note_optional"), Lang.t("note_optional"), "plain")
	note_box.capitalize_words = false
	note_box.enabled = not _locked
	note_box.text_changed.connect(func(t): note = t)
	UI.add_rows(dc, [date_row, note_box])
	body.add_child(dc)
	# Save / delete.
	if not _locked:
		_save_btn = UI.button("", "primary", _save)
		footer.add_child(UI.margin(_save_btn, 16, 10, 16, 10))
		if entry_id != "":
			body.add_child(UI.button(Lang.t("delete_entry"), "danger", _delete, "trash"))
	_update_save()


func _open_amount() -> void:
	if _amount_field and is_instance_valid(_amount_field) and not _locked:
		UI.app.numpad_open(_amount_field)


func _update_save() -> void:
	if _save_btn == null or not is_instance_valid(_save_btn):
		return
	var l: Label = _save_btn.get_child(0).get_child(_save_btn.get_child(0).get_child_count() - 1)
	l.text = Lang.t("save_amount", [Money.group(amount)]) if amount > 0 else Lang.t("save")
	_save_btn.enabled = amount > 0 and person_id != ""


func _save() -> void:
	if amount <= 0 or person_id == "":
		return
	UI.app.numpad_close()
	if entry_id != "":
		DB.update_entry(entry_id, type, amount, date, note.strip_edges())
		UI.app.toast(Lang.t("saved"))
	else:
		DB.add_entry(person_id, type, amount, date, note.strip_edges())
		UI.app.toast(Lang.t("entry_saved", [Lang.entry_type(type), Money.group(amount), DB.person(person_id).name]))
	close()


func _delete() -> void:
	var id := entry_id
	UI.app.confirm(Lang.t("delete_entry"), Lang.t("delete_entry_q"), Lang.t("delete"), func():
		DB.delete_entry(id)
		close()
		UI.app.toast(Lang.t("deleted")), true)
