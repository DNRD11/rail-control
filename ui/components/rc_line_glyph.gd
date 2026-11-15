class_name RcLineGlyph
extends Control
## Esquema mínimo de una línea: vía con estaciones a escala por km y su código. Decorativo
## (briefing y ficha de escenario). Datos: [{code: String, km: float}] ordenados por km.

var stations: Array[Dictionary] = []:
	set(value):
		stations = value
		queue_redraw()

const PAD := 28.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 80)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if stations.size() < 2:
		return
	var y: float = size.y * 0.42
	var last_km: float = maxf(float(stations[stations.size() - 1]["km"]), 1.0)
	var w: float = size.x - PAD * 2.0
	draw_line(Vector2(PAD, y), Vector2(PAD + w, y), RcTokens.STROKE_STRONG, 3.0, true)
	var prev_right: float = -1000.0
	for st: Dictionary in stations:
		var x: float = PAD + w * float(st["km"]) / last_km
		draw_style_box(RcTokens.make_box(RcTokens.BG_PANEL, 6, RcTokens.STROKE_STRONG, 1),
				Rect2(x - 5.0, y - 15.0, 10.0, 30.0))
		draw_circle(Vector2(x, y), 3.0, RcTokens.ACCENT)
		var code: String = String(st["code"])
		var tw: float = RcDraw.text_width(RcTokens.font_station(), code, RcTokens.FS_STATION)
		if x - tw * 0.5 > prev_right + 6.0:
			RcDraw.text_center(self, RcTokens.font_station(), code, Vector2(x, y + 32.0), RcTokens.FS_STATION,
					RcTokens.TEXT_SECONDARY)
			prev_right = x + tw * 0.5
