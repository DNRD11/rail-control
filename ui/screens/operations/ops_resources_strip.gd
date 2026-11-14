class_name OpsResourcesStrip
extends HBoxContainer
## Franja de recursos (inferior): material, reserva y personal. Solo lectura; `set_data` la
## reconstruye únicamente cuando cambian los datos.

var _signature: String = ""


class _Chevron extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		RcDraw.chevron(self, size * 0.5, 14.0, true, RcTokens.TEXT_SECONDARY)


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_4)
	alignment = BoxContainer.ALIGNMENT_BEGIN


## data: {items: [[título, valor, sufijo]], note: String}
func set_data(data: Dictionary) -> void:
	var signature: String = str(data)
	if signature == _signature:
		return
	_signature = signature
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.theme_type_variation = &"LabelPanelTitle"
	title.text = "RECURSOS"
	add_child(title)
	var toggle := RcButton.new()
	toggle.kind = RcButton.Kind.GHOST
	toggle.custom_minimum_size = Vector2(RcTokens.TOUCH_MIN, RcTokens.TOUCH_MIN)
	toggle.add_child(_Chevron.new())
	add_child(toggle)
	for item: Array in data["items"]:
		_add_item(item[0], item[1], item[2])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var note_text: String = data["note"]
	if not note_text.is_empty():
		var note := Label.new()
		note.theme_type_variation = &"LabelMuted"
		note.text = note_text
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(note)


func _add_item(caption: String, value: String, suffix: String) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(1, 24)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(sep)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", RcTokens.SP_2)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c := Label.new()
	c.theme_type_variation = &"LabelCaption"
	c.text = caption.to_upper()
	row.add_child(c)
	var v := Label.new()
	v.theme_type_variation = &"LabelData"
	v.text = value
	row.add_child(v)
	if not suffix.is_empty():
		var s := Label.new()
		s.theme_type_variation = &"LabelMuted"
		s.text = suffix
		row.add_child(s)
	add_child(row)
