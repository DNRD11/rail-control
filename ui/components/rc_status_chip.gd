class_name RcStatusChip
extends Control
## Chip de estado: icono + texto + color semántico (el color nunca es el único canal).

@export var text: String = "":
	set(value):
		text = value
		_changed()
@export var state: RcTokens.State = RcTokens.State.OK:
	set(value):
		state = value
		_changed()
@export var show_icon: bool = true:
	set(value):
		show_icon = value
		_changed()
@export var strong: bool = false:
	set(value):
		strong = value
		_changed()

const HEIGHT := 28.0
const PAD_X := 10.0
const ICON := 14.0
const FONT_SIZE := 13


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _changed() -> void:
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var w: float = RcDraw.text_width(RcTokens.font_title(), text.to_upper(), FONT_SIZE) + PAD_X * 2.0
	if show_icon:
		w += ICON + 6.0
	return Vector2(ceilf(w), HEIGHT)


func _draw() -> void:
	var col: Color = RcTokens.state_color(state)
	var fill: Color = RcTokens.with_alpha(col, 0.30 if strong else 0.14)
	var box: StyleBoxFlat = RcTokens.make_box(fill, RcTokens.RADIUS_CHIP, RcTokens.with_alpha(col, 0.55), 1)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var x: float = PAD_X
	var cy: float = size.y * 0.5
	if show_icon:
		RcDraw.state_icon(self, state, Vector2(x + ICON * 0.5, cy), ICON, col)
		x += ICON + 6.0
	RcDraw.text_left(self, RcTokens.font_title(), text.to_upper(), x, cy, FONT_SIZE, col)
