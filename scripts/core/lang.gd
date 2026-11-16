extends Node
## Language (autoload "Lang"). English by default; one switch turns every word
## in the app to Hindi. Numbers always stay as English digits.

signal changed

var lang := "en"


func _ready() -> void:
	# DB loads after us; it calls set_lang() with the saved choice.
	pass


func set_lang(l: String, persist := true) -> void:
	if l != "en" and l != "hi":
		l = "en"
	if l == lang:
		return
	lang = l
	if persist and DB:
		DB.data.settings.lang = l
		DB.save()
	changed.emit()


# ---------------------------------------------------------------------------
# Names in Hindi letters. Names are saved as typed (English letters); in Hindi
# every label that shows a person or mill name shows it in Hindi letters.
# A person or mill may have its own Hindi spelling ("hi", typed in English
# letters, e.g. "Raamu" → रामू).
# ---------------------------------------------------------------------------

var _names_dirty := true
var _names_re: RegEx
var _names := {}   # English name → Hindi letters
var _hooked := false


func name_hi(name: String, spelling := "") -> String:
	return Translit.to_hi(spelling if spelling.strip_edges() != "" else name)


func show(text: String) -> String:
	## In Hindi, the person and mill names inside text are written in Hindi letters.
	if lang != "hi" or text == "":
		return text
	_build_names()
	if _names_re == null:
		return text
	var out := ""
	var at := 0
	for m in _names_re.search_all(text):
		out += text.substr(at, m.get_start(1) - at) + String(_names.get(m.get_string(1), m.get_string(1)))
		at = m.get_end(1)
	return out + text.substr(at)


func name_of(name: String) -> String:
	## One name as it should be shown now.
	if lang != "hi":
		return name
	_build_names()
	return _names.get(name, Translit.to_hi(name))


func _build_names() -> void:
	if not _hooked and DB:
		DB.changed.connect(func(): _names_dirty = true)
		_hooked = true
	if not _names_dirty:
		return
	_names_dirty = false
	_names.clear()
	var add := func(n: String, spelling: String):
		n = n.strip_edges()
		if n != "" and not _names.has(n):
			_names[n] = name_hi(n, spelling)
	for p in DB.data.get("people", []):
		add.call(String(p.get("name", "")), String(p.get("hi", "")))
	for m in DB.data.get("mills", []):
		add.call(String(m.get("name", "")), String(m.get("hi", "")))
	# Names kept in old payments (before a rename).
	for pay in DB.data.get("payments", []):
		add.call(String(pay.get("payee_name", "")), "")
		for r in pay.get("rows", []):
			add.call(String(r.get("person_name", "")), "")
			add.call(String(r.get("mill_name", "")), "")
	if _names.is_empty():
		_names_re = null
		return
	var keys: Array = _names.keys()
	keys.sort_custom(func(a, b): return a.length() > b.length())
	var parts := []
	for k in keys:
		parts.append(_re_escape(k))
	_names_re = RegEx.new()
	_names_re.compile("(?<![A-Za-z])(" + "|".join(parts) + ")(?![A-Za-z])")


static func _re_escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in "\\^$.|?*+()[]{}-/":
			out += "\\" + ch
		else:
			out += ch
	return out


func t(key: String, args: Array = []) -> String:
	var table: Dictionary = Strings.HI if lang == "hi" else Strings.EN
	var s: String = table.get(key, Strings.EN.get(key, key))
	if not args.is_empty():
		s = s % args
	return s


func post_name(post: String) -> String:
	match post:
		"BM":
			return t("post_bm")
		"F":
			return t("post_f")
		"H":
			return t("post_h")
	return post


func entry_type(type: String) -> String:
	return t("type_" + type)


func month_short(m: int) -> String:
	return t("mon_%d" % m)


func month_long(m: int) -> String:
	return t("month_%d" % m)


func date_short(s: String) -> String:
	## "7 Nov"
	if s == "":
		return "—"
	return "%d %s" % [Dates.day(s), month_short(Dates.month(s))]


func date_full(s: String) -> String:
	## "7 Nov 2026"
	if s == "":
		return "—"
	return "%d %s %d" % [Dates.day(s), month_short(Dates.month(s)), Dates.year(s)]


func date_smart(s: String) -> String:
	## Year only when it is not this year.
	if s == "":
		return "—"
	if Dates.year(s) == Dates.year(Dates.today()):
		return date_short(s)
	return date_full(s)


func period(from: String, upto: String) -> String:
	## Always the exact days: "1 Oct – 15 Nov 2026", "1 – 31 Oct 2026".
	if from == "" or upto == "":
		return "—"
	if Dates.year(from) == Dates.year(upto):
		if Dates.month(from) == Dates.month(upto):
			return "%d – %d %s %d" % [Dates.day(from), Dates.day(upto), month_short(Dates.month(upto)), Dates.year(upto)]
		return "%s – %s" % [date_short(from), date_full(upto)]
	return "%s – %s" % [date_full(from), date_full(upto)]


func day_label(s: String) -> String:
	var today := Dates.today()
	if s == today:
		return t("today")
	if s == Dates.add_days(today, -1):
		return t("yesterday")
	return date_smart(s)


func ago(seconds: int) -> String:
	## "5 min", "3 hr", "2 days"
	if seconds < 60:
		return t("ago_moment")
	if seconds < 3600:
		return t("ago_min", [seconds / 60])
	if seconds < 86400:
		return t("ago_hr", [seconds / 3600])
	return t("ago_days", [seconds / 86400])


func month_ym(ym: String) -> String:
	## "2026-10" → "Oct 2026"
	if ym.length() < 7:
		return ym
	return "%s %s" % [month_short(int(ym.substr(5, 2))), ym.substr(0, 4)]
