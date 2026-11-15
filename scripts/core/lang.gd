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
	if from == "" or upto == "":
		return "—"
	if Dates.year(from) == Dates.year(upto):
		if Dates.month(from) == Dates.month(upto) and Dates.day(from) == 1 and upto == Dates.last_of_month(upto):
			return "%s %d" % [month_long(Dates.month(from)), Dates.year(from)]
		return "%s – %s" % [date_short(from), date_full(upto)]
	return "%s – %s" % [date_full(from), date_full(upto)]


func day_label(s: String) -> String:
	var today := Dates.today()
	if s == today:
		return t("today")
	if s == Dates.add_days(today, -1):
		return t("yesterday")
	return date_smart(s)
