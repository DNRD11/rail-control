class_name OpsIncidentsView
extends VBoxContainer
## Panel izquierdo: incidencia activa, avisos previstos y resumen de la jornada (mock).

signal manage_requested


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_3)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card := RcAlertCard.new()
	card.title = "Avería de material"
	card.detail = "Servicio 3103 · entre Calatayud y Zaragoza"
	card.time_text = "07:38"
	card.chip_text = "AVERÍA"
	card.manage_pressed.connect(func() -> void: manage_requested.emit())
	add_child(card)
	card.play_enter()

	add_child(_section("Avisos"))
	add_child(_notice(RcTokens.State.WARN, "+9′", "3105 · rotación de 3103", "Saldría de ZAR a las 08:06"))
	add_child(_notice(RcTokens.State.WARN, "+4′", "3150 · retraso en ruta", "Parada larga en Tarragona"))
	add_child(_notice(RcTokens.State.OK, "OK", "3101 · 3152", "Circulan según horario"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	add_child(_section("Jornada"))
	add_child(_stat_row("Servicios en circulación", "4 / 10"))
	add_child(_punctuality_bar())


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"LabelPanelTitle"
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", RcTokens.TEXT_MUTED)
	return label


func _notice(state: RcTokens.State, chip_text: String, title: String, detail: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", RcTokens.SP_2)
	var chip := RcStatusChip.new()
	chip.text = chip_text
	chip.state = state
	chip.show_icon = false
	chip.custom_minimum_size = Vector2(44, 28)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"LabelBody"
	t.text = title
	t.clip_text = true
	col.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"LabelMuted"
	d.text = detail
	col.add_child(d)
	return row


func _stat_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.theme_type_variation = &"LabelSecondary"
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.theme_type_variation = &"LabelData"
	v.text = value
	row.add_child(v)
	return row


func _punctuality_bar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", RcTokens.SP_1)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 8)
	box.add_child(bar)
	var segments: Array[Array] = [[RcTokens.STATE_OK, 2.0], [RcTokens.STATE_WARN, 1.0], [RcTokens.STATE_ALERT, 1.0]]
	for seg: Array in segments:
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = seg[1]
		panel.add_theme_stylebox_override("panel", RcTokens.make_box(seg[0], 4))
		bar.add_child(panel)
	var legend := Label.new()
	legend.theme_type_variation = &"LabelMuted"
	legend.text = "2 en hora · 1 retraso · 1 incidencia"
	box.add_child(legend)
	return box
