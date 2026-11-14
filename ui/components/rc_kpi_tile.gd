class_name RcKpiTile
extends PanelContainer
## Indicador: etiqueta, valor grande, tendencia (▲▼) y micrográfico de la jornada.

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var value_text: String = "":
	set(value):
		value_text = value
		_refresh()
@export var suffix: String = "":
	set(value):
		suffix = value
		_refresh()
@export var trend_up: bool = true:
	set(value):
		trend_up = value
		_refresh()
## Estado semántico de la tendencia (verde = mejora, ámbar = empeora).
@export var trend_state: RcTokens.State = RcTokens.State.OK:
	set(value):
		trend_state = value
		_refresh()
@export var history: PackedFloat32Array = PackedFloat32Array():
	set(value):
		history = value
		_refresh()

## Sin datos todavía: oculta tendencia y micrográfico y atenúa el valor.
@export var no_data: bool = false:
	set(value):
		no_data = value
		_refresh()

var _caption_label: Label
var _value_label: Label
var _suffix_label: Label
var _trend: _Trend
var _spark: _Spark


class _Trend extends Control:
	var up: bool = true
	var color: Color = RcTokens.STATE_OK

	func _init() -> void:
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		RcDraw.trend(self, size * 0.5, 10.0, up, color)


class _Spark extends Control:
	var values: PackedFloat32Array = PackedFloat32Array()
	var color: Color = RcTokens.STATE_OK

	func _init() -> void:
		custom_minimum_size = Vector2(36, 24)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if values.size() < 2:
			return
		var lo: float = values[0]
		var hi: float = values[0]
		for v: float in values:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var span: float = maxf(hi - lo, 0.0001)
		var pts := PackedVector2Array()
		for i: int in values.size():
			var x: float = 2.0 + (size.x - 4.0) * float(i) / float(values.size() - 1)
			var y: float = size.y - 3.0 - (size.y - 6.0) * (values[i] - lo) / span
			pts.append(Vector2(x, y))
		draw_polyline(pts, RcTokens.with_alpha(color, 0.75), 1.6, true)
		draw_circle(pts[pts.size() - 1], 2.4, color)


func _ready() -> void:
	theme_type_variation = &"PanelTile"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", RcTokens.SP_3)
	add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_caption_label = Label.new()
	_caption_label.theme_type_variation = &"LabelCaption"
	col.add_child(_caption_label)
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", RcTokens.SP_1)
	col.add_child(value_row)
	_value_label = Label.new()
	_value_label.add_theme_font_override("font", RcTokens.font_mono_medium())
	_value_label.add_theme_font_size_override("font_size", 22)
	value_row.add_child(_value_label)
	_suffix_label = Label.new()
	_suffix_label.theme_type_variation = &"LabelDataMuted"
	_suffix_label.size_flags_vertical = Control.SIZE_SHRINK_END
	value_row.add_child(_suffix_label)
	_trend = _Trend.new()
	value_row.add_child(_trend)
	_spark = _Spark.new()
	row.add_child(_spark)
	_refresh()


func _refresh() -> void:
	if _caption_label == null:
		return
	_caption_label.text = caption.to_upper()
	_value_label.text = value_text
	_suffix_label.text = suffix
	_suffix_label.visible = not suffix.is_empty()
	var col: Color = RcTokens.state_color(trend_state)
	_trend.up = trend_up
	_trend.color = col
	_trend.queue_redraw()
	_spark.values = history
	_spark.color = col
	_spark.visible = history.size() >= 2 and not no_data
	_trend.visible = not no_data
	_value_label.add_theme_color_override("font_color", RcTokens.TEXT_MUTED if no_data else RcTokens.TEXT_PRIMARY)
	_spark.queue_redraw()
