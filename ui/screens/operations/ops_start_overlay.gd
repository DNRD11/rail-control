class_name OpsStartOverlay
extends Control
## Velo sobre el esquema antes de iniciar la jornada (o con el error de carga del escenario).
## Solo emite `start_pressed`; no conoce la simulación.

signal start_pressed

var _title: Label
var _sub: Label
var _button: RcButton
var _card: PanelContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20


func _ready() -> void:
	var veil := ColorRect.new()
	veil.color = RcTokens.with_alpha(RcTokens.BG_BASE, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"PanelRaised"
	_card.custom_minimum_size = Vector2(380, 0)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", RcTokens.SP_3)
	_card.add_child(col)
	var kicker := Label.new()
	kicker.theme_type_variation = &"LabelPanelTitle"
	kicker.text = "CENTRO DE GESTIÓN DE OPERACIONES"
	kicker.add_theme_color_override("font_color", RcTokens.ACCENT)
	col.add_child(kicker)
	_title = Label.new()
	_title.theme_type_variation = &"LabelHeading"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_sub = Label.new()
	_sub.theme_type_variation = &"LabelSecondary"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
	_button = RcButton.new()
	_button.kind = RcButton.Kind.PRIMARY
	_button.text = "Iniciar jornada"
	_button.pressed.connect(func() -> void: start_pressed.emit())
	col.add_child(_button)


func show_ready(title: String, detail: String, button_text: String = "Iniciar jornada") -> void:
	visible = true
	_button.text = button_text
	_title.text = title
	_sub.text = detail
	_button.visible = true


func show_error(detail: String) -> void:
	visible = true
	_title.text = "No se pudo cargar el escenario"
	_title.add_theme_color_override("font_color", RcTokens.STATE_ALERT)
	_sub.text = detail
	_button.visible = false
