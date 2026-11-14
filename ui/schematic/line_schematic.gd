class_name LineSchematic
extends Control
## Esquema ferroviario MAD–BCN dibujado con _draw(): dos vías, estaciones como cápsulas,
## regla kilométrica, leyenda, «sombra programada» y cadena de rotación del servicio
## seleccionado. Los marcadores son nodos ServiceMarker (uno por servicio).

signal service_selected(code: String)

const PAD_X := 56.0
const MIN_GAP := 64.0
const CAP_W := 12.0
const NAME_FONT := 13

var _stations: Array[SchematicStation] = []
var _services: Array[SchematicService] = []
var _markers: Dictionary[String, ServiceMarker] = {}
var _station_x: PackedFloat32Array = PackedFloat32Array()
var _selected_code: String = ""
var _eta: Dictionary[String, Array] = {}


func set_data(stations: Array[SchematicStation], services: Array[SchematicService]) -> void:
	_stations = stations
	_services = services
	for marker: ServiceMarker in _markers.values():
		marker.queue_free()
	_markers.clear()
	for service: SchematicService in _services:
		var marker := ServiceMarker.new()
		marker.setup(service)
		marker.tapped.connect(_on_marker_tapped)
		add_child(marker)
		_markers[service.code] = marker
	_relayout()


func set_eta(station_code: String, text: String, state: RcTokens.State) -> void:
	_eta.clear()
	if not station_code.is_empty():
		_eta[station_code] = [text, state]
	queue_redraw()


func select_service(code: String, pulse: bool = true) -> void:
	_selected_code = code
	var d: float = RcTokens.dur(RcTokens.DUR_PANEL)
	for key: String in _markers:
		var marker: ServiceMarker = _markers[key]
		var is_sel: bool = key == code
		marker.selected = is_sel
		var target: float = 1.0 if (is_sel or code.is_empty()) else 0.7
		if d > 0.0:
			create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(marker, "modulate:a", target, d)
		else:
			marker.modulate.a = target
		if is_sel:
			move_child(marker, get_child_count() - 1)
			if pulse:
				marker.play_select_pulse()
	queue_redraw()


func _on_marker_tapped(code: String) -> void:
	select_service(code)
	service_selected.emit(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _process(_delta: float) -> void:
	_place_markers()
	queue_redraw()


# --- Geometría -------------------------------------------------------------

func _relayout() -> void:
	if _stations.is_empty():
		return
	var usable: float = maxf(size.x - PAD_X * 2.0, 100.0)
	var gaps: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(1, _stations.size()):
		gaps.append(_stations[i].km - _stations[i - 1].km)
	# Escala px/km tal que la suma de max(km·s, MIN_GAP) llene el ancho útil
	# (compresión mínima: GUA no queda pegada a MAD).
	var lo: float = 0.0
	var hi: float = 20.0
	for _i: int in 40:
		var mid: float = (lo + hi) * 0.5
		var total: float = 0.0
		for g: float in gaps:
			total += maxf(g * mid, MIN_GAP)
		if total > usable:
			hi = mid
		else:
			lo = mid
	_station_x = PackedFloat32Array([PAD_X])
	for g: float in gaps:
		_station_x.append(_station_x[_station_x.size() - 1] + maxf(g * lo, MIN_GAP))
	# Centrar si sobra espacio.
	var extra: float = (usable - (_station_x[_station_x.size() - 1] - PAD_X)) * 0.5
	for i: int in _station_x.size():
		_station_x[i] += extra
	_place_markers()
	queue_redraw()


func km_to_x(km: float) -> float:
	if _stations.is_empty():
		return 0.0
	if km <= _stations[0].km:
		return _station_x[0]
	for i: int in range(1, _stations.size()):
		if km <= _stations[i].km:
			var t: float = (km - _stations[i - 1].km) / (_stations[i].km - _stations[i - 1].km)
			return lerpf(_station_x[i - 1], _station_x[i], t)
	return _station_x[_station_x.size() - 1]


func _ruler_y() -> float:
	return size.y - 58.0


## Bloque de vías centrado entre la cabecera de estaciones y la regla kilométrica.
func _block() -> Dictionary:
	var top: float = 92.0
	var bottom: float = _ruler_y() - 22.0
	var mid: float = (top + bottom) * 0.5
	var gap: float = clampf((bottom - top) - 100.0, 120.0, 190.0)
	return {"upper": mid - gap * 0.5, "lower": mid + gap * 0.5}


func _cap_top() -> float:
	return float(_block()["upper"]) - 46.0


func _cap_bottom() -> float:
	return float(_block()["lower"]) + 46.0


func _track_y(direction: int) -> float:
	return float(_block()["lower"] if direction > 0 else _block()["upper"])


func _place_markers() -> void:
	for service: SchematicService in _services:
		var marker: ServiceMarker = _markers.get(service.code)
		if marker == null:
			continue
		marker.position = Vector2(km_to_x(service.km), _track_y(service.direction)) - ServiceMarker.CENTER


# --- Dibujo ----------------------------------------------------------------

func _draw() -> void:
	if _stations.is_empty():
		return
	_draw_tracks()
	_draw_stations()
	_draw_ruler_and_legend()
	for service: SchematicService in _services:
		_draw_schedule_shadow(service)
	_draw_chain()


func _draw_tracks() -> void:
	var x0: float = _station_x[0] - 22.0
	var x1: float = _station_x[_station_x.size() - 1] + 22.0
	for direction: int in [-1, 1]:
		var y: float = _track_y(direction)
		draw_line(Vector2(x0, y), Vector2(x1, y), RcTokens.STROKE_STRONG, 3.0, true)
		draw_line(Vector2(x0, y + 5.0), Vector2(x1, y + 5.0), RcTokens.with_alpha(RcTokens.STROKE_SUBTLE, 0.8), 1.0)
	# Etiquetas de sentido en el extremo de destino de cada vía.
	var up_y: float = _track_y(-1)
	var dn_y: float = _track_y(1)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 - 6.0, up_y), Vector2(x0 + 4.0, up_y - 6.0), Vector2(x0 + 4.0, up_y + 6.0)]), RcTokens.TEXT_SECONDARY)
	RcDraw.text_left(self, RcTokens.font_title(), "MAD", 6.0, up_y - 20.0, NAME_FONT, RcTokens.TEXT_MUTED)
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 6.0, dn_y), Vector2(x1 - 4.0, dn_y - 6.0), Vector2(x1 - 4.0, dn_y + 6.0)]), RcTokens.TEXT_SECONDARY)
	RcDraw.text_right(self, RcTokens.font_title(), "BCN", size.x - 6.0, dn_y - 20.0, NAME_FONT, RcTokens.TEXT_MUTED)


func _draw_stations() -> void:
	var top: float = _cap_top()
	var bottom: float = _cap_bottom()
	for i: int in _stations.size():
		var st: SchematicStation = _stations[i]
		var x: float = _station_x[i]
		var is_end: bool = i == 0 or i == _stations.size() - 1
		var capsule: StyleBoxFlat = RcTokens.make_box(RcTokens.BG_RAISED, int(CAP_W * 0.5),
				RcTokens.with_alpha(RcTokens.TEXT_SECONDARY, 0.55) if is_end else RcTokens.STROKE_STRONG, 2)
		draw_style_box(capsule, Rect2(Vector2(x - CAP_W * 0.5, top), Vector2(CAP_W, bottom - top)))
		for direction: int in [-1, 1]:
			draw_circle(Vector2(x, _track_y(direction)), 3.5, RcTokens.TEXT_SECONDARY)
		RcDraw.text_center(self, RcTokens.font_station(), st.code, Vector2(x, top - 62.0), RcTokens.FS_STATION + 2, RcTokens.TEXT_PRIMARY)
		RcDraw.text_center(self, RcTokens.font_text(), st.short_name, Vector2(x, top - 43.0), NAME_FONT, RcTokens.TEXT_SECONDARY)
		if _eta.has(st.code):
			var eta: Array = _eta[st.code]
			var text: String = eta[0]
			var col: Color = RcTokens.state_color(eta[1])
			var w: float = RcDraw.text_width(RcTokens.font_mono_medium(), text, NAME_FONT) + 16.0
			var rect := Rect2(Vector2(x - w * 0.5, top - 30.0), Vector2(w, 22.0))
			draw_style_box(RcTokens.make_box(RcTokens.with_alpha(col, 0.14), RcTokens.RADIUS_CHIP, RcTokens.with_alpha(col, 0.6), 1), rect)
			RcDraw.text_center(self, RcTokens.font_mono_medium(), text, rect.get_center(), NAME_FONT, col)


func _draw_ruler_and_legend() -> void:
	var y: float = _ruler_y()
	var x0: float = km_to_x(0.0)
	var x1: float = km_to_x(_stations[_stations.size() - 1].km)
	draw_line(Vector2(x0, y), Vector2(x1, y), RcTokens.STROKE_STRONG, 1.0)
	var last_km: int = int(_stations[_stations.size() - 1].km)
	for km: int in range(0, last_km + 1, 50):
		var x: float = km_to_x(float(km))
		var tall: bool = km % 100 == 0
		draw_line(Vector2(x, y), Vector2(x, y + (7.0 if tall else 4.0)), RcTokens.STROKE_STRONG, 1.0)
	for km: int in [0, 300, last_km]:
		RcDraw.text_center(self, RcTokens.font_mono(), "%d km" % km, Vector2(km_to_x(float(km)), y + 19.0), NAME_FONT, RcTokens.TEXT_MUTED)
	# Leyenda.
	var ly: float = size.y - 14.0
	var x: float = x0 - CAP_W * 0.5
	var entries: Array[Array] = [
		[RcTokens.State.OK, "En hora"], [RcTokens.State.WARN, "Retraso leve"],
		[RcTokens.State.ALERT, "Incidencia"], [RcTokens.State.IDLE, "Horario programado"]]
	for entry: Array in entries:
		var st: RcTokens.State = entry[0]
		var label: String = entry[1]
		var col: Color = RcTokens.state_color(st)
		var c := Vector2(x + 8.0, ly)
		if st == RcTokens.State.IDLE:
			_dashed_poly(ServiceMarker.arrow_points(c, 1, 0.55), col, 1.2)
		else:
			draw_colored_polygon(ServiceMarker.arrow_points(c, 1, 0.55), col)
		x += 22.0
		x += RcDraw.text_left(self, RcTokens.font_text(), label, x, ly, NAME_FONT, RcTokens.TEXT_SECONDARY) + 18.0


func _dashed_poly(pts: PackedVector2Array, col: Color, width: float) -> void:
	for i: int in pts.size():
		draw_dashed_line(pts[i], pts[(i + 1) % pts.size()], col, width, 3.0, true)


## «Sombra programada»: fantasma discontinuo donde debería estar el servicio según
## horario, unido al real por un segmento semántico. El retraso se ve como distancia.
func _draw_schedule_shadow(service: SchematicService) -> void:
	if service.delay_min <= 0:
		return
	var marker: ServiceMarker = _markers.get(service.code)
	var alpha: float = marker.modulate.a if marker != null else 1.0
	var col: Color = RcTokens.state_color(service.state)
	var y: float = _track_y(service.direction)
	var xr: float = km_to_x(service.km)
	var xg: float = km_to_x(service.scheduled_km)
	draw_line(Vector2(xr, y), Vector2(xg, y), RcTokens.with_alpha(col, 0.7 * alpha), 5.0, true)
	var ghost: PackedVector2Array = ServiceMarker.arrow_points(Vector2(xg, y), service.direction)
	draw_colored_polygon(ghost, RcTokens.with_alpha(col, 0.07 * alpha))
	_dashed_poly(ghost, RcTokens.with_alpha(col, 0.95 * alpha), 1.6)


## Cadena de rotación del servicio seleccionado (siguiente servicio con el mismo material).
func _draw_chain() -> void:
	for service: SchematicService in _services:
		if service.code != _selected_code or service.chain_km < 0.0:
			continue
		var y: float = _track_y(service.direction)
		var cx: float = km_to_x(service.chain_km)
		var from_y: float = y + 8.0
		var to_y: float = _cap_bottom() + 6.0
		draw_dashed_line(Vector2(cx, from_y), Vector2(cx, to_y), RcTokens.with_alpha(RcTokens.ACCENT, 0.85), 2.0, 2.0)
		var w: float = RcDraw.text_width(RcTokens.font_mono_medium(), service.chain_label, NAME_FONT) + 16.0
		var rect := Rect2(Vector2(cx - w * 0.5, to_y), Vector2(w, 24.0))
		draw_style_box(RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.12), RcTokens.RADIUS_CHIP,
				RcTokens.with_alpha(RcTokens.ACCENT, 0.7), 1), rect)
		RcDraw.text_center(self, RcTokens.font_mono_medium(), service.chain_label, rect.get_center(), NAME_FONT, RcTokens.ACCENT)
