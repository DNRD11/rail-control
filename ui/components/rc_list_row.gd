class_name RcListRow
extends PanelContainer
## Fila táctil de 56 px (72 px con `tall`): chip/código a la izquierda, título + subtítulo y valor a la
## derecha. Con `selectable` responde a la pulsación (al soltar, para no robar el arrastre del scroll)
## y se ilumina con `selected`.

signal pressed

@export var selectable: bool = false
@export var tall: bool = false:
	set(value):
		tall = value
		custom_minimum_size.y = RcTokens.ROW_TALL_H if value else RcTokens.ROW_H
@export var selected: bool = false:
	set(value):
		selected = value
		theme_type_variation = &"PanelRowSelected" if value else &"PanelRow"

var _lead: RcStatusChip
var _title: Label
var _subtitle: Label
var _trailing: Label
var _chevron: Label
var _down_at: Vector2 = Vector2.ZERO


func _init() -> void:
	theme_type_variation = &"PanelRow"
	custom_minimum_size = Vector2(0, RcTokens.ROW_H)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_construct()  # los hijos existen desde el principio: `setup` puede llamarse antes de entrar en el árbol


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_PASS


func _construct() -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", RcTokens.SP_3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	_lead = RcStatusChip.new()
	_lead.visible = false
	line.add_child(_lead)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = &"LabelBodyStrong"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"LabelSecondary"
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.visible = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_subtitle)
	_trailing = Label.new()
	_trailing.theme_type_variation = &"LabelData"
	_trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trailing.visible = false
	_trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_trailing)


## `lead` = texto del chip (vacío = sin chip); estados -1 = texto normal.
func setup(title: String, subtitle: String = "", lead: String = "", lead_state: RcTokens.State = RcTokens.State.IDLE,
		trailing: String = "", trailing_state: int = -1) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_lead.text = lead
	_lead.state = lead_state
	_lead.visible = not lead.is_empty()
	_trailing.text = trailing
	_trailing.visible = not trailing.is_empty()
	var col: Color = RcTokens.TEXT_PRIMARY
	if trailing_state >= 0:
		col = RcTokens.state_color(trailing_state as RcTokens.State)
	_trailing.add_theme_color_override("font_color", col)


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down_at = mb.position
	elif mb.position.distance_to(_down_at) < 12.0 and Rect2(Vector2.ZERO, size).has_point(mb.position):
		pressed.emit()
		accept_event()
