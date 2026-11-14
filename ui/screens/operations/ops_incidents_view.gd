class_name OpsIncidentsView
extends VBoxContainer
## Panel izquierdo: incidencias activas (Fase 5), avisos de retraso previstos y resumen de la jornada.
## Los datos llegan ya preparados desde OperationsPresenter.

signal notice_selected(code: String)
signal inject_requested

var _incident_box: VBoxContainer
var _notice_box: VBoxContainer
var _stat_value: Label
var _bar: HBoxContainer
var _legend: Label
var _notice_signature: String = ""
var _bar_signature: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_3)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_incident_box = VBoxContainer.new()
	_incident_box.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(_incident_box)
	var empty := Label.new()
	empty.theme_type_variation = &"LabelMuted"
	empty.text = "Sin incidencias activas"
	_incident_box.add_child(empty)

	add_child(_section("Avisos"))
	_notice_box = VBoxContainer.new()
	_notice_box.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(_notice_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	if OS.is_debug_build():
		add_child(_section("Depuración"))
		var inject := RcButton.new()
		inject.text = "Inyectar retraso 3103 (+25′)"
		inject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inject.pressed.connect(func() -> void: inject_requested.emit())
		add_child(inject)

	add_child(_section("Jornada"))
	var row := HBoxContainer.new()
	var k := Label.new()
	k.theme_type_variation = &"LabelSecondary"
	k.text = "Servicios en marcha"
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	_stat_value = Label.new()
	_stat_value.theme_type_variation = &"LabelData"
	row.add_child(_stat_value)
	add_child(row)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 2)
	_bar.custom_minimum_size = Vector2(0, 8)
	add_child(_bar)
	_legend = Label.new()
	_legend.theme_type_variation = &"LabelMuted"
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_legend)


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"LabelPanelTitle"
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", RcTokens.TEXT_MUTED)
	return label


## items: [{code, state, chip, title, detail}]
func set_notices(items: Array[Dictionary]) -> void:
	var signature: String = str(items)
	if signature == _notice_signature:
		return
	_notice_signature = signature
	for child: Node in _notice_box.get_children():
		_notice_box.remove_child(child)
		child.queue_free()
	if items.is_empty():
		var ok := Label.new()
		ok.theme_type_variation = &"LabelMuted"
		ok.text = "Todo el servicio circula según horario."
		ok.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notice_box.add_child(ok)
		return
	for item: Dictionary in items:
		_notice_box.add_child(_notice(item))


func _notice(item: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, RcTokens.TOUCH_MIN)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			notice_selected.emit(item["code"]))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", RcTokens.SP_2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)
	var chip := RcStatusChip.new()
	chip.text = item["chip"]
	chip.state = item["state"]
	chip.show_icon = false
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inner.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"LabelBody"
	t.text = item["title"]
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"LabelMuted"
	d.text = item["detail"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	return row


## summary: {running, total, ontime, minor, major}
func set_summary(summary: Dictionary) -> void:
	_stat_value.text = "%d / %d" % [summary["running"], summary["total"]]
	var signature: String = str(summary)
	if signature == _bar_signature:
		return
	_bar_signature = signature
	for child: Node in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	var segments: Array[Array] = [
		[RcTokens.STATE_OK, summary["ontime"]], [RcTokens.STATE_WARN, summary["minor"]],
		[RcTokens.STATE_ALERT, summary["major"]]]
	var any: bool = false
	for seg: Array in segments:
		if int(seg[1]) <= 0:
			continue
		any = true
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = float(seg[1])
		panel.add_theme_stylebox_override("panel", RcTokens.make_box(seg[0], 4))
		_bar.add_child(panel)
	if not any:
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", RcTokens.make_box(RcTokens.STROKE_STRONG, 4))
		_bar.add_child(panel)
	_legend.text = "%d en hora · %d leve · %d grave" % [summary["ontime"], summary["minor"], summary["major"]]
