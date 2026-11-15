class_name RcScreenFrame
extends Control
## Marco común de las pantallas de aplicación (menú, selección, briefing, informe, ajustes):
## fondo de consola, cabecera (marca + kicker + título + botón volver opcional), cuerpo y pie.
## Cada pantalla hereda y rellena `body` / `footer` / `header_right` en `_build()`.

signal back_pressed

@export var kicker: String = "Centro de gestión de operaciones"
@export var screen_title: String = ""
@export var show_back: bool = false
@export var show_header: bool = true

var body: VBoxContainer
var footer: HBoxContainer
var header_right: HBoxContainer

var _margin: MarginContainer
var _root: VBoxContainer
var _header: RcPanel
var _title_label: Label
var _kicker_label: Label
var _toasts: RcToast


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiSettings.apply_all()
	add_child(ConsoleBackground.new())
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, RcTokens.MARGIN_SCREEN)
	add_child(_margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_margin.add_child(_root)
	_build_header()
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_root.add_child(body)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", RcTokens.SP_3)
	_root.add_child(footer)
	_toasts = RcToast.new()
	add_child(_toasts)
	_build()
	footer.visible = footer.get_child_count() > 0


## Las pantallas heredadas construyen aquí su contenido.
func _build() -> void:
	pass


func set_title(text: String, sub: String = "") -> void:
	_title_label.text = text
	_kicker_label.text = (sub if not sub.is_empty() else kicker).to_upper()


func toast(text: String, state: RcTokens.State = RcTokens.State.OK) -> void:
	_toasts.show_toast(text, state)


func _build_header() -> void:
	_header = RcPanel.new()
	_header.show_header = false
	_header.compact = true
	_header.content_horizontal = true
	_header.content_separation = RcTokens.SP_3
	_header.custom_minimum_size.y = RcTokens.TOPBAR_H
	_header.visible = show_header
	_root.add_child(_header)
	var c: BoxContainer = _header.content
	if show_back:
		var back := RcButton.new()
		back.icon_name = "arrow-left"
		back.icon_only = true
		back.kind = RcButton.Kind.GHOST
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func() -> void: back_pressed.emit())
		c.add_child(back)
	var mark := BrandMark.new()
	c.add_child(mark)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(titles)
	_kicker_label = Label.new()
	_kicker_label.theme_type_variation = &"LabelKicker"
	titles.add_child(_kicker_label)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"LabelHeading"
	titles.add_child(_title_label)
	header_right = HBoxContainer.new()
	header_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(header_right)
	set_title(screen_title)
