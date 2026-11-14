class_name OpsServiceDetail
extends VBoxContainer
## Contenido del panel de detalle de servicio (derecha). Recibe un modelo de presentación
## (Dictionary construido por OperationsPresenter): `show_service` cambia de servicio con una
## transición de 240 ms; `update_service` refresca los datos en vivo sin animar.

var _code_label: Label
var _route_label: Label
var _delay_label: Label
var _delay_caption: Label
var _chip: RcStatusChip
var _note_label: Label
var _timeline: OpsStopTimeline
var _res_box: VBoxContainer
var _pax_value: Label
var _empty_label: Label
var _body: VBoxContainer
var _res_signature: String = ""
var _tween: Tween


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label = Label.new()
	_empty_label.theme_type_variation = &"LabelMuted"
	_empty_label.text = "Toca un servicio del esquema para ver su detalle."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_empty_label)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", RcTokens.SP_2)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.visible = false
	add_child(_body)

	var head := HBoxContainer.new()
	_body.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	_code_label = Label.new()
	_code_label.theme_type_variation = &"LabelCode"
	left.add_child(_code_label)
	_route_label = Label.new()
	_route_label.theme_type_variation = &"LabelBody"
	_route_label.clip_text = true
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
	_body.add_child(_chip)
	_note_label = Label.new()
	_note_label.theme_type_variation = &"LabelSecondary"
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_note_label)

	_body.add_child(_section("Paradas"))
	_timeline = OpsStopTimeline.new()
	_body.add_child(_timeline)

	_body.add_child(_section("Recursos asignados"))
	_res_box = VBoxContainer.new()
	_res_box.add_theme_constant_override("separation", 2)
	_body.add_child(_res_box)

	var pax_row: HBoxContainer = _info_row("Viajeros", "")
	_pax_value = pax_row.get_child(1) as Label
	_body.add_child(pax_row)


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"LabelPanelTitle"
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", RcTokens.TEXT_MUTED)
	return label


func _info_row(key: String, value_text: String, value_variation: StringName = &"LabelBody") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", RcTokens.SP_2)
	var name_label := Label.new()
	name_label.theme_type_variation = &"LabelSecondary"
	name_label.text = key
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.theme_type_variation = value_variation
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func clear() -> void:
	_body.visible = false
	_empty_label.visible = true


func show_service(model: Dictionary, animate: bool = true) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var total: float = RcTokens.dur(RcTokens.DUR_PANEL)
	if not animate or total <= 0.0:
		_apply(model)
		modulate.a = 1.0
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 0.0, total * 0.35).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_apply.bind(model))
	_tween.tween_property(self, "modulate:a", 1.0, total * 0.65).set_ease(Tween.EASE_OUT)


## Refresco en vivo del servicio ya mostrado (sin transición).
func update_service(model: Dictionary) -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		return
	_apply(model)


func _apply(model: Dictionary) -> void:
	_body.visible = true
	_empty_label.visible = false
	var state: RcTokens.State = model["state"]
	var col: Color = RcTokens.state_color(state)
	_code_label.text = model["code"]
	_route_label.text = model["route"]
	_delay_label.text = model["delay"]
	_delay_label.add_theme_color_override("font_color", col)
	_chip.text = model["status"]
	_chip.state = state
	_note_label.text = model["note"]
	_timeline.set_stops(model["stops"], state)
	_pax_value.text = model["passengers"]
	_set_resources(model["resources"])


## Filas de recursos: [tipo, etiqueta, tramo, es_actual]. Se reconstruyen solo si cambian.
func _set_resources(rows: Array) -> void:
	var signature: String = str(rows)
	if signature == _res_signature:
		return
	_res_signature = signature
	for child: Node in _res_box.get_children():
		_res_box.remove_child(child)
		child.queue_free()
	var last_type: String = ""
	for row: Array in rows:
		var type_name: String = row[0]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", RcTokens.SP_2)
		var key := Label.new()
		key.theme_type_variation = &"LabelSecondary"
		key.text = type_name if type_name != last_type else ""
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(key)
		last_type = type_name
		var leg: String = row[2]
		if not leg.is_empty():
			var leg_label := Label.new()
			leg_label.theme_type_variation = &"LabelMuted"
			leg_label.text = leg
			line.add_child(leg_label)
		var value := Label.new()
		value.theme_type_variation = &"LabelBodyStrong" if bool(row[3]) else &"LabelBody"
		value.text = row[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not bool(row[3]) and not leg.is_empty():
			value.add_theme_color_override("font_color", RcTokens.TEXT_SECONDARY)
		line.add_child(value)
		_res_box.add_child(line)
