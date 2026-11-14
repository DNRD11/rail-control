class_name OpsServiceDetail
extends VBoxContainer
## Contenido del panel de detalle de servicio (derecha). `show_service` actualiza los
## datos con una transición de 240 ms (fundido de salida + entrada).

signal primary_pressed(code: String)

var _code_label: Label
var _route_label: Label
var _delay_label: Label
var _delay_caption: Label
var _chip: RcStatusChip
var _note_label: Label
var _timeline: OpsStopTimeline
var _rows: Dictionary[String, Label] = {}
var _primary: RcButton
var _secondary: RcButton
var _current_code: String = ""
var _tween: Tween


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_2)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	_code_label = Label.new()
	_code_label.theme_type_variation = &"LabelCode"
	left.add_child(_code_label)
	_route_label = Label.new()
	_route_label.theme_type_variation = &"LabelBody"
	left.add_child(_route_label)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	head.add_child(right)
	_delay_label = Label.new()
	_delay_label.add_theme_font_override("font", RcTokens.font_mono_medium())
	_delay_label.add_theme_font_size_override("font_size", RcTokens.FS_CLOCK - 4)
	_delay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_delay_label)
	_delay_caption = Label.new()
	_delay_caption.theme_type_variation = &"LabelCaption"
	_delay_caption.text = "RETRASO"
	_delay_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_delay_caption)

	_chip = RcStatusChip.new()
	_chip.strong = true
	add_child(_chip)
	_note_label = Label.new()
	_note_label.theme_type_variation = &"LabelSecondary"
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(0, 34)
	add_child(_note_label)

	add_child(_section("Paradas"))
	_timeline = OpsStopTimeline.new()
	add_child(_timeline)

	add_child(_section("Recursos asignados"))
	for key: String in ["Composición", "Maquinista", "Interventor", "Viajeros"]:
		add_child(_info_row(key))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(buttons)
	_primary = RcButton.new()
	_primary.kind = RcButton.Kind.PRIMARY
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.pressed.connect(func() -> void: primary_pressed.emit(_current_code))
	buttons.add_child(_primary)
	_secondary = RcButton.new()
	_secondary.kind = RcButton.Kind.SECONDARY
	_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_secondary)


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"LabelPanelTitle"
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", RcTokens.TEXT_MUTED)
	return label


func _info_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.theme_type_variation = &"LabelSecondary"
	name_label.text = key
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.theme_type_variation = &"LabelBody"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_rows[key] = value
	return row


func show_service(data: Dictionary, animate: bool = true) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var total: float = RcTokens.dur(RcTokens.DUR_PANEL)
	if not animate or total <= 0.0:
		_apply(data)
		modulate.a = 1.0
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 0.0, total * 0.35).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_apply.bind(data))
	_tween.tween_property(self, "modulate:a", 1.0, total * 0.65).set_ease(Tween.EASE_OUT)


func _apply(data: Dictionary) -> void:
	var state: RcTokens.State = data["state"]
	var col: Color = RcTokens.state_color(state)
	_current_code = data["code"]
	_code_label.text = data["code"]
	_route_label.text = data["route"]
	_delay_label.text = data["delay"]
	_delay_label.add_theme_color_override("font_color", col)
	_chip.text = data["status"]
	_chip.state = state
	_note_label.text = data["note"]
	_timeline.set_stops(data["stops"], state)
	_rows["Composición"].text = data["composition"]
	_rows["Maquinista"].text = data["driver"]
	_rows["Interventor"].text = data["conductor"]
	_rows["Viajeros"].text = data["passengers"]
	_primary.text = data["primary"]
	_secondary.text = data["secondary"]
