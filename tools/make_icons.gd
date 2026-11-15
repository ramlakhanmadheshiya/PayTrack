extends SceneTree
## Renders the logo SVGs into the PNG icons Android and iOS need.
##   godot --headless --path . --script tools/make_icons.gd

func _render(svg_path: String, size: int, out: String, bg := Color(0, 0, 0, 0), scale := "") -> void:
	var text := FileAccess.get_file_as_string(svg_path)
	if scale != "":
		text = text.replace("scale(0.62)", "scale(%s)" % scale)
	var img := Image.new()
	img.load_svg_from_string(text, size / 1024.0)
	if bg.a > 0.0:
		var base := Image.create(size, size, false, Image.FORMAT_RGBA8)
		base.fill(bg)
		base.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		img = base
	img.save_png(out)
	print("wrote ", out)


func _initialize() -> void:
	_render("res://assets/icon/icon.svg", 192, "res://assets/android/icon_main.png")
	_render("res://assets/icon/foreground.svg", 432, "res://assets/android/icon_foreground.png", Color(0, 0, 0, 0), "0.85")
	_render("res://assets/icon/monochrome.svg", 432, "res://assets/android/icon_monochrome.png", Color(0, 0, 0, 0), "0.85")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("#EEF3FC"))
	bg.save_png("res://assets/android/icon_background.png")
	_render("res://assets/icon/icon.svg", 1024, "res://assets/icon/icon-1024.png")
	# iOS app icon must be square with no transparency; the system rounds the corners.
	_render("res://assets/icon/foreground.svg", 1024, "res://assets/icon/ios-1024.png", Color("#EEF3FC"), "1.12")
	quit()
