class_name ConsoleBackground
extends Control
## Fondo de la aplicación: bg_base + retícula de 32 px al 3 % + viñeta sutil.

var _vignette: GradientTexture2D
var _glow: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_vignette = _radial([0.5, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0.6)])
	_glow = _radial([0.0, 1.0], [RcTokens.with_alpha(RcTokens.ACCENT_DEEP, 0.10), Color(0, 0, 0, 0)])


func _radial(offsets: Array[float], colors: Array[Color]) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), RcTokens.BG_BASE)
	var grid := Color(1, 1, 1, 0.03)
	var x: float = 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
		x += 32.0
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
		y += 32.0
	if _glow != null:
		var glow_rect := Rect2(Vector2(size.x * 0.1, size.y * 0.05), Vector2(size.x * 0.8, size.y * 0.9))
		draw_texture_rect(_glow, glow_rect, false)
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
