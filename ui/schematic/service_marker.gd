class_name ServiceMarker
extends Control
## Marcador de servicio: punta de flecha con sentido, código y chip de retraso.
## Selección = anillo de acento con pulso único; avería = halo rojo de pulso lento (1 pulso / 2 s).

signal tapped(code: String)

const BOX := Vector2(132.0, 88.0)
const CENTER := Vector2(66.0, 44.0)
const ARROW_LEN := 30.0
const ARROW_HALF := 12.0

var service: SchematicService
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _halo_t: float = 0.0
var _pulse_t: float = 1.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = BOX
	size = BOX
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_service: SchematicService) -> void:
	service = p_service
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return Rect2(CENTER - Vector2(44, 40), Vector2(88, 80)).has_point(point)


func _process(delta: float) -> void:
	if service == null:
		return
	if service.broken and not RcTokens.reduce_motion:
		_halo_t = fposmod(_halo_t + delta / RcTokens.DUR_PULSE_LOOP, 1.0)
		queue_redraw()


func play_select_pulse() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var d: float = RcTokens.dur(0.6)
	if d <= 0.0:
		return
	_pulse_t = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_pulse, 0.0, 1.0, d)


func _set_pulse(value: float) -> void:
	_pulse_t = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and service != null:
		tapped.emit(service.code)
		accept_event()


## Contorno de la punta de flecha (con muesca trasera) centrado en c.
static func arrow_points(c: Vector2, direction: int, scale_f: float = 1.0) -> PackedVector2Array:
	var d: float = float(direction)
	var l: float = ARROW_LEN * scale_f
	var h: float = ARROW_HALF * scale_f
	return PackedVector2Array([
		c + Vector2(d * l * 0.5, 0.0),
		c + Vector2(-d * l * 0.5, -h),
		c + Vector2(-d * l * 0.2, 0.0),
		c + Vector2(-d * l * 0.5, h)])


func _draw() -> void:
	if service == null:
		return
	var col: Color = RcTokens.state_color(service.state)
	var d: float = float(service.direction)

	# Estela: la vía recién recorrida se ilumina tenuemente tras el servicio.
	var trail := PackedVector2Array([CENTER + Vector2(-d * 96.0, 0), CENTER + Vector2(-d * 48.0, 0), CENTER + Vector2(-d * 10.0, 0)])
	var trail_cols := PackedColorArray([RcTokens.with_alpha(col, 0.0), RcTokens.with_alpha(col, 0.22), RcTokens.with_alpha(col, 0.5)])
	draw_polyline_colors(trail, trail_cols, 3.0)

	if service.broken:
		var r: float = 22.0 + 30.0 * _halo_t
		draw_circle(CENTER, r, RcTokens.with_alpha(col, 0.16 * (1.0 - _halo_t)))
		draw_arc(CENTER, r, 0.0, TAU, 48, RcTokens.with_alpha(col, 0.55 * (1.0 - _halo_t)), 2.0, true)
	if selected:
		draw_circle(CENTER, 26.0, RcTokens.with_alpha(RcTokens.ACCENT, 0.10))
		draw_arc(CENTER, 26.0, 0.0, TAU, 48, RcTokens.ACCENT, 2.0, true)
		if _pulse_t < 1.0:
			var pr: float = 26.0 + 22.0 * _pulse_t
			draw_arc(CENTER, pr, 0.0, TAU, 48, RcTokens.with_alpha(RcTokens.ACCENT, 0.8 * (1.0 - _pulse_t)), 2.0, true)

	# Punta de flecha: contorno oscuro para separarla de la vía + relleno semántico.
	var pts: PackedVector2Array = arrow_points(CENTER, service.direction)
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, col)
	draw_polyline(outline, RcTokens.BG_BASE, 2.0, true)

	# Código (con icono de aviso si hay avería).
	var code_font: Font = RcTokens.font_mono_medium()
	var code_w: float = RcDraw.text_width(code_font, service.code, RcTokens.FS_DATA)
	var icon_w: float = 18.0 if service.broken else 0.0
	var start_x: float = CENTER.x - (code_w + icon_w) * 0.5
	if service.broken:
		RcDraw.warning(self, Vector2(start_x + 7.0, CENTER.y - 30.0), 14.0, col)
	RcDraw.text_left(self, code_font, service.code, start_x + icon_w, CENTER.y - 30.0, RcTokens.FS_DATA, RcTokens.TEXT_PRIMARY)

	# Chip de retraso.
	var chip_font: Font = RcTokens.font_title()
	var label: String = service.chip_text()
	var chip_icon: float = 14.0
	var chip_w: float = RcDraw.text_width(chip_font, label, RcTokens.FS_SMALL) + chip_icon + 22.0
	var chip_rect := Rect2(Vector2(CENTER.x - chip_w * 0.5, CENTER.y + 22.0), Vector2(chip_w, 22.0))
	var box: StyleBoxFlat = RcTokens.make_box(RcTokens.with_alpha(col, 0.16), RcTokens.RADIUS_CHIP, RcTokens.with_alpha(col, 0.6), 1)
	draw_style_box(box, chip_rect)
	RcDraw.state_icon(self, service.state, Vector2(chip_rect.position.x + 11.0, chip_rect.get_center().y), chip_icon - 2.0, col)
	RcDraw.text_left(self, chip_font, label, chip_rect.position.x + 11.0 + chip_icon * 0.5 + 4.0, chip_rect.get_center().y, RcTokens.FS_SMALL, col)
