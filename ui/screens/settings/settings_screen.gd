extends RcScreenFrame
## Configuración: velocidad por defecto, pausa automática en incidencia, escala de la interfaz y
## reducción de animaciones. Lee/escribe `AppFlow.settings` (se persiste con save()); la reducción de animaciones va por UiSettings.

const SPEEDS: Array[int] = [1, 2, 4]
const SCALES: Array[float] = [0.9, 1.0, 1.15]


func _init() -> void:
	screen_title = "Configuración"
	show_back = true


func _build() -> void:
	back_pressed.connect(_leave)
	var panel := RcPanel.new()
	panel.title = "Jugabilidad y pantalla"
	panel.custom_minimum_size.x = 780
	panel.content_separation = RcTokens.SP_1

	var speed := RcSegmentedControl.new()
	speed.options = PackedStringArray(["x1", "x2", "x4"])
	speed.segment_width = 64.0
	speed.selected = maxi(SPEEDS.find(AppFlow.settings.default_speed), 0)
	speed.selected_changed.connect(func(i: int) -> void: _store(&"default_speed", SPEEDS[i]))
	panel.add_child(_row("Velocidad inicial", "Velocidad de simulación al comenzar o reanudar la jornada.", speed))

	var pause := RcToggle.new()
	pause.pressed = AppFlow.settings.auto_pause_on_incident
	pause.toggled.connect(func(on: bool) -> void: _store(&"auto_pause_on_incident", on))
	panel.add_child(_row("Pausa automática en incidencia",
			"Detiene la simulación y abre la hoja de decisión cuando se detecta una avería.", pause))

	var scale := RcSegmentedControl.new()
	scale.options = PackedStringArray(["Pequeña", "Normal", "Grande"])
	scale.segment_width = 104.0
	scale.selected = maxi(SCALES.find(AppFlow.settings.ui_scale), 1)
	scale.selected_changed.connect(func(i: int) -> void:
		_store(&"ui_scale", SCALES[i])
		UiSettings.apply_all())
	panel.add_child(_row("Tamaño de la interfaz", "Amplía o reduce textos y controles en toda la aplicación.", scale))

	var motion := RcToggle.new()
	motion.pressed = UiSettings.reduce_motion()
	motion.toggled.connect(UiSettings.set_reduce_motion)
	panel.add_child(_row("Reducir animaciones", "Desactiva transiciones y destellos. No afecta a la simulación.", motion, false))
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(panel)
	body.add_child(holder)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var done := RcButton.new()
	done.text = "Volver"
	done.icon_name = "check"
	done.kind = RcButton.Kind.PRIMARY
	done.large = true
	done.custom_minimum_size.x = 220
	done.pressed.connect(_leave)
	footer.add_child(done)


func _row(title: String, hint: String, control: Control, separator: bool = true) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", RcTokens.SP_3)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", RcTokens.SP_4)
	line.custom_minimum_size.y = RcTokens.ROW_TALL_H
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := Label.new()
	t.theme_type_variation = &"LabelBodyStrong"
	t.text = title
	texts.add_child(t)
	var h := Label.new()
	h.theme_type_variation = &"LabelSecondary"
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.text = hint
	texts.add_child(h)
	line.add_child(texts)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(control)
	box.add_child(line)
	if separator:
		box.add_child(HSeparator.new())
	return box


## Escribe el ajuste en Settings y lo persiste.
func _store(key: StringName, value: Variant) -> void:
	AppFlow.settings.set(key, value)
	AppFlow.settings.save()


## Con una jornada en curso (se llegó desde el menú de pausa) vuelve a Operación; si no, al menú.
func _leave() -> void:
	AppFlow.go(AppFlow.OPERATIONS if AppFlow.host.session != null else AppFlow.MAIN_MENU)
