class_name RcPanel
extends PanelContainer
## Módulo de consola: cabecera (marca de acento + título condensado + acción) y contenido.
## Los hijos declarados en la escena se reubican automáticamente en `content`.

@export var title: String = "":
	set(value):
		title = value
		_refresh_header()
@export var action_text: String = "":
	set(value):
		action_text = value
		_refresh_header()
@export var show_header: bool = true
@export var compact: bool = false
@export var content_horizontal: bool = false
@export var content_separation: int = RcTokens.SP_2

var content: BoxContainer
var _header: HBoxContainer
var _title_label: Label
var _action_label: Label
var _divider: HSeparator


class _TopLine extends Control:
	## Filete superior de 1 px (acento al 25 %): sensación de «módulo encendido».
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var m: Vector4 = RcDraw.parent_margins(self)
		var left: float = -m.x
		var width: float = size.x + m.x + m.z
		var y: float = -m.y + 0.5
		var r: float = float(RcTokens.RADIUS_PANEL) * 0.6
		var pts := PackedVector2Array([Vector2(left + r, y), Vector2(left + width * 0.25, y),
				Vector2(left + width * 0.75, y), Vector2(left + width - r, y)])
		var cols := PackedColorArray([RcTokens.with_alpha(RcTokens.ACCENT, 0.0), RcTokens.with_alpha(RcTokens.ACCENT, 0.3),
				RcTokens.with_alpha(RcTokens.ACCENT, 0.3), RcTokens.with_alpha(RcTokens.ACCENT, 0.0)])
		draw_polyline_colors(pts, cols, 1.0)


func _ready() -> void:
	theme_type_variation = &"PanelRcCompact" if compact else &"PanelRc"
	var orphans: Array[Node] = []
	for child: Node in get_children():
		orphans.append(child)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", RcTokens.SP_3)
	add_child(root)

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", RcTokens.SP_2)
	var tick := ColorRect.new()
	tick.color = RcTokens.ACCENT
	tick.custom_minimum_size = Vector2(3, 14)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(tick)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"LabelPanelTitle"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title_label)
	_action_label = Label.new()
	_action_label.theme_type_variation = &"LabelDataMuted"
	_header.add_child(_action_label)
	root.add_child(_header)

	_divider = HSeparator.new()
	root.add_child(_divider)

	content = HBoxContainer.new() if content_horizontal else VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", content_separation)
	root.add_child(content)

	for child: Node in orphans:
		child.reparent(content, false)  # conserva el owner (nombres únicos de la escena)

	_header.visible = show_header
	_divider.visible = show_header
	add_child(_TopLine.new())
	_refresh_header()


func _refresh_header() -> void:
	if _title_label == null:
		return
	_title_label.text = title.to_upper()
	_action_label.text = action_text
	_action_label.visible = not action_text.is_empty()
