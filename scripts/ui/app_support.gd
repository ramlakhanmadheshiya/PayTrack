extends Control
const P = preload("res://scripts/domain/payroll.gd")
const R = preload("res://scripts/storage/repository.gd")
const S = preload("res://scripts/services/payroll_service.gd")
var repo = R.new()
var service = S.new(repo)
var body: VBoxContainer
var status: Label
var current = "Home"
var import_callback
var pending_backup = ""

# Presentation hooks implemented by the app. These are platform/storage helpers only.
func transact(_action: Callable): pass
func preview_restore(_content: String): pass

func seed_demo():
	transact(func():
		service.person("Aarav Demo", "2026-11-01")
		service.person("Meera Demo", "2026-11-01")
		for name in ["Willow Demo", "Maple Demo", "Cedar Demo", "Elm Demo", "Pine Demo"]:
			service.mill(name)
			var key = repo.data.mills.back().id
			service.rate(key,"F",350,"2026-01-01")
			service.rate(key,"H",250,"2026-01-01")
		service.salary(repo.data.persons[0].id,24000,"2026-11-01")
		return true)

func decimal_units(value: String, scale: int) -> int:
	var bits = value.strip_edges().split(".")
	if bits.size() > 2 or not bits[0].is_valid_int() or int(bits[0]) < 0: return -1
	var fraction = 0
	if bits.size() == 2:
		if not bits[1].is_valid_int() or bits[1].length() > 2: return -1
		fraction = int(bits[1].rpad(2,"0"))
	if (fraction * scale) % 100 != 0: return -1
	return int(bits[0]) * scale + fraction * scale / 100

func download(content: String, filename: String, mime: String):
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(),filename,mime)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.current_file = filename
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			var file = FileAccess.open(path,FileAccess.WRITE)
			if file: file.store_string(content)
			dialog.queue_free())
		dialog.popup_centered_ratio(0.7)

func import_backup():
	if OS.has_feature("web"):
		import_callback = JavaScriptBridge.create_callback(func(args): preview_restore(str(args[0])))
		var window = JavaScriptBridge.get_interface("window")
		window.paytrackImport = import_callback
		JavaScriptBridge.eval("var pick=document.createElement('input');pick.type='file';pick.accept='.json,application/json';pick.onchange=async()=>{if(pick.files[0])window.paytrackImport(await pick.files[0].text())};pick.click();",true)
	else:
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.json ; JSON backup"])
		add_child(dialog)
		dialog.file_selected.connect(func(path):
			preview_restore(FileAccess.get_file_as_string(path))
			dialog.queue_free())
		dialog.popup_centered_ratio(0.7)

func export_csv(collection: String):
	var rows: Array = repo.data[collection]
	if rows.is_empty():
		status.text = "No records to export yet."
		status.show()
		return
	var keys = rows[0].keys()
	keys.erase("before")
	var output = ",".join(keys) + "\n"
	for row in rows:
		var values = []
		for key in keys:
			var value = str(row.get(key,""))
			if value.begins_with("=") or value.begins_with("+") or value.begins_with("-") or value.begins_with("@"): value = "'" + value
			values.append('"' + value.replace('"','""') + '"')
		output += ",".join(values) + "\n"
	download(output,"paytrack-" + collection + ".csv","text/csv")

func today() -> String:
	return Time.get_date_string_from_system()

func selected(node: OptionButton) -> String:
	return "" if node.selected < 0 else str(node.get_item_metadata(node.selected))
