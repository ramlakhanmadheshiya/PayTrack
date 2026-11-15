class_name Money
extends RefCounted
## Rupee helpers. All stored money is whole rupees (int).


static func round_half_up(x: float) -> int:
	## Below .5 goes down, .5 and above goes up (negative values mirror this).
	if x < 0.0:
		return -round_half_up(-x)
	return int(floor(x + 0.5 + 1e-7))


static func group(n: int) -> String:
	## Indian digit grouping: 1,84,300
	var neg := n < 0
	var s := str(absi(n))
	if s.length() > 3:
		var last3 := s.substr(s.length() - 3)
		var rest := s.substr(0, s.length() - 3)
		var parts := []
		while rest.length() > 2:
			parts.push_front(rest.substr(rest.length() - 2))
			rest = rest.substr(0, rest.length() - 2)
		if rest != "":
			parts.push_front(rest)
		s = ",".join(parts) + "," + last3
	return ("-" if neg else "") + s


static func rs(n: int) -> String:
	return ("−₹" + group(-n)) if n < 0 else ("₹" + group(n))


static func num(x: float) -> String:
	## Attendance / hours: 31, 31.5, 0.25 – never trailing zeros.
	if is_equal_approx(x, round(x)):
		return str(int(round(x)))
	var s := "%.2f" % x
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	return s
