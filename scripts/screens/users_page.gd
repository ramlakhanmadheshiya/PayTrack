class_name UsersPage
extends Page
## Admin only: who can use the shared PayTrack. Add a user (gets a one-time
## code), change what they can do, give a new code for a new phone, remove.

var users: Array = []
var _loaded := false
var _error := ""


func _init() -> void:
	super._init()


func on_shown() -> void:
	refresh()
	_load()


func setup() -> void:
	super.setup()
	_load()


func _load() -> void:
	var r: Dictionary = await Sync.list_users()
	if not is_instance_valid(self):
		return
	_loaded = true
	_error = String(r.get("error", ""))
	users = r.get("users", users)
	refresh()


func build(b: VBoxContainer) -> void:
	title = Lang.t("users")
	b.add_child(UI.section_title(Lang.t("users"), UI.small_button(Lang.t("add_user"), "tinted", func(): AddUserSheet.open(func(): _load()), "plus")))
	var c := UI.card()
	if not _loaded:
		UI.card_body(c).add_child(UI.margin(UI.label(Lang.t("loading"), UI.S_SUB, UI.TEXT2), 16, 14, 16, 14))
	elif _error != "" and users.is_empty():
		UI.card_body(c).add_child(UI.margin(UI.wrapped(UI.label(Lang.t(_error), UI.S_SUB, UI.RED, 500)), 16, 14, 16, 14))
	else:
		var active := []
		var removed := []
		for u in users:
			(removed if u.get("removed", false) else active).append(_user_row(u))
		UI.add_rows(c, active)
		b.add_child(UI.margin(c, 16, 0, 16, 0))
		_role_notes(b)
		if not removed.is_empty():
			b.add_child(UI.section_title(Lang.t("removed_users", [removed.size()])))
			var rc := UI.card()
			UI.add_rows(rc, removed)
			b.add_child(UI.margin(rc, 16, 0, 16, 0))
		return
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	_role_notes(b)


func _role_notes(b: VBoxContainer) -> void:
	b.add_child(UI.footnote(Lang.t("role_editor") + ": " + Lang.t("role_editor_help")))
	b.add_child(UI.footnote(Lang.t("role_viewer") + ": " + Lang.t("role_viewer_help")))


func _user_row(u: Dictionary) -> Control:
	var now := int(Time.get_unix_time_from_system())
	var id: String = u.id
	var name: String = u.name
	var me: bool = id == String(Sync.me.get("id", ""))
	var sub := Sync.role_name(String(u.role))
	if u.get("removed", false):
		sub = Lang.t("user_removed")
	elif not u.get("joined", false):
		sub += " · " + Lang.t("user_waiting")
	elif u.get("last_seen") != null and float(u.last_seen) > 0:
		sub += " · " + Lang.t("last_seen", [Lang.ago(now - int(float(u.last_seen) / 1000.0))])
	var shown := Lang.name_of(name) + (" (" + Lang.t("you") + ")" if me else "")
	var col := UI.TEXT3 if u.get("removed", false) else UI.ACCENT
	return UI.row(shown, sub, null, func(): _menu(u), true, UI.avatar(name, 38, UI.ACCENT_SOFT, col))


func _menu(u: Dictionary) -> void:
	var id: String = u.id
	var name: String = u.name
	var me: bool = id == String(Sync.me.get("id", ""))
	var items := [[Lang.t("rename_user"), "edit", func(): _rename(u)]]
	if not me:
		if not u.get("removed", false):
			items.append([Lang.t("change_role"), "people", func(): _role(u)])
		items.append([Lang.t("rejoin_code") if u.get("removed", false) else Lang.t("new_phone"), "undo", func():
			UI.app.confirm(Lang.t("new_phone"), Lang.t("new_phone_q", [name]), Lang.t("new_phone"), func(): _new_code(u))])
		if not u.get("removed", false):
			items.append([Lang.t("remove_user"), "trash", func():
				UI.app.confirm(Lang.t("remove_user"), Lang.t("remove_user_q", [name]), Lang.t("remove_user"), func(): _change(id, {"remove": true}, Lang.t("user_removed_toast", [name])), true), true])
	UI.app.menu(name, items)


func _role(u: Dictionary) -> void:
	var id: String = u.id
	UI.app.menu(u.name, [
		[Lang.t("role_editor"), "edit", func(): _change(id, {"role": "editor"}, Lang.t("saved"))],
		[Lang.t("role_viewer"), "history", func(): _change(id, {"role": "viewer"}, Lang.t("saved"))],
	])


func _rename(u: Dictionary) -> void:
	var s := Sheet.new(Lang.t("rename_user"), Lang.t("save"))
	var id: String = u.id
	var f := UI.text_field(Lang.t("user_name_ph"), u.name, Lang.t("user_name"))
	s.action_cb = func():
		UI.app.numpad_close()
		var n := f.text.strip_edges()
		if n != "":
			s.close()
			_change(id, {"name": n}, Lang.t("saved"))
	UI.app.present(s)
	s.body.add_child(f)
	(func(): if is_instance_valid(f): UI.app.numpad_open(f)).call_deferred()


func _new_code(u: Dictionary) -> void:
	var r: Dictionary = await Sync.change_user(String(u.id), {"new_code": true})
	if r.has("error"):
		UI.app.toast(Lang.t(r.error), "error")
		return
	AddUserSheet.show_code(String(u.name), String(r.get("code", "")))
	_load()


func _change(id: String, change: Dictionary, ok_text: String) -> void:
	var r: Dictionary = await Sync.change_user(id, change)
	if r.has("error"):
		UI.app.toast(Lang.t(r.error), "error")
		return
	UI.app.toast(ok_text)
	_load()
