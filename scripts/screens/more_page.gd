class_name MorePage
extends Page
## Language, text size, backup (export / import), payments, about.


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("tab_more")
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
	b.add_child(UI.section_title(Lang.t("backup")))
	var c := UI.card()
	var last: String = DB.setting("last_export", "")
	var rows := [
		UI.row(Lang.t("export_backup"), Lang.t("last_backup", [Lang.date_full(last)]) if last != "" else Lang.t("never_backed_up"), null, func(): Platform.export_backup(), true, Icons.make("export", UI.ACCENT, 22)),
		UI.row(Lang.t("import_backup"), Lang.t("import_help"), null, func(): Platform.import_backup(), true, Icons.make("import", UI.ACCENT, 22)),
	]
	if DB.can_undo_import():
		rows.append(UI.row(Lang.t("undo_import"), Lang.t("undo_import_help"), null, func():
			UI.app.confirm(Lang.t("undo_import"), Lang.t("undo_import_q"), Lang.t("undo_import"), func():
				if DB.undo_import():
					Lang.set_lang(String(DB.data.settings.get("lang", "en")), false)
					UI.app.toast(Lang.t("import_undone")), true), true, Icons.make("undo", UI.RED, 22)))
	UI.add_rows(c, rows)
	b.add_child(UI.margin(c, 16, 0, 16, 0))
	b.add_child(UI.footnote(Lang.t("backup_help")))
	# Records.
	b.add_child(UI.section_title(Lang.t("records")))
	var rc := UI.card()
	UI.add_rows(rc, [
		UI.row(Lang.t("all_payments"), Lang.t("n_payments", [DB.data.payments.size()]), null, func(): UI.app.push(PaymentsPage.new()), true, Icons.make("history", UI.ACCENT, 22)),
		UI.row(Lang.t("how_it_works"), "", null, func(): UI.app.push(HelpPage.new()), true, Icons.make("info", UI.ACCENT, 22)),
	])
	b.add_child(UI.margin(rc, 16, 0, 16, 0))
	# Data.
	b.add_child(UI.section_title(Lang.t("data")))
	var dc := UI.card()
	var drows := []
	if not DB.has_any_data():
		drows.append(UI.row(Lang.t("try_sample"), Lang.t("sample_body"), null, func(): DB.load_sample_data(); UI.app.toast(Lang.t("sample_loaded")), true, Icons.make("doc", UI.ACCENT, 22)))
	drows.append(UI.row(Lang.t("erase_all"), Lang.t("erase_all_help"), null, _erase, false, Icons.make("trash", UI.RED, 22)))
	UI.add_rows(dc, drows)
	b.add_child(UI.margin(dc, 16, 0, 16, 0))
	# About.
	var about := UI.label("PayTrack %s · %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Lang.t("about_line")], UI.S_CAP, UI.TEXT3, 500)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(UI.margin(UI.wrapped(about), 16, 24, 16, 0))


func _erase() -> void:
	UI.app.confirm(Lang.t("erase_all"), Lang.t("erase_q"), Lang.t("erase_confirm"), func():
		UI.app.confirm(Lang.t("erase_all"), Lang.t("erase_q2"), Lang.t("erase_confirm"), func():
			var lang := Lang.lang
			DB.data = DB.empty_data()
			DB.data.settings.lang = lang
			DB.save()
			UI.app.go_tab_root("home")
			UI.app.toast(Lang.t("erased")), true), true)
