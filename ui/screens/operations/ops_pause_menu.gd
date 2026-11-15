class_name OpsPauseMenu
extends Control
## Menú de pausa sobre el esquema atenuado: Reanudar, Guardar, Configuración y Abandonar jornada.
## «Abandonar» es destructivo: va separado del resto y pide una segunda confirmación explícita.
## Solo emite señales; la pantalla de Operación decide qué hacer con el tiempo y el flujo.

signal resume_requested
signal save_requested
signal settings_requested
signal abandon_confirmed

var _menu_box: VBoxContainer
var _confirm_box: VBoxContainer
var _time_label: Label
var _save: RcButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 45


func _ready() -> void:
	var veil := ColorRect.new()
	veil.color = RcTokens.with_alpha(RcTokens.BG_BASE, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet := PanelContainer.new()
	sheet.theme_type_variation = &"PanelSheet"
	sheet.custom_minimum_size.x = 400
	center.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", RcTokens.SP_3)
	sheet.add_child(col)
	var kicker := Label.new()
	kicker.theme_type_variation = &"LabelKicker"
	kicker.text = "JORNADA EN PAUSA"
	col.add_child(kicker)
	_time_label = Label.new()
	_time_label.theme_type_variation = &"LabelTitle"
	col.add_child(_time_label)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", RcTokens.SP_3)
	col.add_child(_menu_box)
	_menu_box.add_child(_button("Reanudar", "play", RcButton.Kind.PRIMARY, resume_requested.emit))
	_save = _button("Guardar partida", "save", RcButton.Kind.SECONDARY, save_requested.emit)
	_menu_box.add_child(_save)
	_menu_box.add_child(_button("Configuración", "sliders", RcButton.Kind.SECONDARY, settings_requested.emit))
	var gap := Control.new()
	gap.custom_minimum_size.y = RcTokens.SP_4
	_menu_box.add_child(gap)
	_menu_box.add_child(_button("Abandonar jornada", "exit", RcButton.Kind.DANGER, _ask_confirm))

	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", RcTokens.SP_3)
	_confirm_box.visible = false
	col.add_child(_confirm_box)
	var warn := Label.new()
	warn.theme_type_variation = &"LabelBody"
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.text = "¿Abandonar la jornada? Se perderá el progreso no guardado y no habrá informe."
	_confirm_box.add_child(warn)
	_confirm_box.add_child(_button("Volver al menú de pausa", "arrow-left", RcButton.Kind.SECONDARY, _cancel_confirm))
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = RcTokens.SP_4
	_confirm_box.add_child(gap2)
	_confirm_box.add_child(_button("Sí, abandonar", "exit", RcButton.Kind.DANGER, abandon_confirmed.emit))


func _button(text: String, icon: String, kind: RcButton.Kind, on_press: Callable) -> RcButton:
	var b := RcButton.new()
	b.text = text
	b.icon_name = icon
	b.kind = kind
	b.large = true
	b.pressed.connect(on_press)
	return b


func open(clock_text: String) -> void:
	_time_label.text = "Son las %s" % clock_text
	_cancel_confirm()
	visible = true


func close() -> void:
	visible = false


func _ask_confirm() -> void:
	_menu_box.visible = false
	_confirm_box.visible = true


func _cancel_confirm() -> void:
	_menu_box.visible = true
	_confirm_box.visible = false
