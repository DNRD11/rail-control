class_name RcBullet
extends HBoxContainer
## Línea de lista con marca ✓ dibujada (sin depender de glifos de la fuente) y texto que se ajusta.

@export var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value
@export var state: RcTokens.State = RcTokens.State.OK

var _label: Label


class _Mark extends Control:
	var color: Color = RcTokens.ACCENT

	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 9.0, RcTokens.with_alpha(color, 0.16))
		RcDraw.check(self, size * 0.5, 11.0, color)


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_3)
	var mark := _Mark.new()
	mark.color = RcTokens.state_color(state)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(mark)
	_label = Label.new()
	_label.theme_type_variation = &"LabelBody"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.text = text
	add_child(_label)
