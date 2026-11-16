class_name Platform
extends RefCounted
## Sharing, export and import on each platform.
##  Android: PayTrackShare plugin (share sheet → WhatsApp etc., file picker).
##  Web:     Web Share API when the browser has it, otherwise a download; file input for import.
##  iPad:    files are written to the app's Documents folder (visible in the Files app).
##  Desktop: saved to Downloads; native open dialog for import.

static var _web_cb  # keeps the JS callback alive
static var _android_connected := false


static func setup() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
		window.ptShare = async function(b64, name, mime) {
			try {
				const bin = atob(b64); const arr = new Uint8Array(bin.length);
				for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
				const file = new File([arr], name, {type: mime});
				if (navigator.canShare && navigator.canShare({files: [file]})) {
					await navigator.share({files: [file], title: name});
					return;
				}
				const url = URL.createObjectURL(file);
				const a = document.createElement('a'); a.href = url; a.download = name;
				document.body.appendChild(a); a.click(); a.remove();
				setTimeout(() => URL.revokeObjectURL(url), 4000);
			} catch (e) {
				if (e && e.name === 'AbortError') return;
				const blob = new Blob([Uint8Array.from(atob(b64), c => c.charCodeAt(0))], {type: mime});
				const url = URL.createObjectURL(blob);
				const a = document.createElement('a'); a.href = url; a.download = name;
				document.body.appendChild(a); a.click(); a.remove();
			}
		};
		window.ptDownload = function(b64, name, mime) {
			try {
				const bin = atob(b64); const arr = new Uint8Array(bin.length);
				for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
				const url = URL.createObjectURL(new Blob([arr], {type: mime}));
				const a = document.createElement('a'); a.href = url; a.download = name;
				document.body.appendChild(a); a.click(); a.remove();
				setTimeout(() => URL.revokeObjectURL(url), 10000);
				return true;
			} catch (e) { return false; }
		};
		// Ask the browser to keep PayTrack's data (not clear it to save space).
		try { if (navigator.storage && navigator.storage.persist) navigator.storage.persist(); } catch (e) {}
		window.ptPick = function(cb) {
			// No "accept" filter: iPad/iPhone grey out files whose type they do
			// not know (like .paytrack), so every file can be chosen; the app
			// checks the contents itself.
			const old = document.getElementById('pt-pick');
			if (old) old.remove();
			const input = document.createElement('input');
			input.type = 'file';
			input.id = 'pt-pick';
			input.style.position = 'fixed';
			input.style.left = '-1000px';
			input.style.opacity = '0';
			document.body.appendChild(input);
			input.onchange = () => {
				const f = input.files && input.files[0];
				if (!f) { input.remove(); return; }
				const r = new FileReader();
				r.onload = () => { cb(String(r.result)); input.remove(); };
				r.onerror = () => { cb(''); input.remove(); };
				r.readAsText(f);
			};
			input.click();
		};
		""", true)


static func _android() -> Object:
	if Engine.has_singleton("PayTrackShare"):
		return Engine.get_singleton("PayTrackShare")
	return null


static func share_bytes(bytes: PackedByteArray, file_name: String, mime: String, text := "") -> bool:
	## Hands a file to the system share sheet (or saves it). Returns true on success.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ptShare('%s', '%s', '%s')" % [Marshalls.raw_to_base64(bytes), file_name.replace("'", ""), mime], true)
		return true
	var dir := "user://share"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var a := _android()
	if a:
		return a.share(abs_path, mime, text)
	if OS.get_name() == "Android":
		return false
	if OS.get_name() == "iOS":
		# Documents folder is visible in the Files app ("On My iPad › PayTrack").
		var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if docs != "":
			DirAccess.copy_absolute(abs_path, docs.path_join(file_name))
		UI.app.toast(Lang.t("saved_to_files"))
		return true
	# Desktop: copy to Downloads and show it.
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		var dest := dl.path_join(file_name)
		DirAccess.copy_absolute(abs_path, dest)
		OS.shell_show_in_file_manager(dest)
		UI.app.toast(Lang.t("saved_to_downloads"))
		return true
	return false


# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

static func save_to_device(bytes: PackedByteArray, file_name: String, mime: String) -> String:
	## Keeps a copy of the file on this phone / tablet / computer.
	## Returns where it went ("" if it could not be saved).
	if OS.has_feature("web"):
		var ok = JavaScriptBridge.eval("window.ptDownload('%s', '%s', '%s')" % [Marshalls.raw_to_base64(bytes), file_name.replace("'", ""), mime], true)
		return Lang.t("saved_where_web") if ok else ""
	var dir := "user://share"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var a := _android()
	if a:
		return Lang.t("saved_where_android") if a.saveToDownloads(abs_path, file_name, mime) else ""
	if OS.get_name() == "Android":
		return ""
	if OS.get_name() == "iOS":
		var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if docs != "" and DirAccess.copy_absolute(abs_path, docs.path_join(file_name)) == OK:
			return Lang.t("saved_to_files")
		return ""
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "" and DirAccess.copy_absolute(abs_path, dl.path_join(file_name)) == OK:
		return Lang.t("saved_to_downloads")
	return ""


static func export_backup() -> void:
	## Saves the backup on this device first, then offers to share it
	## (WhatsApp, Drive, email…) from the same screen.
	var bytes := DB.export_text().to_utf8_buffer()
	var name := DB.export_file_name()
	var where := save_to_device(bytes, name, "application/json")
	if where != "":
		DB.mark_exported()
	var s := Sheet.new(Lang.t("export_backup"))
	UI.app.present(s)
	var v := UI.vbox(12)
	var h := UI.hbox(12)
	h.add_child(Icons.make("check" if where != "" else "warning", UI.GREEN if where != "" else UI.ORANGE, 28))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.wrapped(UI.label(Lang.t("backup_saved") if where != "" else Lang.t("backup_not_saved"), UI.S_HEAD, UI.TEXT, 600)))
	tv.add_child(UI.wrapped(UI.label(where + "\n" + name if where != "" else Lang.t("backup_share_instead"), UI.S_SUB, UI.TEXT2)))
	h.add_child(tv)
	v.add_child(h)
	v.add_child(UI.spacer(4))
	v.add_child(UI.button(Lang.t("share_backup"), "primary", func():
		if share_bytes(bytes, name, "application/json", Lang.t("backup_share_text")):
			DB.mark_exported()
		else:
			UI.app.toast(Lang.t("export_failed"), "error"), "share"))
	v.add_child(UI.wrapped(UI.label(Lang.t("share_backup_help"), UI.S_CAP, UI.TEXT2)))
	v.add_child(UI.button(Lang.t("done"), "secondary", func(): s.close()))
	s.body.add_child(v)


static func import_backup() -> void:
	if OS.has_feature("web"):
		_web_cb = JavaScriptBridge.create_callback(func(args): _got_text(String(args[0]), "web"))
		var win = JavaScriptBridge.get_interface("window")
		win.ptPick(_web_cb)
		return
	var a := _android()
	if a:
		# PayTrack's own picker screen; the result is read back by asking.
		if not a.pickFile():
			_fail("picker did not open: " + String(a.lastError()))
			return
		_wait_for_pick(a)
		return
	if OS.has_feature("android"):
		_fail("file picker missing in this build")
		return
	# Desktop: the system's open dialog.
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var err := DisplayServer.file_dialog_show(Lang.t("import_backup"), OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json, *.paytrack ; PayTrack"]),
			func(status: bool, paths: PackedStringArray, _idx: int):
				if status and paths.size() > 0:
					_got_file(paths[0]))
		if err == OK:
			return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.paytrack, *.json ; PayTrack"])
	fd.file_selected.connect(func(p): _got_file(p); fd.queue_free())
	UI.app.add_child(fd)
	fd.popup_centered_ratio(0.8)


static func _wait_for_pick(a: Object) -> void:
	## Asks the picker every 0.4 s until a file was chosen (or not), and shows
	## each step in a small window, so a problem can be seen and reported.
	var sh := Sheet.new(Lang.t("import_backup"))
	UI.app.present(sh)
	var msg := UI.wrapped(UI.label(Lang.t("import_opening"), UI.S_SUB, UI.TEXT, 500))
	sh.body.add_child(msg)
	var detail := UI.wrapped(UI.label("", UI.S_CAP, UI.TEXT3))
	detail.set_meta("raw", true)
	sh.body.add_child(detail)
	var tree := UI.app.get_tree()
	var waited := 0.0
	var opened := false
	var last := Time.get_ticks_msec()
	while waited < 1800.0:
		await tree.create_timer(0.4, true).timeout
		if not is_instance_valid(sh) or sh._closing:
			return   # closed by the user
		var now := Time.get_ticks_msec()
		if now - last > 1500:
			opened = true   # the app was in the background: the picker was shown
			msg.text = Lang.t("import_reading")
		last = now
		waited += 0.4
		var st := String(a.pickStatus())
		detail.text = st.substr(0, 160)
		if st == "waiting":
			if not opened and waited > 6.0:
				msg.text = Lang.t("import_no_picker")
				msg.add_theme_color_override("font_color", UI.RED)
			continue
		if st.begins_with("done:"):
			sh.close()
			_got_file(st.substr(5))
		elif st.begins_with("error:"):
			msg.text = Lang.t("import_failed") + ": " + st.substr(6)
			msg.add_theme_color_override("font_color", UI.RED)
		elif st == "cancelled":
			sh.close()
		else:
			msg.text = Lang.t("import_no_result")
			msg.add_theme_color_override("font_color", UI.RED)
		return


static func _fail(reason: String) -> void:
	## Says why, so the problem can be found.
	UI.app.toast(Lang.t("import_failed") + " (" + reason + ")", "error")


static func _got_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("cannot read file, error %d" % FileAccess.get_open_error())
		return
	_got_text(f.get_as_text(), "file")


static func _got_text(text: String, from := "") -> void:
	if text.strip_edges() == "":
		_fail("empty file" + (" from " + from if from != "" else ""))
		return
	var r := DB.parse_import(text)
	if r.has("error"):
		UI.app.toast(Lang.t(r.error), "error")
		return
	var s: Dictionary = r.summary
	var details := UI.card()
	UI.add_rows(details, [
		UI.row(Lang.t("tab_mills"), "", str(s.mills), Callable(), false),
		UI.row(Lang.t("tab_people"), "", str(s.people), Callable(), false),
		UI.row(Lang.t("entries"), "", str(s.entries), Callable(), false),
		UI.row(Lang.t("payments"), "", str(s.payments), Callable(), false),
	])
	var msg := Lang.t("import_body", [String(r.get("exported", "")).replace("T", " ").substr(0, 16)])
	if r.get("local_newer", false):
		msg += "\n\n" + Lang.t("import_warn_newer")
	UI.app.confirm(Lang.t("import_title"), msg, Lang.t("import_replace"), func():
		DB.apply_import(r.data)
		Lang.set_lang(String(DB.data.settings.get("lang", Lang.lang)), false)
		UI.app.go_tab_root("home")
		UI.app.toast(Lang.t("import_done")), r.get("local_newer", false), details)
