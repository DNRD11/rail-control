class_name RcToggle
extends Control
## Interruptor táctil (zona de 64×48 px; pista visible de 48×28). La posición del pomo y la
## marca ✓ son el canal no cromático del estado. Emite `toggled` solo por acción del jugador.

signal toggled(pressed: bool)

@export var pressed: bool = false:
	set(value):
		pressed = value
		_slide(false)

const TRACK_W := 48.0
const TRACK_H := 28.0

var _t: float = 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(64, RcTokens.TOUCH_MIN)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_t = 1.0 if pressed else 0.0


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed = not pressed
		_slide(true)
		toggled.emit(pressed)
		accept_event()


func _slide(animate: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target: float = 1.0 if pressed else 0.0
	var d: float = RcTokens.dur(RcTokens.DUR_STATE)
	if not animate or d <= 0.0 or not is_inside_tree():
		_set_t(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_t, _t, target, d)


func _set_t(value: float) -> void:
	_t = value
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(size.x - TRACK_W, (size.y - TRACK_H) * 0.5)
	var track_col: Color = RcTokens.STROKE_STRONG.lerp(RcTokens.with_alpha(RcTokens.ACCENT, 0.9), _t)
	var fill: Color = RcTokens.BG_RAISED.lerp(RcTokens.with_alpha(RcTokens.ACCENT, 0.22), _t)
	draw_style_box(RcTokens.make_box(fill, int(TRACK_H * 0.5), track_col, 1), Rect2(origin, Vector2(TRACK_W, TRACK_H)))
	var knob_r: float = TRACK_H * 0.5 - 4.0
	var cx: float = origin.x + 4.0 + knob_r + (TRACK_W - 8.0 - knob_r * 2.0) * _t
	var knob_col: Color = RcTokens.TEXT_MUTED.lerp(RcTokens.ACCENT, _t)
	var c := Vector2(cx, origin.y + TRACK_H * 0.5)
	draw_circle(c, knob_r, knob_col)
	if _t > 0.6:
		RcDraw.check(self, c, knob_r * 1.1, RcTokens.BG_BASE)
