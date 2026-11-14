class_name Payroll
extends RefCounted

# All money and rational operations are integer-only; limits keep products in int64.
const MAX_VALUE = 1000000000

static func round_half_up(n: int, d: int = 1) -> int:
	assert(n >= 0 and d > 0 and n <= 4000000000000000000)
	return (n + d / 2) / d

static func day(s: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(s + "T00:00:00Z")) / 86400

static func date_from_day(d: int) -> String:
	return Time.get_date_string_from_unix_time(d * 86400)

static func valid_date(s: String) -> bool:
	if s.length() != 10 or s[4] != "-" or s[7] != "-":
		return false
	var parts = s.split("-")
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	var y = int(parts[0])
	var m = int(parts[1])
	var d = int(parts[2])
	return y >= 1900 and y <= 2200 and m >= 1 and m <= 12 and d >= 1 and d <= month_days(y, m)

static func month_days(y: int, m: int) -> int:
	if m == 2:
		return 29 if y % 4 == 0 and (y % 100 != 0 or y % 400 == 0) else 28
	return 30 if m in [4, 6, 9, 11] else 31

static func add_months(s: String, k: int) -> String:
	var p = s.split("-")
	var total = int(p[0]) * 12 + int(p[1]) - 1 + k
	var y: int = total / 12
	var m: int = total % 12 + 1
	return "%04d-%02d-%02d" % [y, m, mini(int(p[2]), month_days(y, m))]

static func worker(rate: int, half_units: int, minutes: int) -> Dictionary:
	assert(rate >= 0 and rate <= MAX_VALUE and half_units >= 0 and half_units <= MAX_VALUE and minutes >= 0 and minutes <= MAX_VALUE)
	var attendance = round_half_up(rate * half_units, 2)
	var hours = round_half_up(rate * minutes, 720)
	return {"attendance": attendance, "hours": hours, "total": attendance + hours}

static func master(salary: int, start: String, end: String, half_units: int) -> Dictionary:
	assert(valid_date(start) and valid_date(end) and start <= end and salary >= 0 and salary <= MAX_VALUE)
	var days = day(end) - day(start) + 1
	var cycles = 0
	var length = 0
	var partial = 0
	while true:
		var begin = day(add_months(start, cycles))
		var next = day(add_months(start, cycles + 1))
		length = next - begin
		if next - 1 <= day(end):
			cycles += 1
			if next - 1 == day(end):
				break
		else:
			partial = day(end) - begin + 1
			break
	var base = cycles * salary + round_half_up(salary * partial, length)
	var extra_half = maxi(0, half_units - days * 2)
	var extra = round_half_up(salary * extra_half, length * 2)
	return {"base": base, "extra": extra, "total": base + extra, "days": days, "extra_half_units": extra_half, "cycle_length": length, "salary": salary}

static func net(earnings: int, jama: int, kharchi: int, recovery: int, cash: int = -1) -> Dictionary:
	var total = earnings + jama - kharchi - recovery
	if cash < 0:
		cash = maxi(0, total)
	return {"earnings": earnings, "jama": jama, "kharchi": kharchi, "recovery": recovery, "net": total, "cash": cash, "new_jama": maxi(0, total - cash), "shortfall": maxi(0, -total)}

static func money(amount: int) -> String:
	var s = str(absi(amount))
	var result = s.right(3)
	s = s.left(maxi(0, s.length() - 3))
	while not s.is_empty():
		result = s.right(2) + "," + result
		s = s.left(maxi(0, s.length() - 2))
	return ("−₹" if amount < 0 else "₹") + result
