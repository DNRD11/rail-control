extends RcScreenFrame
## Menú principal: identidad del juego a la izquierda y panel de acciones a la derecha
## (Nueva jornada, Continuar si hay guardado, Configuración, Salir).

const VERSION_TEXT := "Versión 0.1 · MVP Madrid – Barcelona"

var _continue: RcButton


func _init() -> void:
	show_header = false


func _build() -> void:
	var backdrop := MenuBackdrop.new()
	add_child(backdrop)
	move_child(backdrop, 1)  # sobre el fondo, bajo el contenido

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", RcTokens.SP_6)
	body.add_child(row)
	row.add_child(_inset())
	row.add_child(_hero())
	row.add_child(_menu_panel())
	row.add_child(_inset())

	var version := Label.new()
	version.theme_type_variation = &"LabelMuted"
	version.text = VERSION_TEXT
	footer.add_child(version)


func _inset() -> Control:
	var pad := Control.new()
	pad.custom_minimum_size.x = RcTokens.SP_5
	return pad


func _hero() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", RcTokens.SP_2)
	var mark_row := HBoxContainer.new()
	mark_row.add_theme_constant_override("separation", RcTokens.SP_3)
	var mark := BrandMark.new()
	mark.custom_minimum_size = Vector2(44, 44)
	mark_row.add_child(mark)
	var kicker_label := Label.new()
	kicker_label.theme_type_variation = &"LabelKicker"
	kicker_label.text = "CENTRO DE GESTIÓN DE OPERACIONES"
	kicker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark_row.add_child(kicker_label)
	box.add_child(mark_row)
	var title := Label.new()
	title.theme_type_variation = &"LabelDisplay"
	title.text = "Rail Control"
	box.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"LabelBody"
	sub.add_theme_color_override("font_color", RcTokens.TEXT_SECONDARY)
	sub.text = "Dirige la operación de alta velocidad entre Madrid y Barcelona:\nvigila la línea, gestiona las incidencias y cuida a los viajeros."
	box.add_child(sub)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", RcTokens.SP_2)
	for entry: Array in [["Tiempo real", RcTokens.State.OK], ["Decisiones con consecuencias", RcTokens.State.WARN]]:
		var chip := RcStatusChip.new()
		chip.text = entry[0]
		chip.state = entry[1]
		chip.show_icon = false
		chips.add_child(chip)
	var pad := Control.new()
	pad.custom_minimum_size.y = RcTokens.SP_2
	box.add_child(pad)
	box.add_child(chips)
	return box


func _menu_panel() -> Control:
	var panel := RcPanel.new()
	panel.title = "Jornada"
	panel.custom_minimum_size.x = RcTokens.MENU_PANEL_W
	panel.content_separation = RcTokens.SP_3
	# Los hijos añadidos antes de entrar en el árbol se reubican en el contenido del panel.
	var start: RcButton = _button("Nueva jornada", "play", RcButton.Kind.PRIMARY)
	start.pressed.connect(func() -> void: AppFlow.go(AppFlow.SCENARIO_SELECT))
	panel.add_child(start)
	_continue = _button("Continuar", "continue", RcButton.Kind.SECONDARY)
	_continue.visible = AppFlow.has_saved_game()
	_continue.pressed.connect(func() -> void:
		if AppFlow.continue_saved():
			AppFlow.go(AppFlow.OPERATIONS))
	panel.add_child(_continue)
	var settings: RcButton = _button("Configuración", "sliders", RcButton.Kind.SECONDARY)
	settings.pressed.connect(func() -> void: AppFlow.go(AppFlow.SETTINGS))
	panel.add_child(settings)
	var gap := Control.new()
	gap.custom_minimum_size.y = RcTokens.SP_2
	panel.add_child(gap)
	var quit_button: RcButton = _button("Salir", "exit", RcButton.Kind.GHOST)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	panel.add_child(quit_button)
	var holder := CenterContainer.new()
	holder.add_child(panel)
	return holder


func _button(text: String, icon: String, kind: RcButton.Kind) -> RcButton:
	var b := RcButton.new()
	b.text = text
	b.icon_name = icon
	b.kind = kind
	b.large = true
	return b
