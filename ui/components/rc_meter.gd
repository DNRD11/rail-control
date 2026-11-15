class_name RcMeter
extends Control
## Medidor horizontal 0-100 con marcas de umbral (p. ej. los cortes de nota). El relleno se anima
## 240 ms al cambiar de valor y su color depende del estado semántico.

@export var value: float = 0.0:
	set(v):
		value = v
		_animate_to(v)
@export var state: RcTokens.State = RcTokens.State.OK:
	set(v):
		state = v
		queue_redraw()
## Posiciones (0-100) de las marcas de umbral.
@export var marks: PackedFloat32Array = PackedFloat32Array():
	set(v):
		marks = v
		queue_redraw()

const BAR_H := 10.0

var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _animate_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var d: float = RcTokens.dur(RcTokens.DUR_PANEL)
	if d <= 0.0 or not is_inside_tree():
		_set_shown(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_shown, _shown, target, d * 2.0)


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _draw() -> void:
	var col: Color = RcTokens.state_color(state)
	var y: float = (size.y - BAR_H) * 0.5
	draw_style_box(RcTokens.make_box(RcTokens.STROKE_SUBTLE, 5), Rect2(0, y, size.x, BAR_H))
	var w: float = size.x * clampf(_shown / 100.0, 0.0, 1.0)
	if w >= 2.0:
		draw_style_box(RcTokens.make_box(col, 5), Rect2(0, y, maxf(w, BAR_H), BAR_H))
	for m: float in marks:
		var x: float = size.x * m / 100.0
		draw_line(Vector2(x, y - 3.0), Vector2(x, y + BAR_H + 3.0), RcTokens.with_alpha(RcTokens.TEXT_SECONDARY, 0.55), 1.5)
