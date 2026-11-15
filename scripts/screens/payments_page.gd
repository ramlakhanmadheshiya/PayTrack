class_name PaymentsPage
extends Page
## Every saved payment, newest first.


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("all_payments")
	var pays: Array = DB.payments_list()
	if pays.is_empty():
		b.add_child(UI.empty_state("pay", Lang.t("no_payments"), Lang.t("no_payments_body")))
		return
	var by_date := {}
	var dates := []
	for p in pays:
		if not by_date.has(p.date):
			by_date[p.date] = []
			dates.append(p.date)
		by_date[p.date].append(p)
	for d in dates:
		var total := 0
		for p in by_date[d]:
			total += int(p.paid)
		b.add_child(UI.section_title(Lang.date_full(d), UI.label(Lang.t("cash_total", [Money.group(total)]), UI.S_CAP, UI.TEXT2, 600, true)))
		var c := UI.card()
		var rows := []
		for p in by_date[d]:
			rows.append(payment_row(p))
		UI.add_rows(c, rows)
		b.add_child(UI.margin(c, 16, 0, 16, 0))


static func payment_row(p: Dictionary, show_name := true) -> Control:
	var name: String = p.get("payee_name", "?")
	var title := name if show_name else Lang.date_full(p.date)
	var sub := Lang.t("work_period_short", [Lang.period(p.from, p.upto)])
	if not show_name:
		sub = Lang.t("work_period_short", [Lang.period(p.from, p.upto)])
	var right := UI.vbox(0)
	var paid := UI.label(Lang.t("paid_x", [Money.group(int(p.paid))]) if int(p.paid) > 0 else Lang.t("no_cash"), UI.S_SUB, UI.TEXT, 600, true)
	paid.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(paid)
	right.add_child(UI.balance_label(int(p.new_balance), UI.S_CAP))
	var id: String = p.id
	return UI.row(title, sub, right, func(): Screens.open_payment(id), true, UI.avatar(name, 36, UI.GREEN_SOFT, UI.GREEN) if show_name else Icons.make("pay", UI.GREEN, 22))
