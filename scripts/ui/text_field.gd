extends LineEdit
## Shared validation for typing, paste and mobile virtual-keyboard changes.
var numeric = false
var observed = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	observed = text
	text_changed.connect(_changed)

func _changed(value: String):
	if numeric:
		# Never turn a pasted decimal or negative sum into a different positive amount.
		if value.contains(".") or value.contains("-") or value.contains("+"):
			text = observed
			caret_column = text.length()
			return
		var clean = ""
		var before_caret = 0
		for index in value.length():
			var character = value[index]
			if character >= "0" and character <= "9":
				clean += character
				if index < caret_column: before_caret += 1
		if clean != value:
			text = clean
			caret_column = before_caret
	observed = text
	queue_redraw()

func _process(_delta: float):
	# Some Web virtual keyboards set text without emitting text_changed.
	# Keep calculations and validation identical to hardware-keyboard entry.
	if text != observed:
		_changed(text)
		text_changed.emit(text)
