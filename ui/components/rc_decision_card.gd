class_name RcDecisionCard
extends PanelContainer
## Opción de decisión con previsualización comparable (mismas métricas, mismo orden en todas las
## tarjetas) y estado deshabilitado con motivo. Una pulsación en el botón confirma la opción.
##
## Modelo (`set_model`):
##   option_type: StringName, title, blurb, button_text: String, danger: bool
##   available: bool, reason: String (si no está disponible)
##   metrics: Array[{label, value, state}]  (state: RcTokens.State o -1 = texto normal)
##   dependents_title: String, dependents: Array[{code, text, state}], dependents_more: int
##   flags: Array[{text, state}]  (avisos como chips: plazas insuficientes, necesitan alternativa)
##   note: String (línea informativa bajo los avisos)

signal chosen(option_type: StringName)

const DEPENDENTS_ROWS := 3

var option_type: StringName = &""

var _title: Label
var _blurb: Label
var _body: VBoxContainer
var _metrics_box: VBoxContainer
var _dep_title: Label
var _dep_box: VBoxContainer
var _flags_box: VBoxContainer
var _note: Label
var _reason_box: VBoxContainer
var _reason_label: Label
var _button: RcButton
var _signature: String = ""


func _ready() -> void:
	theme_type_variation = &"PanelRaised"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(col)

	_title = Label.new()
	_title.theme_type_variation = &"LabelHeading"
	col.add_child(_title)
	_blurb = Label.new()
	_blurb.theme_type_variation = &"LabelSecondary"
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(0, 40)
	col.add_child(_blurb)
	col.add_child(HSeparator.new())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", RcTokens.SP_2)
	col.add_child(_body)
	_metrics_box = VBoxContainer.new()
	_metrics_box.add_theme_constant_override("separation", RcTokens.SP_1)
	_body.add_child(_metrics_box)
	_dep_title = Label.new()
	_dep_title.theme_type_variation = &"LabelCaption"
	_body.add_child(_dep_title)
	_dep_box = VBoxContainer.new()
	_dep_box.add_theme_constant_override("separation", 2)
	_dep_box.custom_minimum_size = Vector2(0, DEPENDENTS_ROWS * 20 + 2)
	_body.add_child(_dep_box)
	_flags_box = VBoxContainer.new()
	_flags_box.add_theme_constant_override("separation", RcTokens.SP_1)
	_body.add_child(_flags_box)
	_note = Label.new()
	_note.theme_type_variation = &"LabelMuted"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_note)

	_reason_box = VBoxContainer.new()
	_reason_box.add_theme_constant_override("separation", RcTokens.SP_2)
	col.add_child(_reason_box)
	var chip := RcStatusChip.new()
	chip.text = "No disponible"
	chip.state = RcTokens.State.IDLE
	_reason_box.add_child(chip)
	_reason_label = Label.new()
	_reason_label.theme_type_variation = &"LabelSecondary"
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_box.add_child(_reason_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_button = RcButton.new()
	_button.pressed.connect(func() -> void: chosen.emit(option_type))
	col.add_child(_button)


func set_model(model: Dictionary) -> void:
	var signature: String = str(model)
	if signature == _signature:
		return
	_signature = signature
	option_type = model.get("option_type", &"")
	var available: bool = bool(model.get("available", true))
	_title.text = model.get("title", "")
	_blurb.text = model.get("blurb", "")
	_button.text = model.get("button_text", "Confirmar")
	_button.kind = RcButton.Kind.DANGER if bool(model.get("danger", false)) else RcButton.Kind.SECONDARY
	_button.disabled = not available
	_body.visible = available
	_reason_box.visible = not available
	_reason_label.text = model.get("reason", "")
	_title.modulate.a = 1.0 if available else 0.6
	_blurb.modulate.a = 1.0 if available else 0.6
	if available:
		_fill_metrics(model.get("metrics", []))
		_fill_dependents(model)
		_fill_flags(model.get("flags", []))
		_note.text = model.get("note", "")
		_note.visible = not _note.text.is_empty()


func _fill_metrics(metrics: Array) -> void:
	_clear(_metrics_box)
	for m: Dictionary in metrics:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.theme_type_variation = &"LabelSecondary"
		k.text = m["label"]
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(_value_label(m["value"], int(m.get("state", -1)), &"LabelData"))
		_metrics_box.add_child(row)


func _fill_dependents(model: Dictionary) -> void:
	_clear(_dep_box)
	_dep_title.text = String(model.get("dependents_title", "")).to_upper()
	var items: Array = model.get("dependents", [])
	if items.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"LabelMuted"
		none.text = "Ninguno"
		_dep_box.add_child(none)
		return
	for item: Dictionary in items:
		var row := HBoxContainer.new()
		var code := Label.new()
		code.theme_type_variation = &"LabelData"
		code.text = item["code"]
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(code)
		row.add_child(_value_label(item["text"], int(item.get("state", -1)), &"LabelData"))
		_dep_box.add_child(row)
	var more: int = int(model.get("dependents_more", 0))
	if more > 0:
		var label := Label.new()
		label.theme_type_variation = &"LabelMuted"
		label.text = "y %d más" % more
		_dep_box.add_child(label)


func _fill_flags(flags: Array) -> void:
	_clear(_flags_box)
	for f: Dictionary in flags:
		var chip := RcStatusChip.new()
		chip.text = f["text"]
		chip.state = int(f["state"]) as RcTokens.State
		_flags_box.add_child(chip)


func _value_label(text: String, state: int, variation: StringName) -> Label:
	var v := Label.new()
	v.theme_type_variation = variation
	v.text = text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if state >= 0:
		v.add_theme_color_override("font_color", RcTokens.state_color(state as RcTokens.State))
	return v


func _clear(box: Control) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
