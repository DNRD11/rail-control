class_name RcBarRow
extends VBoxContainer
## Fila de desglose: etiqueta + importe y una barra proporcional debajo (desglose económico).
## `fraction` 0-1 respecto al mayor importe del conjunto; `state` colorea la barra.

var _label: Label
var _value: Label
var _bar: _Bar


class _Bar extends Control:
	var fraction: float = 0.0
	var color: Color = RcTokens.STATE_OK

	func _init() -> void:
		custom_minimum_size = Vector2(0, 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(RcTokens.make_box(RcTokens.STROKE_SUBTLE, 2), Rect2(Vector2.ZERO, size))
		var w: float = size.x * clampf(fraction, 0.0, 1.0)
		if w >= 1.0:
			draw_style_box(RcTokens.make_box(color, 2), Rect2(Vector2.ZERO, Vector2(maxf(w, 4.0), size.y)))


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_construct()  # `setup` puede llamarse antes de entrar en el árbol


func _construct() -> void:
	var line := HBoxContainer.new()
	add_child(line)
	_label = Label.new()
	_label.theme_type_variation = &"LabelBody"
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_label)
	_value = Label.new()
	_value.theme_type_variation = &"LabelData"
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_value)
	_bar = _Bar.new()
	add_child(_bar)


func setup(label: String, value_text: String, fraction: float, state: RcTokens.State) -> void:
	_label.text = label
	_value.text = value_text
	_bar.fraction = fraction
	_bar.color = RcTokens.state_color(state)
	_bar.queue_redraw()
