class_name PaymentPage
extends Page
## One saved payment: the bill, share, undo.

var payment_id := ""


func _init() -> void:
	super._init()
	show_large_title = false


func nav_right() -> Control:
	return UI.icon_button("share", func(): Bill.share_payment(payment_id))


func build(b: VBoxContainer) -> void:
	var pay := DB.payment(payment_id)
	title = Lang.t("payment")
	if pay.is_empty():
		b.add_child(UI.empty_state("info", Lang.t("payment_gone"), Lang.t("payment_gone_body")))
		return
	b.add_child(UI.margin(Bill.make(pay, 1.0), 16, 4, 16, 0))
	var acts := UI.vbox(10)
	acts.add_child(UI.button(Lang.t("share_bill"), "primary", func(): Bill.share_payment(payment_id), "share"))
	acts.add_child(UI.wrapped(UI.label(Lang.t("share_bill_help"), UI.S_CAP, UI.TEXT2)))
	var kid: String = pay.khata_id
	if not DB.khata(kid).is_empty():
		acts.add_child(UI.button(Lang.t("open_khata"), "secondary", func(): Screens.open_person(DB.khata(kid).payee_id), "person"))
	if DB.can_undo_payment(payment_id):
		acts.add_child(UI.spacer(10))
		acts.add_child(UI.button(Lang.t("undo_payment"), "danger", _undo, "undo"))
		acts.add_child(UI.wrapped(UI.label(Lang.t("undo_help"), UI.S_CAP, UI.TEXT2)))
	b.add_child(UI.margin(acts, 16, 16, 16, 0))


func _undo() -> void:
	var pay := DB.payment(payment_id)
	UI.app.confirm(Lang.t("undo_payment"), Lang.t("undo_q", [pay.payee_name, Money.group(pay.paid)]), Lang.t("undo_payment"), func():
		if DB.undo_payment(payment_id):
			UI.app.toast(Lang.t("payment_undone"))
			UI.app.pop(), true)
