class_name HelpPage
extends Page
## Short guide in plain words.


func _init() -> void:
	super._init()


func build(b: VBoxContainer) -> void:
	title = Lang.t("how_it_works")
	for i in range(1, 10):
		var c := UI.card(16)
		var v := UI.card_body(c)
		v.add_theme_constant_override("separation", 6)
		v.add_child(UI.wrapped(UI.label(Lang.t("help_t%d" % i), UI.S_HEAD, UI.TEXT, 700)))
		v.add_child(UI.wrapped(UI.label(Lang.t("help_b%d" % i), UI.S_SUB, UI.TEXT2)))
		b.add_child(UI.margin(c, 16, 12, 16, 0))
