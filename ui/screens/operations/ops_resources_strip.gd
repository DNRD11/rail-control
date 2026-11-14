class_name OpsResourcesStrip
extends HBoxContainer
## Franja de recursos plegada (inferior): material, reserva y personal (solo lectura, mock).


class _Chevron extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		RcDraw.chevron(self, size * 0.5, 14.0, true, RcTokens.TEXT_SECONDARY)


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_4)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	var title := Label.new()
	title.theme_type_variation = &"LabelPanelTitle"
	title.text = "RECURSOS"
	add_child(title)
	var toggle := RcButton.new()
	toggle.kind = RcButton.Kind.GHOST
	toggle.custom_minimum_size = Vector2(RcTokens.TOUCH_MIN, RcTokens.TOUCH_MIN)
	toggle.add_child(_Chevron.new())
	add_child(toggle)
	_add_item("Material", "4/5", "en servicio")
	_add_item("Reserva", "V5", "en Zaragoza")
	_add_item("Maquinistas", "5/6", "")
	_add_item("Interventores", "5/5", "")
	_add_note("Relevo de maquinista en Zaragoza · 09:10")


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


func _add_note(text: String) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var note := Label.new()
	note.theme_type_variation = &"LabelMuted"
	note.text = text
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(note)
