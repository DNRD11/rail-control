class_name RcSegmentedControl
extends Control
## Selector segmentado (velocidad: pausa, x1, x2, x4). La opción activa se ilumina.
## La opción con texto «pause» se dibuja como icono de pausa.

signal selected_changed(index: int)

@export var options: PackedStringArray = PackedStringArray(["pause", "x1", "x2", "x4"]):
	set(value):
		options = value
		update_minimum_size()
		queue_redraw()
@export var selected: int = 1:
	set(value):
		_set_index(value, false)
	get:
		return _selected

const SEG_W := 48.0
const PAD := 4.0
const HEIGHT := 48.0

var _selected: int = 1
var _hl_x: float = PAD
var _flash: float = 0.0
var _tween: Tween
var _bg_box: StyleBoxFlat
var _hl_box: StyleBoxFlat


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bg_box = RcTokens.make_box(RcTokens.with_alpha(RcTokens.BG_BASE, 0.7), RcTokens.RADIUS_CARD, RcTokens.STROKE_SUBTLE, 1)
	_hl_box = RcTokens.make_box(RcTokens.with_alpha(RcTokens.ACCENT, 0.16), RcTokens.RADIUS_CHIP + 2,
			RcTokens.with_alpha(RcTokens.ACCENT, 0.8), 1)
	_hl_box.shadow_color = RcTokens.with_alpha(RcTokens.ACCENT, 0.28)
	_hl_box.shadow_size = 8


func _ready() -> void:
	_hl_x = _segment_x(_selected)


func _get_minimum_size() -> Vector2:
	return Vector2(options.size() * SEG_W + PAD * 2.0, HEIGHT)


func _segment_x(index: int) -> float:
	return PAD + index * SEG_W


func select(index: int) -> void:
	_set_index(index, true)


func _set_index(index: int, emit: bool) -> void:
	var clamped: int = clampi(index, 0, maxi(options.size() - 1, 0))
	var changed: bool = clamped != _selected
	_selected = clamped
	_apply_selected(clamped)
	if changed and emit:
		selected_changed.emit(clamped)


func _apply_selected(index: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target: float = _segment_x(index)
	var d: float = RcTokens.dur(RcTokens.DUR_STATE)
	if d <= 0.0 or not is_inside_tree():
		_hl_x = target
		queue_redraw()
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_hl_x, _hl_x, target, d)
	_flash = 1.0
	_tween.tween_method(_set_flash, 1.0, 0.0, RcTokens.dur(RcTokens.DUR_PRESS) * 2.0)


func _set_hl_x(value: float) -> void:
	_hl_x = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var index: int = int((mb.position.x - PAD) / SEG_W)
		select(index)
		accept_event()


func _draw() -> void:
	draw_style_box(_bg_box, Rect2(Vector2.ZERO, size))
	var seg_h: float = size.y - PAD * 2.0
	var hl_rect := Rect2(Vector2(_hl_x, PAD), Vector2(SEG_W, seg_h))
	_hl_box.bg_color = RcTokens.with_alpha(RcTokens.ACCENT, 0.16 + 0.18 * _flash)
	draw_style_box(_hl_box, hl_rect)
	for i: int in options.size():
		var active: bool = i == _selected
		var col: Color = RcTokens.ACCENT if active else RcTokens.TEXT_SECONDARY
		var center := Vector2(_segment_x(i) + SEG_W * 0.5, size.y * 0.5)
		if options[i] == "pause":
			RcDraw.pause(self, center, 16.0, col)
		else:
			RcDraw.text_center(self, RcTokens.font_mono_medium(), options[i], center, RcTokens.FS_DATA, col)
