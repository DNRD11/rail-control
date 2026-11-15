extends RcScreenFrame
## Briefing de inicio de jornada: objetivos, resumen del escenario y recursos disponibles.
## «Comenzar jornada» pide a AppFlow crear la sesión (start_new_day) y abrir Operación.

var _model: Dictionary = {}


func _init() -> void:
	screen_title = "Briefing de la jornada"
	show_back = true


func _build() -> void:
	back_pressed.connect(func() -> void: AppFlow.go(AppFlow.SCENARIO_SELECT))
	var id: String = AppFlow.selected_scenario
	if id.is_empty():
		var list: Array[ScenarioInfo] = ScenarioCatalog.list()
		id = String(list[0].id) if not list.is_empty() else ""
	_model = BriefingPresenter.build(id)
	if not bool(_model["ok"]):
		_show_error(String(_model["error"]))
		return
	set_title(String(_model["name"]), "Briefing")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	body.add_child(row)
	row.add_child(_goals_panel())
	row.add_child(_summary_panel())
	row.add_child(_resources_panel())

	var hint := Label.new()
	hint.theme_type_variation = &"LabelMuted"
	hint.text = "La simulación empieza en pausa: dispones de todo el tiempo que necesites antes de pulsar x1."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(hint)
	var start := RcButton.new()
	start.text = "Comenzar jornada"
	start.icon_name = "play"
	start.kind = RcButton.Kind.PRIMARY
	start.large = true
	start.custom_minimum_size.x = 260
	start.pressed.connect(_on_start)
	footer.add_child(start)


func _on_start() -> void:
	if AppFlow.start_new_day():
		AppFlow.go(AppFlow.OPERATIONS)


func _show_error(message: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"LabelBody"
	label.add_theme_color_override("font_color", RcTokens.STATE_ALERT)
	label.text = message
	body.add_child(label)


func _goals_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Objetivos"
	panel.custom_minimum_size.x = 380
	panel.content_separation = RcTokens.SP_3
	for goal: Dictionary in _model["goals"]:
		var card := PanelContainer.new()
		card.theme_type_variation = &"PanelRaised"
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", RcTokens.SP_1)
		card.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", RcTokens.SP_2)
		var chip := RcStatusChip.new()
		chip.state = goal["state"]
		chip.text = String(goal["title"])
		head.add_child(chip)
		col.add_child(head)
		var text := Label.new()
		text.theme_type_variation = &"LabelSecondary"
		text.add_theme_font_size_override("font_size", RcTokens.FS_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = String(goal["text"])
		col.add_child(text)
		panel.add_child(card)
	return panel


func _summary_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Resumen del escenario"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.content_separation = RcTokens.SP_3
	var desc := Label.new()
	desc.theme_type_variation = &"LabelBody"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = String(_model["description"])
	panel.add_child(desc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", RcTokens.SP_3)
	grid.add_theme_constant_override("v_separation", RcTokens.SP_3)
	var items: Array[Array] = [["Franja horaria", String(_model["window"])], ["Servicios", str(_model["services"])],
			["Estaciones", str(_model["stations"])], ["Longitud de la línea", "%d km" % int(_model["length_km"])]]
	for item: Array in items:
		var tile := RcKpiTile.new()
		tile.caption = item[0]
		tile.value_text = item[1]
		tile.show_trend = false
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	panel.add_child(grid)
	var caption := Label.new()
	caption.theme_type_variation = &"LabelCaption"
	caption.text = "LÍNEA"
	panel.add_child(caption)
	var glyph := RcLineGlyph.new()
	glyph.stations = _model["line"]
	panel.add_child(glyph)
	return panel


func _resources_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Recursos disponibles"
	panel.custom_minimum_size.x = 340
	panel.content_separation = RcTokens.SP_2
	for r: Dictionary in _model["resources"]:
		var row := RcListRow.new()
		row.setup(String(r["label"]), String(r["note"]), "", RcTokens.State.IDLE, String(r["value"]))
		panel.add_child(row)
	return panel
