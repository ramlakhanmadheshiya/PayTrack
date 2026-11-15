class_name PaymentPage
extends Page
## One saved payment: Correct it, Share the bill, Undo it.

var payment_id := ""


func _init() -> void:
	super._init()
	show_large_title = false


func build(b: VBoxContainer) -> void:
	var pay := DB.payment(payment_id)
	title = Lang.t("payment")
	if pay.is_empty():
		b.add_child(UI.empty_state("info", Lang.t("payment_gone"), Lang.t("payment_gone_body")))
		return
	var can_fix := DB.can_undo_payment(payment_id)
	var acts := UI.hbox(10)
	if can_fix:
		acts.add_child(UI.expand(UI.button(Lang.t("correct_payment"), "tinted", func(): Screens.correct_payment(payment_id), "edit")))
	acts.add_child(UI.expand(UI.button(Lang.t("share_bill"), "primary", func(): Bill.share_payment(payment_id), "share")))
	b.add_child(UI.margin(acts, 16, 4, 16, 0))
	if not can_fix:
		b.add_child(UI.footnote(Lang.t("only_latest_payment")))
	b.add_child(UI.margin(Bill.make(pay, 1.0), 16, 12, 16, 0))
	var more := UI.vbox(10)
	var kid: String = pay.khata_id
	if not DB.khata(kid).is_empty():
		more.add_child(UI.button(Lang.t("open_khata"), "secondary", func(): Screens.open_khata(kid), "person"))
	if can_fix:
		more.add_child(UI.button(Lang.t("undo_payment"), "danger", _undo, "undo"))
		more.add_child(UI.wrapped(UI.label(Lang.t("undo_help"), UI.S_CAP, UI.TEXT2)))
	b.add_child(UI.margin(more, 16, 16, 16, 0))


func _undo() -> void:
	var pay := DB.payment(payment_id)
	UI.app.confirm(Lang.t("undo_payment"), Lang.t("undo_q", [pay.payee_name, Money.group(pay.paid)]), Lang.t("undo_payment"), func():
		if DB.undo_payment(payment_id):
			UI.app.toast(Lang.t("payment_undone"))
			UI.app.pop(), true)
