class_name OpsInformBlock
extends VBoxContainer
## Bloque «Información al viajero»: chip de estado (SIN INFORMAR / INFORMADOS), texto y botón
## «Informar a los viajeros». Se usa en el detalle de servicio y en la hoja de decisión.
## Modelo: OpsIncidentPresenter.inform_model(). Solo emite `inform_pressed`; no toca la simulación.

signal inform_pressed

## En la hoja de decisión (ancha) el botón va en la misma línea que el estado.
var inline_button: bool = false
var _chip: RcStatusChip
var _text: Label
var _button: RcButton
var _signature: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", RcTokens.SP_2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", RcTokens.SP_2)
	add_child(head)
	_chip = RcStatusChip.new()
	head.add_child(_chip)
	_text = Label.new()
	_text.theme_type_variation = &"LabelSecondary"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_text)
	_button = RcButton.new()
	_button.text = "Informar a los viajeros"
	_button.icon_name = "megaphone"
	_button.pressed.connect(func() -> void: inform_pressed.emit())
	if inline_button:
		head.add_child(_button)
	else:
		add_child(_button)
	visible = false


func set_model(model: Dictionary) -> void:
	var signature: String = str(model)
	if signature == _signature:
		return
	_signature = signature
	visible = bool(model.get("visible", false))
	var informed: bool = bool(model.get("informed", false))
	_chip.text = "Informados" if informed else "Sin informar"
	_chip.state = RcTokens.State.OK if informed else RcTokens.State.WARN
	_text.text = String(model.get("text", ""))
	_button.visible = not informed and bool(model.get("available", false))
