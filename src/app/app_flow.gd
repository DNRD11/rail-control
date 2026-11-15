extends Node
## Autoload `AppFlow`: navegación entre pantallas y paso de contexto (escenario, sesión, informe).
## No contiene lógica de juego. Sin `class_name` a propósito (chocaría con el nombre del autoload).

signal screen_changed(screen: StringName)

const MAIN_MENU: StringName = &"MAIN_MENU"
const SCENARIO_SELECT: StringName = &"SCENARIO_SELECT"
const BRIEFING: StringName = &"BRIEFING"
const OPERATIONS: StringName = &"OPERATIONS"
const REPORT: StringName = &"REPORT"
const SETTINGS: StringName = &"SETTINGS"

## Pantalla -> carpeta/nombre de la escena `res://ui/screens/<n>/<n>_screen.tscn`.
const SCREEN_FOLDERS: Dictionary[StringName, String] = {
	MAIN_MENU: "menu",
	SCENARIO_SELECT: "scenario_select",
	BRIEFING: "briefing",
	OPERATIONS: "operations",
	REPORT: "report",
	SETTINGS: "settings",
}

## Carpeta del escenario elegido bajo data/scenarios.
var selected_scenario: String = "mvp_mad_bcn_morning"
var host: SimulationHost
var last_report: DayReport = null
var settings: Settings
var current_screen: StringName = &""
## Escenario de la jornada en curso (para guardar y para el informe).
var active_scenario: String = ""


func _init() -> void:
	settings = Settings.load_from()
	host = SimulationHost.new()
	host.name = "SimulationHost"


func _ready() -> void:
	add_child(host)


static func scene_path(screen: StringName) -> String:
	var folder: String = SCREEN_FOLDERS.get(screen, "")
	return "" if folder == "" else "res://ui/screens/%s/%s_screen.tscn" % [folder, folder]


## Cambia de pantalla. Si la escena aún no existe avisa y no hace nada.
func go(screen: StringName) -> void:
	var path: String = scene_path(screen)
	if path == "":
		push_warning("AppFlow: pantalla desconocida «%s»" % screen)
		return
	if not ResourceLoader.exists(path):
		push_warning("AppFlow: la escena «%s» todavía no existe" % path)
		return
	if not is_inside_tree():
		push_warning("AppFlow: aún no está en el árbol; no se puede cambiar a «%s»" % screen)
		return
	current_screen = screen
	get_tree().change_scene_to_file(path)
	screen_changed.emit(screen)


## Carga y valida `selected_scenario`, crea la sesión y la deja en `host`. No cambia de pantalla.
func start_new_day() -> bool:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(selected_scenario)
	if not res.ok:
		push_error("AppFlow: el escenario «%s» no es válido; no se inicia la jornada" % selected_scenario)
		return false
	host.start(SimulationSession.create(res.world))
	host.pause()  # la jornada empieza en pausa: la UI la reanuda
	active_scenario = selected_scenario
	last_report = null
	return true


func has_saved_game() -> bool:
	return SaveGame.exists()


## Restaura el autoguardado en `host`. False (con error registrado) si falla.
func continue_saved() -> bool:
	var head: Dictionary = SaveGame.peek()
	if head.is_empty():
		return false
	var session: SimulationSession = SaveGame.load()
	if session == null:
		return false
	selected_scenario = String(head["scenario_id"])
	active_scenario = selected_scenario
	last_report = null
	host.start(session)
	host.pause()
	return true


## Guarda la jornada en curso en el slot de autoguardado.
func autosave() -> bool:
	if host.session == null or active_scenario == "":
		return false
	return SaveGame.save(host.session, active_scenario)


## Construye el informe de la jornada, cierra la sesión activa y va a REPORT.
func finish_day() -> void:
	if host.session == null:
		push_warning("AppFlow.finish_day sin jornada activa")
		return
	last_report = DayReport.from_session(host.session, null, active_scenario)
	host.stop()
	SaveGame.delete()
	go(REPORT)


## Descarta la jornada sin informe y vuelve al menú.
func abandon_day() -> void:
	host.stop()
	last_report = null
	active_scenario = ""
	go(MAIN_MENU)
