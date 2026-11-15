class_name Dates
extends RefCounted
## Calendar helpers. Dates are plain "YYYY-MM-DD" strings everywhere in the app,
## so they sort and compare correctly as text.

const MONTHS_EN := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const MONTHS_LONG_EN := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

## Test hook: when set, today() returns this instead of the system date.
static var fake_today := ""


static func today() -> String:
	if fake_today != "":
		return fake_today
	var d := Time.get_date_dict_from_system()
	return make(d.year, d.month, d.day)


static func make(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]


static func valid(s: String) -> bool:
	if s.length() != 10 or s[4] != "-" or s[7] != "-":
		return false
	var y := year(s)
	var m := month(s)
	var d := day(s)
	return y >= 2000 and y <= 2200 and m >= 1 and m <= 12 and d >= 1 and d <= days_in_month(y, m)


static func year(s: String) -> int:
	return s.substr(0, 4).to_int()


static func month(s: String) -> int:
	return s.substr(5, 2).to_int()


static func day(s: String) -> int:
	return s.substr(8, 2).to_int()


static func is_leap(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or y % 400 == 0


static func days_in_month(y: int, m: int) -> int:
	match m:
		2:
			return 29 if is_leap(y) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


static func month_days_of(s: String) -> int:
	return days_in_month(year(s), month(s))


static func _to_unix(s: String) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": year(s), "month": month(s), "day": day(s), "hour": 12, "minute": 0, "second": 0})


static func add_days(s: String, n: int) -> String:
	var t := _to_unix(s) + n * 86400
	var d := Time.get_date_dict_from_unix_time(t)
	return make(d.year, d.month, d.day)


static func diff_days(a: String, b: String) -> int:
	## Days from a to b (b - a).
	return int(round((_to_unix(b) - _to_unix(a)) / 86400.0))


static func first_of_month(s: String) -> String:
	return make(year(s), month(s), 1)


static func last_of_month(s: String) -> String:
	return make(year(s), month(s), month_days_of(s))


static func last_of_previous_month(s: String) -> String:
	return add_days(first_of_month(s), -1)


static func first_of_previous_month(s: String) -> String:
	return first_of_month(last_of_previous_month(s))


static func add_months(s: String, n: int) -> String:
	var total := year(s) * 12 + (month(s) - 1) + n
	var y := total / 12
	var m := total % 12 + 1
	return make(y, m, mini(day(s), days_in_month(y, m)))


static func months_between(from: String, upto: String) -> Array:
	## Every calendar month touched by the range, as {"ym","from","upto","days","label"}.
	var out := []
	if from == "" or upto == "" or upto < from:
		return out
	var cur := first_of_month(from)
	while cur <= upto:
		var mfrom: String = from if from > cur else cur
		var mend := last_of_month(cur)
		var mupto: String = upto if upto < mend else mend
		out.append({
			"ym": cur.substr(0, 7),
			"from": mfrom,
			"upto": mupto,
			"days": month_days_of(cur),
			"month": month(cur),
			"year": year(cur),
		})
		cur = add_months(cur, 1)
	return out


static func weekday(s: String) -> int:
	## 0 = Sunday.
	var d := Time.get_date_dict_from_unix_time(_to_unix(s))
	return d.weekday
