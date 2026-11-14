class_name RcDraw
extends RefCounted
## Utilidades de dibujo compartidas: iconos de trazo (2 px) y alineación de texto.
## No es un componente; lo usan los componentes y el esquema.


static func text_center(ci: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline: float = center.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	ci.draw_string(font, Vector2(center.x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto alineado a la izquierda en x, centrado verticalmente en cy. Devuelve el ancho.
static func text_left(ci: CanvasItem, font: Font, text: String, x: float, cy: float, size: int, color: Color) -> float:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline: float = cy + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	ci.draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return w


## Texto alineado a la derecha en x.
static func text_right(ci: CanvasItem, font: Font, text: String, x: float, cy: float, size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_left(ci, font, text, x - w, cy, size, color)


static func text_width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func warning(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		c + Vector2(0, -h), c + Vector2(h, h * 0.78), c + Vector2(-h, h * 0.78), c + Vector2(0, -h)])
	ci.draw_polyline(pts, col, 1.8, true)
	ci.draw_line(c + Vector2(0, -h * 0.22), c + Vector2(0, h * 0.2), col, 1.8, true)
	ci.draw_circle(c + Vector2(0, h * 0.5), 1.1, col)


static func check(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		c + Vector2(-h * 0.7, 0.0), c + Vector2(-h * 0.15, h * 0.55), c + Vector2(h * 0.75, -h * 0.5)])
	ci.draw_polyline(pts, col, 2.0, true)


static func clock(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var r: float = s * 0.5
	ci.draw_arc(c, r, 0.0, TAU, 24, col, 1.8, true)
	ci.draw_line(c, c + Vector2(0, -r * 0.6), col, 1.8, true)
	ci.draw_line(c, c + Vector2(r * 0.45, r * 0.2), col, 1.8, true)


static func ring(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s * 0.38, 0.0, TAU, 20, col, 1.8, true)


static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h: float = s * 0.45
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), col)


static func pause(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h: float = s * 0.5
	ci.draw_rect(Rect2(c + Vector2(-h * 0.62, -h * 0.8), Vector2(h * 0.48, h * 1.6)), col)
	ci.draw_rect(Rect2(c + Vector2(h * 0.14, -h * 0.8), Vector2(h * 0.48, h * 1.6)), col)


## Triángulo de tendencia (arriba o abajo).
static func trend(ci: CanvasItem, c: Vector2, s: float, up: bool, col: Color) -> void:
	var h: float = s * 0.5
	var dir: float = -1.0 if up else 1.0
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, dir * h * 0.9), c + Vector2(h, -dir * h * 0.7), c + Vector2(-h, -dir * h * 0.7)]), col)


static func chevron(ci: CanvasItem, c: Vector2, s: float, up: bool, col: Color) -> void:
	var h: float = s * 0.5
	var dir: float = -1.0 if up else 1.0
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-h, -dir * h * 0.35), c + Vector2(0, dir * h * 0.35), c + Vector2(h, -dir * h * 0.35)]), col, 2.0, true)


## Icono según estado semántico: el color nunca es el único canal.
static func state_icon(ci: CanvasItem, state: RcTokens.State, c: Vector2, s: float, col: Color) -> void:
	match state:
		RcTokens.State.OK:
			check(ci, c, s, col)
		RcTokens.State.WARN:
			clock(ci, c, s, col)
		RcTokens.State.ALERT:
			warning(ci, c, s, col)
		RcTokens.State.SPECIAL:
			diamond(ci, c, s, col)
		_:
			ring(ci, c, s, col)


## Márgenes de contenido (izq, arriba, der, abajo) del StyleBox «panel» del padre. Los hijos
## de un PanelContainer se encajan dentro de ellos; los overlays los compensan para dibujar
## sobre el borde real del panel.
static func parent_margins(ctrl: Control) -> Vector4:
	var parent := ctrl.get_parent() as Control
	if parent == null:
		return Vector4.ZERO
	var sb: StyleBox = parent.get_theme_stylebox(&"panel")
	if sb == null:
		return Vector4.ZERO
	return Vector4(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_BOTTOM))
