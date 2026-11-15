class_name RcAlertCard
extends PanelContainer
## Incidencia: barra lateral de prioridad, título, servicio, hora y acción «Gestionar».
## Entrada con deslizamiento + pulso único (`play_enter`).

signal manage_pressed

@export var title: String = "":
	set(value):
		title = value
		_refresh()
@export var detail: String = "":
	set(value):
		detail = value
		_refresh()
@export var time_text: String = "":
	set(value):
		time_text = value
		_refresh()
@export var chip_text: String = "AVERÍA":
	set(value):
		chip_text = value
		_refresh()
@export var severity: RcTokens.State = RcTokens.State.ALERT:
	set(value):
		severity = value
		_refresh()
@export var action_text: String = "Gestionar":
	set(value):
		action_text = value
		_refresh()

## Sin acción (incidencia ya decidida): se oculta el botón.
@export var show_action: bool = true:
	set(value):
		show_action = value
		_refresh()

var _chip: RcStatusChip
var _time_label: Label
var _title_label: Label
var _detail_label: Label
var _button: RcButton
var _overlay: _Overlay
var _tween: Tween


class _Overlay extends Control:
	var color: Color = RcTokens.STATE_ALERT
	var pulse: float = 1.0  # 0 → 1: anillo que se expande una sola vez

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var m: Vector4 = RcDraw.parent_margins(self)
		var full := Rect2(Vector2(-m.x, -m.y), size + Vector2(m.x + m.z, m.y + m.w))
		var bar: StyleBoxFlat = RcTokens.make_box(color, 2)
		draw_style_box(bar, Rect2(full.position + Vector2(0, 12), Vector2(4, maxf(full.size.y - 24.0, 0.0))))
		if pulse < 1.0:
			var grow: float = 10.0 * pulse
			var ring: StyleBoxFlat = RcTokens.make_box(Color(0, 0, 0, 0), RcTokens.RADIUS_CARD + int(grow),
					RcTokens.with_alpha(color, 0.7 * (1.0 - pulse)), 2)
			draw_style_box(ring, Rect2(full.position - Vector2(grow, grow), full.size + Vector2(grow, grow) * 2.0))


func _ready() -> void:
	theme_type_variation = &"PanelRaised"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	_chip = RcStatusChip.new()
	_chip.strong = true
	top.add_child(_chip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_time_label = Label.new()
	_time_label.theme_type_variation = &"LabelDataMuted"
	top.add_child(_time_label)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"LabelBodyStrong"
	col.add_child(_title_label)
	_detail_label = Label.new()
	_detail_label.theme_type_variation = &"LabelSecondary"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_label)
	_button = RcButton.new()
	_button.kind = RcButton.Kind.PRIMARY
	_button.pressed.connect(func() -> void: manage_pressed.emit())
	col.add_child(_button)
	_overlay = _Overlay.new()
	add_child(_overlay)
	_refresh()


func _refresh() -> void:
	if _chip == null:
		return
	_chip.text = chip_text
	_chip.state = severity
	_time_label.text = time_text
	_title_label.text = title
	_detail_label.text = detail
	_button.text = action_text
	_button.visible = show_action
	_overlay.color = RcTokens.state_color(severity)
	_overlay.queue_redraw()


func play_enter() -> void:
	await get_tree().process_frame
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var d: float = RcTokens.dur(RcTokens.DUR_PANEL)
	if d <= 0.0:
		return
	var rest_x: float = position.x
	position.x = rest_x - 28.0
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", rest_x, d)
	_tween.tween_property(self, "modulate:a", 1.0, d)
	_overlay.pulse = 0.0
	_tween.tween_method(_set_pulse, 0.0, 1.0, 0.7).set_delay(d)


func _set_pulse(value: float) -> void:
	_overlay.pulse = value
	_overlay.queue_redraw()
