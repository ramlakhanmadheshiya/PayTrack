class_name JoinSheet
extends Sheet
## Join the family's shared PayTrack with a one-time code from the admin
## (or the admin's own code the first time, or the recovery code).

var recovery := false
var prefill := ""
var field: TextField
var _err: Label
var _busy := false


static func open(use_recovery := false, code := "") -> void:
	var s := JoinSheet.new(Lang.t("sharing"), Lang.t("recover") if use_recovery else Lang.t("join"))
	s.recovery = use_recovery
	s.prefill = code
	s.action_cb = s._join
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.wrapped(UI.label(Lang.t("sharing_help"), UI.S_SUB, UI.TEXT2)))
	body.add_child(UI.wrapped(UI.label(Lang.t("recovery_help") if recovery else Lang.t("sharing_intro"), UI.S_SUB, UI.TEXT, 500)))
	body.add_child(UI.label(Lang.t("recovery_code") if recovery else Lang.t("join_code"), UI.S_CAP, UI.TEXT2, 600))
	field = UI.text_field(Lang.t("join_code_ph"), prefill, Lang.t("join_code"))
	field.capitalize_words = false
	field.max_length = 24
	body.add_child(field)
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	if not recovery:
		body.add_child(UI.footnote(Lang.t("admin_code_help")))
		body.add_child(UI.spacer(6))
		var l := UI.link(Lang.t("use_recovery"), func(): close(); JoinSheet.open(true), UI.ACCENT, UI.S_SUB)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(l)
	if prefill == "":
		(func(): if is_instance_valid(field): UI.app.numpad_open(field)).call_deferred()


func _join() -> void:
	if _busy:
		return
	UI.app.numpad_close()
	var code := field.text.strip_edges()
	if code.length() < 8:
		_err.text = Lang.t("err_bad_code")
		return
	_busy = true
	_err.add_theme_color_override("font_color", UI.TEXT2)
	_err.text = Lang.t("joining")
	set_action_enabled(false)
	var e: String = await Sync.join(code, recovery)
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	set_action_enabled(true)
	if e != "":
		_err.add_theme_color_override("font_color", UI.RED)
		_err.text = Lang.t(e)
		return
	close()
	UI.app.go_tab_root("home")
	UI.app.toast(Lang.t("joined_ok", [Sync.role_name(Sync.role())]))
	if Sync.replaced_local:
		UI.app.confirm(Lang.t("sharing"), Lang.t("join_replaced"), Lang.t("ok"), func(): pass)
