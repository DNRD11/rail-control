class_name OpsDecisionSheet
extends Control
## Hoja modal de gestión de incidencia sobre el esquema atenuado: qué ha pasado y tres
## RcDecisionCard comparables. Una pulsación en una tarjeta emite `chosen`. No conoce la
## simulación: recibe modelos de OpsIncidentPresenter (`show_model` / `refresh`).

signal chosen(incident_id: StringName, option_type: StringName)
signal dismissed
signal inform_requested(incident_id: StringName)

const MAX_WIDTH := 1136
const SIDE_MARGIN := 40

var incident_id: StringName = &""

var _sheet: PanelContainer
var _chip: RcStatusChip
var _title: Label
var _sub: Label
var _count_caption: Label
var _count_value: Label
var _bar: _Bar
var _cards_box: HBoxContainer
var _footer: Label
var _later: RcButton
var _inform: OpsInformBlock
var _cards: Dictionary[StringName, RcDecisionCard] = {}
var _tween: Tween


## Barra fina de tiempo restante hasta la decisión automática.
class _Bar extends Control:
	var fraction: float = 1.0
	var color: Color = RcTokens.ACCENT

	func _init() -> void:
		custom_minimum_size = Vector2(0, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(RcTokens.make_box(RcTokens.STROKE_SUBTLE, 3), Rect2(Vector2.ZERO, size))
		var w: float = size.x * clampf(fraction, 0.0, 1.0)
		if w > 1.0:
			draw_style_box(RcTokens.make_box(color, 3), Rect2(Vector2.ZERO, Vector2(w, size.y)))


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var veil := ColorRect.new()
	veil.color = RcTokens.with_alpha(RcTokens.BG_BASE, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = PanelContainer.new()
	_sheet.theme_type_variation = &"PanelSheet"
	center.add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", RcTokens.SP_3)
	_sheet.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", RcTokens.SP_3)
	col.add_child(head)
	_chip = RcStatusChip.new()
	_chip.strong = true
	_chip.text = "Avería"
	_chip.state = RcTokens.State.ALERT
	_chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_chip)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title = Label.new()
	_title.theme_type_variation = &"LabelHeading"
	titles.add_child(_title)
	_sub = Label.new()
	_sub.theme_type_variation = &"LabelSecondary"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_sub)
	var count := VBoxContainer.new()
	count.add_theme_constant_override("separation", 0)
	head.add_child(count)
	_count_caption = Label.new()
	_count_caption.theme_type_variation = &"LabelCaption"
	_count_caption.text = "DECISIÓN AUTOMÁTICA EN"
	_count_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_child(_count_caption)
	_count_value = Label.new()
	_count_value.theme_type_variation = &"LabelCode"
	_count_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_child(_count_value)

	_bar = _Bar.new()
	col.add_child(_bar)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", RcTokens.SP_3)
	col.add_child(_cards_box)

	_inform = OpsInformBlock.new()
	_inform.inline_button = true
	_inform.inform_pressed.connect(func() -> void: inform_requested.emit(incident_id))
	col.add_child(_inform)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", RcTokens.SP_3)
	col.add_child(foot)
	_later = RcButton.new()
	_later.kind = RcButton.Kind.GHOST
	_later.text = "Decidir más tarde"
	_later.pressed.connect(close)
	foot.add_child(_later)
	_footer = Label.new()
	_footer.theme_type_variation = &"LabelMuted"
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_footer)
	resized.connect(_fit_width)
	_fit_width()


func _fit_width() -> void:
	if _sheet != null:
		_sheet.custom_minimum_size.x = minf(float(MAX_WIDTH), size.x - SIDE_MARGIN * 2.0)


func is_open_for(id: StringName) -> bool:
	return visible and incident_id == id


func open(model: Dictionary) -> void:
	incident_id = model.get("id", &"")
	visible = true
	refresh(model)
	_fit_width()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var d: float = RcTokens.dur(RcTokens.DUR_PANEL)
	modulate.a = 1.0
	if d > 0.0:
		modulate.a = 0.0
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, d)


func close() -> void:
	if not visible:
		return
	visible = false
	incident_id = &""
	dismissed.emit()


## Actualiza datos en vivo (cuenta atrás y previsualizaciones) sin reconstruir la hoja.
func refresh(model: Dictionary) -> void:
	if model.is_empty():
		return
	_title.text = "%s · %s" % [model["title"], model["service"]]
	_sub.text = "%s · detectada a las %s · %s viajeros a bordo · reparación estimada %s" % [
			model["where"], model["when"], model["aboard"], model["repair"]]
	var left: int = int(model["seconds_left"])
	var total: int = maxi(int(model["total_s"]), 1)
	_count_value.text = RcFormat.mmss(left)
	var urgent: bool = left * 3 < total
	_count_value.add_theme_color_override("font_color", RcTokens.STATE_WARN if urgent else RcTokens.TEXT_PRIMARY)
	_bar.fraction = float(left) / float(total)
	_bar.color = RcTokens.STATE_WARN if urgent else RcTokens.ACCENT
	_bar.queue_redraw()
	_footer.text = "Sin decisión, a las %s se aplicará «%s»." % [model["deadline"], model["default_title"]]
	_sync_cards(model["cards"])
	_inform.set_model(model.get("inform", {}))


func _sync_cards(models: Array) -> void:
	for m: Dictionary in models:
		var type: StringName = m["option_type"]
		var card: RcDecisionCard = _cards.get(type)
		if card == null:
			card = RcDecisionCard.new()
			card.chosen.connect(func(option: StringName) -> void: chosen.emit(incident_id, option))
			_cards[type] = card
			_cards_box.add_child(card)
		card.set_model(m)
