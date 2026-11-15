class_name OpsFlowGlue
extends Node
## Pegamento entre la pantalla de Operación y el flujo de la aplicación (`AppFlow`): menú de pausa
## (reanudar, guardar, configuración, abandonar) y cierre de jornada hacia el informe.
## No toca el estado de la simulación salvo la velocidad (comando SetSpeed vía host).

var _host: SimulationHost
var _pause_menu: OpsPauseMenu
var _sheet: OpsDecisionSheet
var _toasts: RcToast
var _clock_text: Callable
var _resume_speed: int = 0
var _finished: bool = false


func setup(host: SimulationHost, pause_menu: OpsPauseMenu, sheet: OpsDecisionSheet, toasts: RcToast,
		clock_text: Callable) -> void:
	_host = host
	_pause_menu = pause_menu
	_sheet = sheet
	_toasts = toasts
	_clock_text = clock_text
	_pause_menu.resume_requested.connect(close_pause_menu)
	_pause_menu.save_requested.connect(_on_save_requested)
	_pause_menu.settings_requested.connect(func() -> void: AppFlow.go(AppFlow.SETTINGS))
	_pause_menu.abandon_confirmed.connect(_on_abandon_confirmed)
	_host.day_finished.connect(_on_day_finished)


func open_pause_menu() -> void:
	if _pause_menu.visible:
		return
	_resume_speed = _host.get_speed()
	_host.set_speed(0)
	_pause_menu.open(_clock_text.call() as String)


func close_pause_menu() -> void:
	_pause_menu.close()
	if _resume_speed > 0 and _host.get_speed() == 0 and not _sheet.visible:
		_host.set_speed(_resume_speed)


func _on_save_requested() -> void:
	if AppFlow.autosave():
		_toasts.show_toast("Partida guardada")
	else:
		_toasts.show_toast("No se pudo guardar la partida", RcTokens.State.ALERT)


func _on_abandon_confirmed() -> void:
	_pause_menu.close()
	AppFlow.abandon_day()


## Fin de jornada: pausa y pasa al informe (diferido, para no cerrar la sesión dentro de su propia señal).
func _on_day_finished() -> void:
	if _finished:
		return
	_finished = true
	_host.set_speed(0)
	AppFlow.finish_day.call_deferred()
