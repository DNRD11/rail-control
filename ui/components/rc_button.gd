class_name RcButton
extends Button
## Botón táctil (≥ 48 px) con variantes primary / secondary / ghost / danger, icono SVG opcional
## (`icon_name` = archivo de assets/icons sin extensión) y tamaño grande (56 px) para menús.
## Feedback de pulsación: escala 0.97 + destello de 120 ms.

enum Kind { PRIMARY, SECONDARY, GHOST, DANGER }

const ICON_DIR := "res://assets/icons/"

@export var kind: Kind = Kind.SECONDARY:
	set(value):
		kind = value
		_apply_kind()
@export var icon_name: String = "":
	set(value):
		icon_name = value
		_apply_icon()
@export var large: bool = false:
	set(value):
		large = value
		_apply_size()
## Botón cuadrado de 48 px solo con icono (menú, volver).
@export var icon_only: bool = false:
	set(value):
		icon_only = value
		_apply_size()

var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0, RcTokens.TOUCH_MIN)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_apply_kind()
	_apply_icon()
	_apply_size()
	resized.connect(_update_pivot)
	_update_pivot()
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _apply_kind() -> void:
	match kind:
		Kind.PRIMARY:
			theme_type_variation = &"RcButtonPrimary"
		Kind.GHOST:
			theme_type_variation = &"RcButtonGhost"
		Kind.DANGER:
			theme_type_variation = &"RcButtonDanger"
		_:
			theme_type_variation = &""


func _apply_icon() -> void:
	if icon_name.is_empty():
		icon = null
		return
	icon = load(ICON_DIR + icon_name + ".svg") as Texture2D


func _apply_size() -> void:
	custom_minimum_size.y = RcTokens.BUTTON_LARGE_H if large else RcTokens.TOUCH_MIN
	if icon_only:
		custom_minimum_size.x = RcTokens.TOUCH_MIN
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_theme_constant_override("h_separation", 0)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _animate(target_scale: float, target_modulate: Color) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var d: float = RcTokens.dur(RcTokens.DUR_PRESS)
	if d <= 0.0:
		scale = Vector2(target_scale, target_scale)
		modulate = target_modulate
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), d)
	_tween.tween_property(self, "modulate", target_modulate, d)


func _on_down() -> void:
	_animate(0.97, Color(1.22, 1.22, 1.22, 1.0))


func _on_up() -> void:
	_animate(1.0, Color.WHITE)
