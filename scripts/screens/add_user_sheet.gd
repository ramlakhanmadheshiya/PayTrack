class_name AddUserSheet
extends Sheet
## Admin: add a family member. The server makes a one-time code to type on
## their phone.

var field: TextField
var role := "editor"
var on_done: Callable
var _err: Label
var _busy := false


static func open(cb: Callable = Callable()) -> void:
	var s := AddUserSheet.new(Lang.t("add_user"), Lang.t("add_user"))
	s.on_done = cb
	s.action_cb = s._save
	UI.app.present(s)


func build() -> void:
	UI.clear(body)
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.label(Lang.t("user_name"), UI.S_CAP, UI.TEXT2, 600))
	var keep := field.text if field else ""
	field = UI.text_field(Lang.t("user_name_ph"), keep, Lang.t("user_name"))
	body.add_child(field)
	body.add_child(UI.label(Lang.t("role"), UI.S_CAP, UI.TEXT2, 600))
	body.add_child(UI.segmented([Lang.t("role_editor"), Lang.t("role_viewer")], 0 if role == "editor" else 1, func(i): role = "editor" if i == 0 else "viewer"; build()))
	body.add_child(UI.wrapped(UI.label(Lang.t("role_editor_help") if role == "editor" else Lang.t("role_viewer_help"), UI.S_SUB, UI.TEXT2)))
	_err = UI.wrapped(UI.label("", UI.S_SUB, UI.RED, 500))
	body.add_child(_err)
	if keep == "":
		(func(): if is_instance_valid(field): UI.app.numpad_open(field)).call_deferred()


func _save() -> void:
	if _busy:
		return
	UI.app.numpad_close()
	var n := field.text.strip_edges()
	if n == "":
		_err.text = Lang.t("err_name_empty")
		return
	_busy = true
	set_action_enabled(false)
	var r: Dictionary = await Sync.add_user(n, role)
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	set_action_enabled(true)
	if r.has("error"):
		_err.text = Lang.t(r.error)
		return
	close()
	show_code(n, String(r.get("code", "")))
	if on_done.is_valid():
		on_done.call()


static func join_link(code: String) -> String:
	return "https://theramlakhan.com/paytrack/?join=" + code


static func show_code(name: String, code: String) -> void:
	## The one-time code, big, with its QR code (scan with the iPad/phone
	## camera: PayTrack opens with the code filled in). Share or copy it.
	var s := Sheet.new(Lang.t("code_for", [name]))
	s.cancel_text = Lang.t("done")
	UI.app.present(s)
	s.body.add_theme_constant_override("separation", 14)
	var img := QR.image(QR.encode(join_link(code)), 8)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(220, 220)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var qc := CenterContainer.new()
	qc.add_child(tr)
	s.body.add_child(qc)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.pad(UI.box(UI.ACCENT_SOFT, 14), 16, 14))
	var l := UI.label(code, 30, UI.ACCENT, 700, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_meta("raw", true)
	box.add_child(l)
	s.body.add_child(box)
	s.body.add_child(UI.wrapped(UI.label(Lang.t("code_help_qr", [name]), UI.S_SUB, UI.TEXT2)))
	var big := QR.image(QR.encode(join_link(code)), 16)
	s.body.add_child(UI.button(Lang.t("share_qr"), "primary", func():
		Platform.share_bytes(big.save_png_to_buffer(), "PayTrack-code-%s.png" % code, "image/png", Lang.t("share_qr_text", [code, join_link(code)])), "share"))
	s.body.add_child(UI.button(Lang.t("copy_code"), "secondary", func():
		DisplayServer.clipboard_set(code)
		UI.app.toast(Lang.t("code_copied")), "doc"))
