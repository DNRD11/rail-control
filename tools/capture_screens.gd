extends SceneTree
## Captura todas las pantallas (Fase 7) en las resoluciones de revisión visual. Requiere ventana (no headless):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tools/capture_screens.gd [-- only=<prefijo>]
## Pantallas: menú, selección de escenario, briefing, configuración, informe (jornadas REALES simuladas hasta
## el final con DayReport.from_session) y Operación (en curso, avería con hoja de decisión, viajeros
## informados, menú de pausa). `only=` filtra por prefijos de etapa separados por comas (p. ej. only=2,3,5).
## Salida: docs/captures/phase7/<ancho>x<alto>_<etapa>.png
## `AppFlow` es un autoload: en un script `-s` no existe al compilar, se obtiene del árbol (`_app`).

const OUT_DIR := "res://docs/captures/phase7"
const SCREENS := "res://ui/screens/%s/%s_screen.tscn"
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1600, 720)]
const SETTLE := 1.4
## Informes reales: etapa -> decisión del jugador ante la avería (&"" = sin decidir, expira por tiempo).
const REPORT_RUNS: Dictionary[String, StringName] = {
	"5_report_sustituir": OptionType.SUBSTITUTE_ROLLING_STOCK,
	"5_report_cancelar": OptionType.CANCEL_SERVICE,
	"5_report_sin_decidir": &"",
}

var _app: Node
var _screen: Node
var _only: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_app = root.get_node("AppFlow")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_only = arg.substr(5)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	OpsIncidentsView.hide_debug = true

	for name: String in ["menu", "scenario_select", "briefing", "settings"]:
		await _open(SCREENS % [name, name])
		await _shoot_all("%s_%s" % [_index(name), name])
	for stage: String in REPORT_RUNS:
		if _wants(stage):
			_app.last_report = _play_full_day(REPORT_RUNS[stage])
			print("%s: nota %s, puntuación %.1f" % [stage, _app.last_report.grade, _app.last_report.score])
			await _open(SCREENS % ["report", "report"])
			await _shoot_all(stage)
	_app.last_report = null

	if not _app.start_new_day():
		push_error("No se pudo iniciar la jornada para capturar Operación")
		quit(1)
		return
	await _open("res://ui/screens/operations/operations_screen.tscn")
	_screen._overlay.visible = false
	_advance_to(SimTime.parse("07:30"))
	await create_timer(0.5).timeout
	await _shoot_all("6_ops_en_curso")
	_advance_to(SimTime.parse("08:12") + 90)
	await create_timer(0.4).timeout
	await _shoot_all("7_ops_averia_decision")
	_screen.decide(&"inc_001", OptionType.WAIT_REPAIR)
	_advance_to(_screen.host.session.clock.now + 10 * 60)
	_screen.inform_passengers("3103")
	await create_timer(0.4).timeout
	await _shoot_all("8_ops_informados")
	_screen.glue.open_pause_menu()
	await create_timer(0.3).timeout
	await _shoot_all("9_ops_pausa")
	quit()


func _index(name: String) -> String:
	return str(["menu", "scenario_select", "briefing", "settings"].find(name) + 1)


func _wants(stage: String) -> bool:
	if _only.is_empty():
		return true
	for prefix: String in _only.split(","):
		if stage.begins_with(prefix):
			return true
	return false


func _open(path: String) -> void:
	if _screen != null:
		_screen.queue_free()
		await process_frame
	_screen = (load(path) as PackedScene).instantiate()
	root.add_child(_screen)
	await create_timer(0.4).timeout


## Simula una jornada completa de verdad (sin pasar por la UI) y devuelve su informe.
func _play_full_day(decision: StringName) -> DayReport:
	_app.start_new_day()
	var session: SimulationSession = _app.host.session
	while not session.clock.is_day_over():
		session.advance_seconds(30)
		if decision == &"":
			continue
		for inc: Incident in session.all_incidents():
			if inc.status == Enums.IncidentStatus.AWAITING_DECISION:
				session.apply_command(ResolveIncidentCommand.make(inc.id, decision))
	var report: DayReport = DayReport.from_session(session, null, _app.active_scenario)
	_app.host.stop()
	return report


func _advance_to(target: int) -> void:
	var session: SimulationSession = _screen.host.session
	while session.clock.now < target:
		session.advance_seconds(mini(30, target - session.clock.now))


func _shoot_all(stage: String) -> void:
	if not _wants(stage):
		return
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		DisplayServer.window_set_position(Vector2i(0, 0))
		await create_timer(SETTLE).timeout
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%dx%d_%s.png" % [OUT_DIR, size.x, size.y, stage]
		var err: Error = image.save_png(ProjectSettings.globalize_path(path))
		print("Captura %s -> %s (%s)" % [size, path, error_string(err)])
