extends SceneTree
## Genera ui/theme/rc_theme.tres a partir de RcTokens. Ejecutar una vez tras cambiar tokens:
##   godot --headless --path . -s res://ui/theme/build_theme.gd
## El .tres resultante es el Theme único del proyecto.

const OUT_PATH := "res://ui/theme/rc_theme.tres"


func _init() -> void:
	var theme := Theme.new()
	theme.default_font = RcTokens.font_text()
	theme.default_font_size = RcTokens.FS_TEXT
	_labels(theme)
	_panels(theme)
	_buttons(theme)
	_misc(theme)
	var err: Error = ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("No se pudo guardar el tema: %s" % error_string(err))
	else:
		print("Tema guardado en ", OUT_PATH)
	quit(0 if err == OK else 1)


func _label_variation(theme: Theme, name: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, &"Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelPanelTitle", RcTokens.font_title(), RcTokens.FS_PANEL_TITLE, RcTokens.TEXT_SECONDARY)
	_label_variation(theme, &"LabelCaption", RcTokens.font_title(), RcTokens.FS_SMALL, RcTokens.TEXT_SECONDARY)
	_label_variation(theme, &"LabelSecondary", RcTokens.font_text(), RcTokens.FS_SMALL, RcTokens.TEXT_SECONDARY)
	_label_variation(theme, &"LabelMuted", RcTokens.font_text(), RcTokens.FS_SMALL, RcTokens.TEXT_MUTED)
	_label_variation(theme, &"LabelBody", RcTokens.font_text(), RcTokens.FS_TEXT, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelBodyStrong", RcTokens.font_text_semibold(), RcTokens.FS_TEXT, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelHeading", RcTokens.font_text_semibold(), RcTokens.FS_HEADING, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelData", RcTokens.font_mono(), RcTokens.FS_DATA, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelDataMuted", RcTokens.font_mono(), RcTokens.FS_SMALL, RcTokens.TEXT_SECONDARY)
	_label_variation(theme, &"LabelCode", RcTokens.font_mono_medium(), 28, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelClock", RcTokens.font_mono_medium(), RcTokens.FS_CLOCK, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelDisplay", RcTokens.font_text_semibold(), RcTokens.FS_DISPLAY, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelTitle", RcTokens.font_text_semibold(), RcTokens.FS_TITLE, RcTokens.TEXT_PRIMARY)
	_label_variation(theme, &"LabelKicker", RcTokens.font_title(), RcTokens.FS_SMALL, RcTokens.ACCENT)
	_label_variation(theme, &"LabelBigData", RcTokens.font_mono_medium(), 30, RcTokens.TEXT_PRIMARY)


func _panel_variation(theme: Theme, name: StringName, box: StyleBoxFlat, margin_h: int, margin_v: int) -> void:
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	theme.set_type_variation(name, &"PanelContainer")
	theme.set_stylebox("panel", name, box)


func _panels(theme: Theme) -> void:
	var border: Color = RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.6)
	var panel: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_PANEL, RcTokens.RADIUS_PANEL, border, 1)
	panel.shadow_color = Color(0, 0, 0, 0.38)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 4)
	_panel_variation(theme, &"PanelRc", panel, RcTokens.SP_4, RcTokens.SP_4)
	var compact: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	_panel_variation(theme, &"PanelRcCompact", compact, RcTokens.SP_4, RcTokens.SP_1)
	var raised: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_RAISED, RcTokens.RADIUS_CARD,
			RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.5), 1)
	_panel_variation(theme, &"PanelRaised", raised, RcTokens.SP_3, RcTokens.SP_3)
	var overlay: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_PANEL, RcTokens.RADIUS_PANEL,
			RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.9), 1)
	overlay.shadow_color = Color(0, 0, 0, 0.55)
	overlay.shadow_size = 28
	overlay.shadow_offset = Vector2(0, 8)
	_panel_variation(theme, &"PanelSheet", overlay, RcTokens.SP_4, RcTokens.SP_4)
	var tile: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_RAISED, RcTokens.RADIUS_CARD,
			RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.4), 1)
	_panel_variation(theme, &"PanelTile", tile, RcTokens.SP_3, RcTokens.SP_1)
	# Fila seleccionable (RcListRow): reposo, seleccionada (borde acento) y atenuada.
	var row: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_RAISED, RcTokens.RADIUS_CARD,
			RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.45), 1)
	_panel_variation(theme, &"PanelRow", row, RcTokens.SP_3, RcTokens.SP_2)
	var row_sel: StyleBoxFlat = RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.12), RcTokens.RADIUS_CARD,
			RcTokens.with_alpha(RcTokens.ACCENT, 0.45), 1)
	row_sel.shadow_color = RcTokens.with_alpha(RcTokens.ACCENT, 0.08)
	row_sel.shadow_size = 6
	_panel_variation(theme, &"PanelRowSelected", row_sel, RcTokens.SP_3, RcTokens.SP_2)
	var plain: StyleBoxFlat = RcTokens.make_box(Color(0, 0, 0, 0), 0)
	theme.set_stylebox("panel", "PanelContainer", plain)


func _button_styles(theme: Theme, type_name: StringName, normal: StyleBoxFlat, hover: StyleBoxFlat,
		pressed: StyleBoxFlat, disabled: StyleBoxFlat) -> void:
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = RcTokens.SP_4
		box.content_margin_right = RcTokens.SP_4
		box.content_margin_top = RcTokens.SP_3
		box.content_margin_bottom = RcTokens.SP_3
	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hover)
	theme.set_stylebox("pressed", type_name, pressed)
	theme.set_stylebox("hover_pressed", type_name, pressed)
	theme.set_stylebox("disabled", type_name, disabled)
	theme.set_stylebox("focus", type_name, RcTokens.make_box(Color(0, 0, 0, 0), RcTokens.RADIUS_CARD,
			RcTokens.with_alpha(RcTokens.ACCENT, 0.9), 2))
	theme.set_font("font", type_name, RcTokens.font_text_semibold())
	theme.set_font_size("font_size", type_name, RcTokens.FS_TEXT)


func _buttons(theme: Theme) -> void:
	var r: int = RcTokens.RADIUS_CARD
	# Secundario (por defecto): contorno sobre superficie elevada.
	_button_styles(theme, &"Button",
		RcTokens.make_box(RcTokens.BG_RAISED, r, RcTokens.STROKE_STRONG, 1),
		RcTokens.make_box(RcTokens.BG_OVERLAY, r, RcTokens.with_alpha(RcTokens.ACCENT, 0.55), 1),
		RcTokens.make_box(RcTokens.BG_OVERLAY, r, RcTokens.ACCENT, 1),
		RcTokens.make_box(RcTokens.with_alpha(RcTokens.BG_RAISED, 0.5), r, RcTokens.STROKE_SUBTLE, 1))
	theme.set_color("font_color", "Button", RcTokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", RcTokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", RcTokens.ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", RcTokens.ACCENT)
	theme.set_color("font_disabled_color", "Button", RcTokens.TEXT_MUTED)
	# Primario: relleno acento, texto oscuro.
	theme.set_type_variation(&"RcButtonPrimary", &"Button")
	_button_styles(theme, &"RcButtonPrimary",
		RcTokens.make_box(RcTokens.ACCENT, r),
		RcTokens.make_box(RcTokens.ACCENT.lightened(0.18), r),
		RcTokens.make_box(RcTokens.ACCENT.darkened(0.18), r),
		RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.25), r))
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "RcButtonPrimary", RcTokens.BG_BASE)
	theme.set_color("font_disabled_color", "RcButtonPrimary", RcTokens.TEXT_MUTED)
	# Ghost: sin relleno.
	theme.set_type_variation(&"RcButtonGhost", &"Button")
	_button_styles(theme, &"RcButtonGhost",
		RcTokens.make_box(Color(0, 0, 0, 0), r),
		RcTokens.make_box(RcTokens.with_alpha(RcTokens.TEXT_PRIMARY, 0.06), r),
		RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.14), r),
		RcTokens.make_box(Color(0, 0, 0, 0), r))
	theme.set_color("font_color", "RcButtonGhost", RcTokens.TEXT_SECONDARY)
	theme.set_color("font_hover_color", "RcButtonGhost", RcTokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "RcButtonGhost", RcTokens.ACCENT)
	theme.set_color("font_hover_pressed_color", "RcButtonGhost", RcTokens.ACCENT)
	theme.set_color("font_disabled_color", "RcButtonGhost", RcTokens.TEXT_MUTED)
	# Peligro: contorno rojo (acciones destructivas, p. ej. cancelar un servicio).
	var alert: Color = RcTokens.STATE_ALERT
	theme.set_type_variation(&"RcButtonDanger", &"Button")
	_button_styles(theme, &"RcButtonDanger",
		RcTokens.make_box(RcTokens.with_alpha(alert, 0.10), r, RcTokens.with_alpha(alert, 0.7), 1),
		RcTokens.make_box(RcTokens.with_alpha(alert, 0.22), r, alert, 1),
		RcTokens.make_box(RcTokens.with_alpha(alert, 0.34), r, alert, 1),
		RcTokens.make_box(RcTokens.with_alpha(RcTokens.BG_RAISED, 0.5), r, RcTokens.STROKE_SUBTLE, 1))
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "RcButtonDanger", alert)
	theme.set_color("font_disabled_color", "RcButtonDanger", RcTokens.TEXT_MUTED)


func _misc(theme: Theme) -> void:
	var line := StyleBoxLine.new()
	line.color = RcTokens.STROKE_SUBTLE
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 1)
	var vline := StyleBoxLine.new()
	vline.color = RcTokens.STROKE_SUBTLE
	vline.thickness = 1
	vline.vertical = true
	theme.set_stylebox("separator", "VSeparator", vline)
	theme.set_constant("separation", "VSeparator", 1)
	# Barra de desplazamiento fina (paneles con scroll táctil).
	var grabber: StyleBoxFlat = RcTokens.make_box(RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.9), 3)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	var grabber_on: StyleBoxFlat = RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.6), 3)
	grabber_on.content_margin_left = 3
	grabber_on.content_margin_right = 3
	theme.set_stylebox("scroll", "VScrollBar", RcTokens.make_box(Color(0, 0, 0, 0), 3))
	theme.set_stylebox("scroll_focus", "VScrollBar", RcTokens.make_box(Color(0, 0, 0, 0), 3))
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_on)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_on)
	# Iconos de botón: mismo color que el texto en cada estado (los SVG son blancos).
	for type_name: String in ["Button", "RcButtonPrimary", "RcButtonGhost", "RcButtonDanger"]:
		theme.set_constant("h_separation", type_name, RcTokens.SP_2 + 2)
		theme.set_color("icon_disabled_color", type_name, RcTokens.TEXT_MUTED)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			theme.set_color("icon_%s_color" % state, type_name, theme.get_color("font_%s_color" % state, type_name)
					if state != "normal" and state != "focus" else theme.get_color("font_color", type_name))
	theme.set_constant("separation", "VBoxContainer", RcTokens.SP_2)
	theme.set_constant("separation", "HBoxContainer", RcTokens.SP_2)
