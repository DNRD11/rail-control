class_name RcGradeBadge
extends Control
## Calificación de la jornada (A-D): letra grande dentro de un anillo cuyo arco indica la
## puntuación 0-100. El color depende de la nota y la letra es el canal no cromático.

@export var grade: String = "A":
	set(value):
		grade = value
		queue_redraw()
## Puntuación 0-100 del arco; negativo = sin arco.
@export var score: float = -1.0:
	set(value):
		score = value
		queue_redraw()
@export var diameter: float = 168.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()

var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_shown = 1.0
	if RcTokens.dur(RcTokens.DUR_PANEL) > 0.0 and is_inside_tree():
		_shown = 0.0
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_shown, 0.0, 1.0, RcTokens.dur(RcTokens.DUR_PANEL) * 3.0)


func _set_shown(value: float) -> void:
	_shown = value
	queue_redraw()


static func grade_color(letter: String) -> Color:
	match letter:
		"A":
			return RcTokens.STATE_OK
		"B":
			return RcTokens.ACCENT
		"C":
			return RcTokens.STATE_WARN
	return RcTokens.STATE_ALERT


func _draw() -> void:
	var col: Color = grade_color(grade)
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 6.0
	draw_circle(c, r, RcTokens.BG_RAISED)
	draw_arc(c, r, 0.0, TAU, 64, RcTokens.STROKE_STRONG, 6.0, true)
	if score >= 0.0:
		var sweep: float = TAU * clampf(score / 100.0, 0.0, 1.0) * _shown
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + sweep, 64, col, 6.0, true)
	draw_arc(c, r - 14.0, 0.0, TAU, 64, RcTokens.with_alpha(col, 0.22), 1.5, true)
	RcDraw.text_center(self, RcTokens.font_text_semibold(), grade, c + Vector2(0, 2), int(r * 1.15), col)
	RcDraw.text_center(self, RcTokens.font_title(), "NOTA", c + Vector2(0, -r * 0.62), 13, RcTokens.TEXT_SECONDARY)
