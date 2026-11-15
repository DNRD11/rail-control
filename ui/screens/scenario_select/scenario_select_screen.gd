extends RcScreenFrame
## Selección de escenario: lista a la izquierda (RcListRow) y ficha a la derecha con los datos
## del escenario elegido. «Ver briefing» guarda la elección en AppFlow y avanza.

const LOCKED: Array[Dictionary] = [
	{"title": "Jornada de tarde", "subtitle": "Punta de tarde y servicios especiales"},
	{"title": "Corredor Madrid – Sevilla", "subtitle": "Segunda línea compartiendo Atocha"},
]

var _infos: Array[ScenarioInfo] = []
var _rows: Array[RcListRow] = []
var _selected: int = -1
var _detail_title: Label
var _detail_text: Label
var _tiles: Dictionary[String, RcKpiTile] = {}
var _difficulty: RcStatusChip
var _next: RcButton
var _glyph: RcLineGlyph


func _init() -> void:
	screen_title = "Selección de escenario"
	show_back = true


func _build() -> void:
	back_pressed.connect(func() -> void: AppFlow.go(AppFlow.MAIN_MENU))
	_infos = ScenarioCatalog.list()
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	body.add_child(row)
	row.add_child(_list_panel())
	row.add_child(_detail_panel())

	_next = RcButton.new()
	_next.text = "Ver briefing"
	_next.icon_name = "continue"
	_next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next.kind = RcButton.Kind.PRIMARY
	_next.large = true
	_next.custom_minimum_size.x = 240
	_next.pressed.connect(_on_next)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(_next)
	if not _infos.is_empty():
		var current: String = AppFlow.selected_scenario
		var index: int = 0
		for i: int in _infos.size():
			if String(_infos[i].id) == current:
				index = i
		_select(index)
	else:
		_next.disabled = true


func _list_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Escenarios"
	panel.custom_minimum_size.x = 440
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", RcTokens.SP_2)
	scroll.add_child(list)
	panel.add_child(scroll)
	for i: int in _infos.size():
		var info: ScenarioInfo = _infos[i]
		var r := RcListRow.new()
		r.selectable = true
		r.tall = true
		var meta: Dictionary = ScenarioCatalog.meta(String(info.id))
		r.setup(info.name, "%s – %s · %d servicios" % [RcFormat.hhmm(info.day_start), RcFormat.hhmm(info.day_end),
				int(meta["service_count"])])
		var index: int = i
		r.pressed.connect(func() -> void: _select(index))
		list.add_child(r)
		_rows.append(r)
	for item: Dictionary in LOCKED:
		var locked := RcListRow.new()
		locked.tall = true
		locked.modulate.a = 0.55
		locked.setup(item["title"], item["subtitle"], "Próximamente", RcTokens.State.IDLE)
		list.add_child(locked)
	return panel


func _detail_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Ficha del escenario"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.content_separation = RcTokens.SP_3
	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"LabelTitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_detail_title)
	_difficulty = RcStatusChip.new()
	_difficulty.show_icon = false
	panel.add_child(_difficulty)
	_detail_text = Label.new()
	_detail_text.theme_type_variation = &"LabelBody"
	_detail_text.add_theme_color_override("font_color", RcTokens.TEXT_SECONDARY)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_detail_text)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", RcTokens.SP_3)
	for key: String in ["Franja horaria", "Servicios", "Incidencias previstas"]:
		var tile := RcKpiTile.new()
		tile.caption = key
		tile.show_trend = false
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tiles.add_child(tile)
		_tiles[key] = tile
	panel.add_child(tiles)
	var caption := Label.new()
	caption.theme_type_variation = &"LabelCaption"
	caption.text = "LÍNEA"
	panel.add_child(caption)
	_glyph = RcLineGlyph.new()
	panel.add_child(_glyph)
	var section := Label.new()
	section.theme_type_variation = &"LabelCaption"
	section.text = "QUÉ VAS A HACER"
	panel.add_child(section)
	for line: String in ["Vigilar la circulación de todos los servicios en el esquema de la línea.",
			"Decidir cómo resolver las incidencias con tiempo limitado y consecuencias reales.",
			"Informar a los viajeros afectados y cuidar la calidad, la percepción y el resultado económico."]:
		var bullet := RcBullet.new()
		bullet.text = line
		panel.add_child(bullet)
	return panel


func _select(index: int) -> void:
	_selected = index
	for i: int in _rows.size():
		_rows[i].selected = i == index
	var info: ScenarioInfo = _infos[index]
	var meta: Dictionary = ScenarioCatalog.meta(String(info.id))
	_detail_title.text = info.name
	_detail_text.text = info.description
	var difficulty: String = String(meta["difficulty"])
	_difficulty.visible = not difficulty.is_empty()
	_difficulty.text = "Dificultad: %s" % difficulty
	_tiles["Franja horaria"].value_text = "%s–%s" % [RcFormat.hhmm(info.day_start), RcFormat.hhmm(info.day_end)]
	_tiles["Servicios"].value_text = str(int(meta["service_count"]))
	_tiles["Incidencias previstas"].value_text = str(int(meta["incident_count"]))
	_glyph.stations = BriefingPresenter.line_for(String(info.id))
	AppFlow.selected_scenario = String(info.id)


func _on_next() -> void:
	if _selected >= 0:
		AppFlow.selected_scenario = String(_infos[_selected].id)
		AppFlow.go(AppFlow.BRIEFING)
