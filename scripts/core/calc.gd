class_name Calc
extends RefCounted
## Pure payroll maths. No storage, no UI – everything here is tested in tests/test_core.gd.
##
## Work row (one line of a payment, like one line of the Excel mill sheet):
##   post "F"/"H": amount = round(rate × att + rate × hr ÷ 12)
##   post "BM", mode "normal": amount = round(salary × att ÷ days)
##   post "BM", mode "split":  amount = Σ round(month.salary × month.att ÷ month.days)
## Each row is rounded on its own (half up), then rows are added.

## Effect of each kind of entry on a khata balance (+ means "you owe them more").
const ENTRY_SIGN := {
	"kharchi": -1,
	"advance": -1,
	"payout": -1,
	"received": 1,
	"adjust": 1,
}


static func fh_amount(rate: float, att: float, hr: float) -> int:
	return Money.round_half_up(rate * att + rate * hr / 12.0)


static func bm_amount(salary: float, att: float, days: int) -> int:
	if days <= 0:
		return 0
	return Money.round_half_up(salary * att / float(days))


static func month_amounts(months: Array) -> Array:
	var out := []
	for m in months:
		out.append(bm_amount(float(m.get("salary", 0)), float(m.get("att", 0.0)), int(m.get("days", 0))))
	return out


static func row_amount(row: Dictionary) -> int:
	var post: String = row.get("post", "")
	if post == "BM":
		if row.get("mode", "normal") == "split":
			var total := 0
			for a in month_amounts(row.get("months", [])):
				total += a
			return total
		return bm_amount(float(row.get("rate", 0)), float(row.get("att", 0.0)), int(row.get("days", 0)))
	return fh_amount(float(row.get("rate", 0)), float(row.get("att", 0.0)), float(row.get("hr", 0.0)))


static func row_has_work(row: Dictionary) -> bool:
	if row.get("post", "") == "BM" and row.get("mode", "normal") == "split":
		for m in row.get("months", []):
			if float(m.get("att", 0.0)) > 0.0:
				return true
		return false
	return float(row.get("att", 0.0)) > 0.0 or float(row.get("hr", 0.0)) > 0.0


static func row_att_total(row: Dictionary) -> float:
	if row.get("post", "") == "BM" and row.get("mode", "normal") == "split":
		var t := 0.0
		for m in row.get("months", []):
			t += float(m.get("att", 0.0))
		return t
	return float(row.get("att", 0.0))


static func entry_effect(entry: Dictionary) -> int:
	return int(ENTRY_SIGN.get(entry.get("type", ""), 0)) * int(entry.get("amount", 0))


static func sum_entries(entries: Array) -> Dictionary:
	## Totals per type plus the combined balance effect.
	var t := {"kharchi": 0, "advance": 0, "payout": 0, "received": 0, "adjust": 0, "effect": 0, "count_kharchi": 0}
	for e in entries:
		var ty: String = e.get("type", "")
		if t.has(ty):
			t[ty] += int(e.get("amount", 0))
		if ty == "kharchi":
			t.count_kharchi += 1
		t.effect += entry_effect(e)
	return t


static func hisab(prev_balance: int, rows: Array, entries: Array) -> Dictionary:
	## The hisab card: what is due on a payment.
	var earnings := 0
	for r in rows:
		earnings += row_amount(r)
	var s := sum_entries(entries)
	var due: int = prev_balance + earnings + int(s.effect)
	return {
		"earnings": earnings,
		"prev_balance": prev_balance,
		"kharchi": s.kharchi,
		"advance": s.advance,
		"payout": s.payout,
		"received": s.received,
		"adjust": s.adjust,
		"count_kharchi": s.count_kharchi,
		"due": due,
	}


static func paid_for_choice(due: int, choice: String, custom: int) -> int:
	## choice: "full" | "custom" | "keep"
	match choice:
		"full":
			return maxi(due, 0)
		"custom":
			return maxi(custom, 0)
		_:
			return 0


static func default_upto(pay_date: String, from: String) -> String:
	## Normally the work up to the end of last month is paid; the rest is on hold.
	var u := Dates.last_of_previous_month(pay_date)
	if from != "" and u < from:
		u = pay_date
	return u


static func default_bm_days(from: String, upto: String) -> int:
	## Normal mode: days of the first month of the work period.
	var src: String = from if from != "" else upto
	if src == "":
		return 30
	return Dates.month_days_of(src)


static func value_on(history: Array, date: String, key: String) -> int:
	## Effective-dated value: the latest entry starting on or before `date`;
	## before the first entry, the first entry applies.
	if history.is_empty():
		return 0
	var best: Dictionary = {}
	var earliest: Dictionary = history[0]
	for h in history:
		if String(h.get("from", "")) < String(earliest.get("from", "")):
			earliest = h
		if String(h.get("from", "")) <= date and (best.is_empty() or String(h.get("from", "")) >= String(best.get("from", ""))):
			best = h
	if best.is_empty():
		best = earliest
	return int(best.get(key, 0))
