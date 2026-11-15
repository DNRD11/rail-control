class_name MenuBackdrop
extends Control
## Ilustración del menú principal: dos vías con estaciones y servicios que avanzan lentamente.
## Decorativa: sin interacción; el movimiento se detiene con «Reducir animaciones».

const SPEED := 22.0  # px/s
const STATIONS: Array[float] = [0.05, 0.19, 0.42, 0.55, 0.71, 0.83, 0.95]

## [vía (0 sup., 1 inf.), posición inicial 0-1, sentido, estado, código]
const MARKERS: Array = [
	[0, 0.62, -1, 0, "3150"], [0, 0.18, -1, 0, "3152"], [1, 0.30, 1, 0, "3101"], [1, 0.80, 1, 1, "3105"]]

var _phase: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if RcTokens.reduce_motion:
		return
	_phase += delta * SPEED
	queue_redraw()


func _draw() -> void:
	var ys: Array[float] = [size.y - 128.0, size.y - 84.0]
	for y: float in ys:
		draw_line(Vector2(0, y), Vector2(size.x, y), RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.7), 3.0, true)
	for f: float in STATIONS:
		var x: float = size.x * f
		var rect := Rect2(x - 7.0, ys[0] - 22.0, 14.0, ys[1] - ys[0] + 44.0)
		draw_style_box(RcTokens.make_box(RcTokens.with_alpha(RcTokens.BG_PANEL, 0.9), 7,
				RcTokens.with_alpha(RcTokens.STROKE_STRONG, 0.8), 1), rect)
		draw_circle(Vector2(x, ys[0]), 3.0, RcTokens.STROKE_STRONG)
		draw_circle(Vector2(x, ys[1]), 3.0, RcTokens.STROKE_STRONG)
	for m: Array in MARKERS:
		_marker(ys[int(m[0])], float(m[1]), int(m[2]), int(m[3]), String(m[4]))


func _marker(y: float, start: float, dir: int, state: int, code: String) -> void:
	var span: float = size.x + 120.0
	var x: float = fposmod(start * span + _phase * float(dir), span) - 60.0
	var col: Color = RcTokens.state_color(state as RcTokens.State)
	var trail_to: float = x - float(dir) * 90.0
	draw_line(Vector2(x, y), Vector2(trail_to, y), RcTokens.with_alpha(col, 0.28), 3.0, true)
	var d: float = float(dir)
	draw_colored_polygon(PackedVector2Array([Vector2(x + d * 12.0, y), Vector2(x - d * 8.0, y - 9.0),
			Vector2(x - d * 3.0, y), Vector2(x - d * 8.0, y + 9.0)]), col)
	RcDraw.text_center(self, RcTokens.font_mono_medium(), code, Vector2(x - d * 8.0, y - 24.0), RcTokens.FS_DATA,
			RcTokens.with_alpha(RcTokens.TEXT_SECONDARY, 0.9))
