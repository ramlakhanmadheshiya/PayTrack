class_name MorePage
extends Page
## Language, text size, backup (export / import), payments, about.


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_more")
	_build_sharing(b)
	# Language.
	b.add_child(UI.section_title(Lang.t("language")))
	b.add_child(UI.margin(UI.segmented(["English", "हिन्दी"], 0 if Lang.lang == "en" else 1, func(i): Lang.set_lang("en" if i == 0 else "hi")), 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("language_help")))
	# Text size.
	b.add_child(UI.section_title(Lang.t("text_size")))
	var sizes := [1.0, 1.15, 1.3]
	var cur := sizes.find(float(DB.setting("text_size", 1.0)))
	b.add_child(UI.margin(UI.segmented([Lang.t("size_normal"), Lang.t("size_large"), Lang.t("size_larger")], maxi(cur, 0), func(i): UI.app.set_text_size(sizes[i])), 16, 0, 16, 0))
	# Backup.
	var backup_title := UI.section_title(Lang.t("backup"))
	b.add_child(backup_title)
	var c := UI.card()
	var last: String = DB.setting("last_export", "")
	var rows := []
	# View-only users may not take the data away.
	if not Sync.read_only():
		rows.append(UI.row(Lang.t("export_backup"), Lang.t("last_backup", [Lang.date_full(last)]) if last != "" else Lang.t("never_backed_up"), null, func(): Platform.export_backup(), true, Icons.make("export", UI.ACCENT, 22)))
	# When sharing, only the admin may replace everyone's data.
	if Sync.is_admin():
		rows.append(UI.row(Lang.t("import_backup"), Lang.t("import_help"), null, func(): Platform.import_backup(), true, Icons.make("import", UI.ACCENT, 22)))
	if DB.can_undo_import() and Sync.is_admin():
		rows.append(UI.row(Lang.t("undo_import"), Lang.t("undo_import_help"), null, func():
			UI.app.confirm(Lang.t("undo_import"), Lang.t("undo_import_q"), Lang.t("undo_import"), func():
				if DB.undo_import():
					Lang.set_lang(String(DB.data.settings.get("lang", "en")), false)
					UI.app.toast(Lang.t("import_undone")), true), true, Icons.make("undo", UI.RED, 22)))
	if rows.is_empty():
		backup_title.queue_free()
	else:
		UI.add_rows(c, rows)
		b.add_child(UI.margin(c, 16, 0, 16, 0))
		b.add_child(UI.footnote(Lang.t("backup_help")))
	# Records.
	b.add_child(UI.section_title(Lang.t("records")))
	var rc := UI.card()
	UI.add_rows(rc, [
		UI.row(Lang.t("activity"), Lang.t("activity_sub"), null, func(): UI.app.push(ActivityPage.new()), true, Icons.make("history", UI.ACCENT, 22)),
		UI.row(Lang.t("all_payments"), Lang.t("n_payments", [DB.data.payments.size()]), null, func(): UI.app.push(PaymentsPage.new()), true, Icons.make("history", UI.ACCENT, 22)),
		UI.row(Lang.t("how_it_works"), "", null, func(): UI.app.push(HelpPage.new()), true, Icons.make("info", UI.ACCENT, 22)),
	])
	b.add_child(UI.margin(rc, 16, 0, 16, 0))
	# Data.
	b.add_child(UI.section_title(Lang.t("data")))
	var dc := UI.card()
	var drows := []
	if not DB.has_any_data() and not Sync.enabled():
		drows.append(UI.row(Lang.t("try_sample"), Lang.t("sample_body"), null, func(): DB.load_sample_data(); UI.app.toast(Lang.t("sample_loaded")), true, Icons.make("doc", UI.ACCENT, 22)))
	if Sync.is_admin():
		drows.append(UI.row(Lang.t("clear_money"), Lang.t("clear_money_help"), null, _clear_money, false, Icons.make("rupee", UI.ORANGE, 22)))
	# Erasing a shared PayTrack would erase it on every phone: not offered then.
	if not Sync.enabled():
		drows.append(UI.row(Lang.t("erase_all"), Lang.t("erase_all_help"), null, _erase, false, Icons.make("trash", UI.RED, 22)))
	if not drows.is_empty():
		UI.add_rows(dc, drows)
		b.add_child(UI.margin(dc, 16, 0, 16, 0))
	else:
		b.get_child(b.get_child_count() - 1).queue_free()
	# About.
	var about := UI.label("PayTrack %s · %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Lang.t("about_line")], UI.S_CAP, UI.TEXT3, 500)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(UI.margin(UI.wrapped(about), 16, 24, 16, 0))


func _build_sharing(b: VBoxContainer) -> void:
	b.add_child(UI.section_title(Lang.t("sharing")))
	var c := UI.card()
	var rows := []
	if not Sync.enabled():
		rows.append(UI.row(Lang.t("sharing"), Lang.t("sharing_off_sub"), null, func(): JoinSheet.open(), true, Icons.make("people", UI.ACCENT, 22)))
	else:
		var st := ""
		match Sync.status:
			"syncing":
				st = Lang.t("sync_syncing")
			"offline":
				st = Lang.t("sync_offline")
			_:
				var ago := int(Time.get_unix_time_from_system()) - Sync.last_ok
				st = Lang.t("sync_never") if Sync.last_ok == 0 else (Lang.t("synced_now") if ago < 60 else Lang.t("synced_ago", [Lang.ago(ago)]))
		var who := Lang.t("connected_as", [Lang.name_of(Sync.my_name()), Sync.role_name(Sync.role())])
		var icon := Icons.make("check_circle" if Sync.status == "ok" else ("warning" if Sync.status == "offline" else "history"), UI.GREEN if Sync.status == "ok" else UI.ORANGE, 22)
		rows.append(UI.row(who, st, null, func(): Sync.sync_now(true), true, icon))
		if Sync.role() == "admin":
			rows.append(UI.row(Lang.t("users"), Lang.t("users_sub"), null, func(): UI.app.push(UsersPage.new()), true, Icons.make("people", UI.ACCENT, 22)))
		rows.append(UI.row(Lang.t("stop_sharing"), "", null, _stop_sharing, false, Icons.make("close", UI.RED, 22)))
	rows.append(UI.row(Lang.t("pin_lock"), Lang.t("pin_lock_sub"), UI.switch(PinLock.is_on(), _toggle_pin), Callable(), false, Icons.make("info", UI.ACCENT, 22)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("view_only_note") if Sync.read_only() else Lang.t("sharing_help")))


func _toggle_pin(on: bool) -> void:
	if on:
		var l := PinLock.show_lock("set")
		l.finished.connect(func(ok):
			UI.app.toast(Lang.t("pin_on") if ok else Lang.t("pin_off"))
			refresh())
	else:
		var l := PinLock.show_lock("check")
		l.finished.connect(func(ok):
			if ok:
				PinLock.turn_off()
				UI.app.toast(Lang.t("pin_off"))
			refresh())


func _stop_sharing() -> void:
	var admin := Sync.role() == "admin"
	UI.app.confirm(Lang.t("stop_sharing"), Lang.t("stop_sharing_admin_q") if admin else Lang.t("stop_sharing_q"), Lang.t("stop_sharing"), func():
		Sync.leave()
		refresh(), true)


func _erase() -> void:
	UI.app.confirm(Lang.t("erase_all"), Lang.t("erase_q"), Lang.t("erase_confirm"), func():
		UI.app.confirm(Lang.t("erase_all"), Lang.t("erase_q2"), Lang.t("erase_confirm"), func():
			var lang := Lang.lang
			DB.data = DB.empty_data()
			DB.data.settings.lang = lang
			DB.save()
			UI.app.go_tab_root("home")
			UI.app.toast(Lang.t("erased")), true), true)


func _clear_money() -> void:
	UI.app.confirm(Lang.t("clear_money"), Lang.t("clear_money_q"), Lang.t("clear_money"), func():
		UI.app.confirm(Lang.t("clear_money"), Lang.t("clear_money_q2"), Lang.t("clear_money"), func():
			DB.clear_money()
			UI.app.toast(Lang.t("money_cleared")), true), true)
