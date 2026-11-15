extends RcScreenFrame
## Informe final: nota A-D, tres indicadores con lectura, desglose económico, viajeros,
## servicios con retraso e incidencias con su decisión. Botones Menú principal / Reintentar.

const GRADE_MARKS: PackedFloat32Array = [55.0, 70.0, 85.0]

var _m: Dictionary = {}


func _init() -> void:
	screen_title = "Informe de la jornada"
	kicker = "Fin de jornada"


func _build() -> void:
	_m = ReportPresenter.build(AppFlow.last_report.to_dict() if AppFlow.last_report != null else {})
	set_title(String(_m["scenario"]) if not String(_m["scenario"]).is_empty() else "Informe de la jornada",
			"Informe de la jornada")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	body.add_child(row)
	row.add_child(_grade_panel())
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	mid.add_child(_economy_panel())
	mid.add_child(_passengers_panel())
	row.add_child(mid)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 336
	right.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	right.add_child(_list_panel("Servicios con retraso", _m["delayed"], "Ningún servicio con retraso", true))
	right.add_child(_list_panel("Incidencias y decisiones", _m["incidents"], "Sin incidencias", false))
	row.add_child(right)

	var menu := RcButton.new()
	menu.text = "Menú principal"
	menu.icon_name = "home"
	menu.large = true
	menu.custom_minimum_size.x = 220
	menu.pressed.connect(func() -> void: AppFlow.go(AppFlow.MAIN_MENU))
	footer.add_child(menu)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var retry := RcButton.new()
	retry.text = "Reintentar"
	retry.icon_name = "retry"
	retry.kind = RcButton.Kind.PRIMARY
	retry.large = true
	retry.custom_minimum_size.x = 220
	retry.pressed.connect(_on_retry)
	footer.add_child(retry)


## Reintentar: nueva jornada del mismo escenario.
func _on_retry() -> void:
	if AppFlow.start_new_day():
		AppFlow.go(AppFlow.OPERATIONS)


func _grade_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Calificación"
	panel.custom_minimum_size.x = 304
	panel.content_separation = RcTokens.SP_3
	var badge := RcGradeBadge.new()
	badge.grade = String(_m["grade"])
	badge.score = float(_m["score"])
	badge.diameter = 144.0
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(badge)
	var headline := Label.new()
	headline.theme_type_variation = &"LabelTitle"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.text = String(_m["headline"])
	panel.add_child(headline)
	var readings: Dictionary = _m["readings"]
	panel.add_child(_indicator("Calidad del servicio", "%d" % int(roundf(float(_m["quality"]))),
			float(_m["quality"]), readings["quality"], true))
	panel.add_child(_indicator("Percepción de los viajeros", "%d" % int(roundf(float(_m["perception"]))),
			float(_m["perception"]), readings["perception"], true))
	var result: int = int(_m["result_cents"])
	panel.add_child(_indicator("Resultado económico", RcFormat.eur_signed(result), 0.0, readings["result"], false))
	return panel


func _indicator(caption: String, value: String, meter_value: float, reading: Dictionary, with_meter: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var line := HBoxContainer.new()
	var cap := Label.new()
	cap.theme_type_variation = &"LabelCaption"
	cap.text = caption.to_upper()
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(cap)
	var val := Label.new()
	val.theme_type_variation = &"LabelData"
	val.text = value
	line.add_child(val)
	box.add_child(line)
	if with_meter:
		var meter := RcMeter.new()
		meter.state = reading["state"]
		meter.marks = GRADE_MARKS
		box.add_child(meter)
		meter.value = meter_value
	var chip := RcStatusChip.new()
	chip.text = String(reading["text"])
	chip.state = reading["state"]
	box.add_child(chip)
	return box


func _economy_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Desglose económico"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.content_separation = RcTokens.SP_2
	for r: Dictionary in _m["ledger"]:
		var row := RcBarRow.new()
		panel.add_child(row)
		row.setup(String(r["label"]), RcFormat.eur_signed(int(r["cents"])), float(r["fraction"]), r["state"])
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer)
	panel.add_child(HSeparator.new())
	var total := HBoxContainer.new()
	var name_label := Label.new()
	name_label.theme_type_variation = &"LabelBodyStrong"
	name_label.text = "Resultado de la jornada"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	total.add_child(name_label)
	var value := Label.new()
	value.theme_type_variation = &"LabelBigData"
	var cents: int = int(_m["result_cents"])
	value.text = RcFormat.eur_signed(cents)
	value.add_theme_color_override("font_color", RcTokens.STATE_ALERT if cents < 0 else RcTokens.STATE_OK)
	total.add_child(value)
	panel.add_child(total)
	return panel


func _passengers_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Viajeros"
	panel.content_horizontal = true
	panel.content_separation = RcTokens.SP_3
	for p: Dictionary in _m["passengers"]:
		var tile := RcKpiTile.new()
		tile.caption = String(p["caption"])
		tile.value_text = String(p["value"])
		tile.value_state = int(p["state"])
		tile.show_trend = false
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(tile)
	return panel


func _list_panel(title: String, items: Array, empty_text: String, delayed: bool) -> Control:
	var panel := RcPanel.new()
	panel.title = title
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", RcTokens.SP_2)
	scroll.add_child(list)
	panel.add_child(scroll)
	if items.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"LabelMuted"
		none.text = empty_text
		list.add_child(none)
	for item: Dictionary in items:
		var r := RcListRow.new()
		if delayed:
			r.setup(String(item["title"]), String(item["subtitle"]), String(item["chip"]), item["state"])
		else:
			r.setup(String(item["title"]), String(item["subtitle"]), "", RcTokens.State.IDLE, String(item["cost"]))
		list.add_child(r)
	return panel
