class_name BrandMark
extends Control
## Marca del CGO: dos vías y un punto de servicio en un módulo redondeado.


func _init() -> void:
	custom_minimum_size = Vector2(36, 36)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box: StyleBoxFlat = RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.12), 10, RcTokens.with_alpha(RcTokens.ACCENT, 0.7), 1)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var c: Vector2 = size * 0.5
	draw_line(c + Vector2(-10, -5), c + Vector2(10, -5), RcTokens.with_alpha(RcTokens.ACCENT, 0.55), 2.0, true)
	draw_line(c + Vector2(-10, 5), c + Vector2(10, 5), RcTokens.ACCENT, 2.0, true)
	draw_circle(c + Vector2(4, 5), 3.2, RcTokens.ACCENT)
