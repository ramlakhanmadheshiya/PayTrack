extends SceneTree
const App = preload("res://scripts/ui/app.gd")
const Repository = preload("res://scripts/storage/repository.gd")
const Service = preload("res://scripts/services/payroll_service.gd")
var app
var total = 0
var failed = 0
func _init(): call_deferred("run")
func check(condition: bool, description: String):
	total += 1
	if not condition:
		failed += 1
		printerr("UI FAIL: ",description)
func nodes(root_node: Node) -> Array:
	var result = [root_node]
	for child in root_node.get_children(): result.append_array(nodes(child))
	return result
func field(title: String, search_root: Node = null):
	var scope = app if search_root == null else search_root
	for node in nodes(scope):
		if node is Label and node.text == title:
			for sibling in node.get_parent().get_children():
				if sibling is LineEdit or sibling is OptionButton or sibling is PayTrackDateField: return sibling
	return null
func click(title: String):
	for node in nodes(app):
		if node is Button and not node is OptionButton and node.text == title and node.is_visible_in_tree():
			node.pressed.emit()
			return true
	printerr("UI button missing: ",title)
	failed += 1
	return false
func has_text(text: String) -> bool:
	for node in nodes(app):
		if node is Label and node.text == text and node.is_visible_in_tree(): return true
	return false
func run():
	app = App.new()
	app.test_mode = true
	app.repo = Repository.new("user://paytrack-redesign-ui-test.json")
	app.service = Service.new(app.repo)
	root.add_child(app)
	await process_frame
	check(click("+ Add a person"),"empty home offers setup")
	field("Name").text = "Test Worker"
	field("Pay starts from").value = "2026-11-01"
	click("Add person")
	check(app.repo.data.persons.size() == 1,"add-person form saves")
	app.person_form()
	field("Name").text = "  test worker  "
	click("Add person")
	check(app.repo.data.persons.size() == 1,"duplicate name rejected")
	check(field("Name").text == "  test worker  ","invalid form keeps user's input")
	check(is_instance_valid(app.modal_layer),"invalid form stays open")
	app.close_modal()
	app.person_form()
	field("Name").text = "Second Worker"
	field("Pay starts from").value = "2026-11-01"
	click("Add person")
	check(app.repo.data.persons.size() == 2,"second person saves")
	app.show_page("Settings")
	app.mill_form()
	field("Mill name").text = "Test Mill"
	field("Fireman · per attendance").text = "350"
	field("Helper · per attendance").text = "250"
	field("Rates start from").value = "2026-01-01"
	click("Save mill & rates")
	check(app.repo.data.mills.size() == 1 and app.repo.data.rates.size() == 2,"mill form saves both rates atomically")
	app.show_page("Attendance")
	check(not has_text("Correct received attendance"),"daily attendance hides correction forms")
	field("From").value = "2026-11-01"
	field("Through").value = "2026-11-14"
	field("Attendances").text = "26"
	click("Save attendance")
	check(app.repo.data.attendance.size() == 1,"attendance form saves actual counts")
	check(app.repo.data.attendance[0].half_units == 52 and app.repo.data.attendance[0].rate == 350,"UI preserves shift units and rate snapshot")
	field("Attendances").text = "bad input"
	click("Save attendance")
	check(app.repo.data.attendance.size() == 1 and field("Attendances").text == "bad input","failed attendance preserves form and data")
	app.money_kind = "kharchi"
	app.show_page("Money")
	field("Amount").text = "500"
	field("Date").value = "2026-11-01"
	click("Save kharchi")
	check(app.repo.data.ledger.size() == 1 and app.repo.data.ledger.back().kind == "kharchi","simple kharchi form works")
	click("Advance")
	field("Amount").text = "1000"
	field("Date").value = "2026-11-01"
	field("Recover from each payment (optional)").text = "100"
	click("Save advance")
	check(app.repo.data.ledger.back().kind == "advance" and app.repo.data.ledger.back().installment == 100,"advance recovery saved")
	click("Jama")
	field("Amount").text = "50"
	field("Date").value = "2026-11-01"
	click("Save jama")
	check(app.repo.data.ledger.back().kind == "jama","jama form works")
	app.open_pay(app.repo.data.persons[0].id)
	field("Pay through").value = "2026-11-14"
	click("Calculate payment")
	check(app.payment_state.result.cash == 8550,"UI preview reconciles wages/jama/kharchi/recovery")
	field("Amount").text = "8000"
	field("Amount").text_changed.emit("8000")
	click("Record payment · ₹8,000")
	click("Confirm")
	check(app.repo.data.settlements.size() == 1,"payment confirmed exactly once")
	if app.repo.data.settlements.size() == 1:
		var payment = app.repo.data.settlements[0]
		check(payment.cash == 8000 and payment.slips[0].totals.new_jama == 550,"part payment carries the exact jama")
		check(has_text("Payment recorded"),"recorded payment displays receipt")
		check(app.receipt_html(payment).contains("₹8,000") and app.receipt_html(payment).contains("Advance remaining"),"print receipt includes cash and remaining debt")
		var reload = Repository.new("user://paytrack-redesign-ui-test.json")
		check(reload.load_data() and reload.data.settlements[0].cash == 8000,"UI payment survives repository reload")
		click("Correct a payment mistake  +")
		click("Cancel this payment")
		click("Confirm")
		check(app.repo.data.settlements[0].cancelled and app.repo.data.persons[0].paid_up_to.is_empty(),"cancellation restores accounting period")
	app.show_page("People")
	app.person_form()
	field("Name").text = "Family One"
	field("Pay starts from").value = "2026-11-01"
	click("Add person")
	app.person_form()
	field("Name").text = "Family Two"
	field("Pay starts from").value = "2026-11-01"
	click("Add person")
	app.show_page("Families")
	click("+ Create a family")
	field("Family name").text = "Test Family"
	for node in nodes(app.modal_layer):
		if node is CheckBox and node.text in ["Family One","Family Two"]: node.button_pressed = true
	click("Create family")
	check(app.repo.data.families.size() == 1,"family created through name checkboxes")
	if not app.repo.data.families.is_empty():
		var family = app.repo.data.families[0]
		check(family.members.size() == 2,"family members saved without typing IDs")
		app.family_form(family.id)
		check(field("Member IDs · comma separated") == null,"family editor never asks for raw IDs")
		app.close_modal()
	app.show_page("Money")
	app.bulk_money_form()
	for node in nodes(app.modal_layer):
		if node is CheckBox and node.text in ["Family One","Family Two"]: node.button_pressed = true
	field("From",app.modal_layer).value = "2026-11-01"
	field("Through",app.modal_layer).value = "2026-11-02"
	field("Per person, per day").text = "100"
	click("Save daily kharchi")
	check(app.repo.data.ledger.filter(func(entry): return entry.kind == "kharchi").size() == 5,"bulk UI posts exact dated amounts")

	var first_person = app.repo.data.persons[0].id
	var mill_key = app.repo.data.mills[0].id
	var frozen = JSON.stringify(app.repo.data.settlements[0].slips)
	app.show_page("Settings")
	app.salary_form(first_person)
	field("Monthly salary",app.modal_layer).text = "22000"
	field("Starts from",app.modal_layer).value = "2026-11-01"
	click("Review salary change")
	click("Confirm")
	check(app.repo.data.salaries.size() == 1 and app.repo.data.salaries[0].amount == 22000,"salary comparison saves effective history")
	check(JSON.stringify(app.repo.data.settlements[0].slips) == frozen,"salary change preserves old receipt")
	app.mill_form(mill_key)
	field("Mill name",app.modal_layer).text = "Renamed Test Mill"
	field("Fireman · per attendance",app.modal_layer).text = "400"
	field("Helper · per attendance",app.modal_layer).text = "300"
	field("Rates start from",app.modal_layer).value = "2026-11-20"
	click("Save mill & rates")
	check(app.repo.data.mills[0].name == "Renamed Test Mill" and app.repo.data.rates.size() == 4,"mill rename and dated rates save")
	check(app.repo.data.attendance[0].rate == 350,"new mill rate preserves old attendance rate")
	app.reprice_form(mill_key)
	field("New rate per attendance",app.modal_layer).text = "360"
	field("Apply from",app.modal_layer).value = "2026-11-01"
	field("Reason for the change",app.modal_layer).text = "Correct received rate"
	click("See affected entries")
	click("Confirm")
	check(app.repo.data.attendance[0].rate == 360,"repricing preview and confirmation update only unpaid rows")
	app.rate_form(app.repo.data.attendance[0].id)
	field("Rate per attendance",app.modal_layer).text = "370"
	field("Reason for the correction",app.modal_layer).text = "Correct one row"
	click("Save corrected rate")
	check(app.repo.data.attendance[0].rate == 370,"single attendance rate correction works")
	app.attendance_edit(app.repo.data.attendance[0].id)
	field("Through",app.modal_layer).value = "2026-11-18"
	field("Attendances",app.modal_layer).text = "30"
	field("Reason for this change",app.modal_layer).text = "New supplied counts"
	click("Save changes")
	check(app.repo.data.attendance[0].end == "2026-11-18" and app.repo.data.attendance[0].half_units == 60,"unpaid correction prefilled and saved")
	app.show_page("Pay")
	app.prepare_payment(first_person,"2026-11-14")
	check(has_text("Attendance before the pay date"),"early payment opens a guided split instead of a technical error")
	field("Attendances in the first part",app.modal_layer).text = "20"
	click("Split attendance")
	check(app.repo.data.attendance.size() == 2 and app.payment_state.result.slips[0].attendance[0].half_units == 40,"guided split resumes payment preview")
	check(int(app.repo.data.attendance[0].half_units)+int(app.repo.data.attendance[1].half_units)==60,"guided split conserves shifts")
	var family_key = app.repo.data.families[0].id
	app.show_page("Pay")
	app.prepare_payment(family_key,"2026-11-02")
	check(app.payment_state.result.slips.size() == 2,"family preview includes each member")
	click("Record payment · ₹0")
	click("Confirm")
	check(app.repo.data.settlements.back().family_id == family_key and app.repo.data.settlements.back().cash == 0,"negative family payment records one combined cash event")
	for member in app.repo.data.families[0].members: app.service.ledger(member,"jama",500,"2026-11-03")
	app.show_page("Home")
	check(has_text("Test Family"),"home includes families with pending amounts")
	var backup = app.repo.backup()
	var working = JSON.stringify(app.repo.data)
	app.preview_restore("not a backup")
	check(JSON.stringify(app.repo.data) == working,"invalid restore leaves working records alone")
	app.preview_restore(backup)
	click("Confirm")
	check(app.repo.data.persons.size() == 4 and app.repo.data.families.size() == 1 and app.repo.data.settlements.size() == 2,"restore preview replaces with the complete validated dataset")
	for page in ["Home","People","Families","Attendance","Money","Pay","History","Settings","More"]:
		app.show_page(page)
		await process_frame
		check(app.body.get_child_count() > 0,"screen renders: "+page)
	app.show_page("Pay")
	var date = field("Pay through")
	date.value = "2026-11-14"
	date.open_calendar()
	await process_frame
	check(click("7"),"calendar offers real day choices")
	check(date.value == "2026-11-07" and date.text.begins_with("7 Nov"),"calendar stores ISO but shows human date")
	app.close_modal()
	print("UI RESULT: ",total-failed,"/",total," checks passed")
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)
