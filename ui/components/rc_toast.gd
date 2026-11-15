class_name RcToast
extends Control
## Notificaciones breves apiladas arriba a la derecha. No bloquean la entrada ni afectan a la
## simulación: aparecen en 180 ms, se mantienen ~2,6 s y se desvanecen en 240 ms.

const HOLD_S := 2.6
const MAX_VISIBLE := 3

var _stack: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60


func _ready() -> void:
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", RcTokens.SP_2)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.offset_top = RcTokens.TOPBAR_H + RcTokens.MARGIN_SCREEN * 2
	_stack.offset_right = -RcTokens.MARGIN_SCREEN
	add_child(_stack)


func show_toast(text: String, state: RcTokens.State = RcTokens.State.OK) -> void:
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest: Node = _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelSheet"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", RcTokens.SP_3)
	card.add_child(line)
	var chip := RcStatusChip.new()
	chip.state = state
	chip.text = _kind_text(state)
	line.add_child(chip)
	var label := Label.new()
	label.theme_type_variation = &"LabelBody"
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	_stack.add_child(card)
	var d_in: float = RcTokens.dur(RcTokens.DUR_STATE)
	var d_out: float = RcTokens.dur(RcTokens.DUR_PANEL)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	if d_in > 0.0:
		card.modulate.a = 0.0
		tween.tween_property(card, "modulate:a", 1.0, d_in).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_S)
	if d_out > 0.0:
		tween.tween_property(card, "modulate:a", 0.0, d_out).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(card):
			card.queue_free())


func _kind_text(state: RcTokens.State) -> String:
	match state:
		RcTokens.State.WARN:
			return "Aviso"
		RcTokens.State.ALERT:
			return "Error"
		RcTokens.State.SPECIAL:
			return "Info"
	return "Hecho"
