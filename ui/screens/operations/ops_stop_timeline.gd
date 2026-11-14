class_name OpsStopTimeline
extends Control
## Paradas del servicio: horario programado frente a estimado. Cada fila:
## [código, programada, estimada, estado: done | next | pending].

const ROW_H := 24.0
const HEAD_H := 20.0
const DOT_X := 8.0

var stops: Array = []
var state: RcTokens.State = RcTokens.State.OK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stops(p_stops: Array, p_state: RcTokens.State) -> void:
	stops = p_stops
	state = p_state
	custom_minimum_size = Vector2(0, HEAD_H + ROW_H * stops.size())
	queue_redraw()


func _draw() -> void:
	if stops.is_empty():
		return
	var accent: Color = RcTokens.state_color(state)
	var right: float = size.x
	RcDraw.text_right(self, RcTokens.font_title(), "EST.", right, HEAD_H * 0.5, RcTokens.FS_SMALL, RcTokens.TEXT_MUTED)
	RcDraw.text_right(self, RcTokens.font_title(), "PROG.", right - 58.0, HEAD_H * 0.5, RcTokens.FS_SMALL, RcTokens.TEXT_MUTED)
	var first_y: float = HEAD_H + ROW_H * 0.5
	var last_y: float = HEAD_H + ROW_H * (stops.size() - 0.5)
	draw_line(Vector2(DOT_X, first_y), Vector2(DOT_X, last_y), RcTokens.STROKE_STRONG, 2.0)
	for i: int in stops.size():
		var row: Array = stops[i]
		var code: String = row[0]
		var sched: String = row[1]
		var est: String = row[2]
		var status: String = row[3]
		var cy: float = HEAD_H + ROW_H * (i + 0.5)
		var late: bool = est != sched
		match status:
			"done":
				draw_circle(Vector2(DOT_X, cy), 4.0, RcTokens.STATE_IDLE)
			"next":
				draw_circle(Vector2(DOT_X, cy), 7.0, RcTokens.with_alpha(accent, 0.2))
				draw_circle(Vector2(DOT_X, cy), 4.5, accent)
			_:
				draw_circle(Vector2(DOT_X, cy), 4.0, RcTokens.BG_PANEL)
				draw_arc(Vector2(DOT_X, cy), 4.0, 0.0, TAU, 16, RcTokens.TEXT_MUTED, 1.6, true)
		var name_col: Color = RcTokens.TEXT_PRIMARY if status != "pending" else RcTokens.TEXT_SECONDARY
		var w: float = RcDraw.text_left(self, RcTokens.font_station(), code, 26.0, cy, RcTokens.FS_DATA, name_col)
		RcDraw.text_left(self, RcTokens.font_text(), OperationsMockData.station_name(code), 26.0 + w + 8.0, cy, RcTokens.FS_SMALL, RcTokens.TEXT_MUTED)
		RcDraw.text_right(self, RcTokens.font_mono(), sched, right - 58.0, cy, RcTokens.FS_SMALL,
				RcTokens.TEXT_MUTED if late else RcTokens.TEXT_SECONDARY)
		var est_col: Color = accent if late else RcTokens.TEXT_PRIMARY
		RcDraw.text_right(self, RcTokens.font_mono_medium(), est, right, cy, RcTokens.FS_SMALL + 1, est_col)
