extends SceneTree
## Captura la pantalla principal en las resoluciones de revisión visual (Fase 4: con simulación).
## Requiere ventana (no headless):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tools/capture_screens.gd [-- select=3103 at=08:00 delay=1500]
## Arranca la sesión del escenario MVP, avanza a `at` (pausa), captura la situación en hora,
## inyecta `delay` segundos al 3103 y captura en cada resolución.
## Salida: docs/captures/phase4/<ancho>x<alto>_<etapa>[_selCODIGO].png

const SCENE_PATH := "res://ui/screens/operations/operations_screen.tscn"
const OUT_DIR := "res://docs/captures/phase4"
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 800)]
## Segundos de espera tras cambiar el tamaño (deja terminar las animaciones de entrada).
const SETTLE := 1.2

var _screen: Node
var _suffix: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var select: String = "3103"
	var at_time: int = SimTime.parse("08:00")
	var delay_s: int = 1500
	var extra_min: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("select="):
			select = arg.substr(7)
		elif arg.begins_with("at="):
			at_time = SimTime.parse(arg.substr(3))
		elif arg.begins_with("delay="):
			delay_s = arg.substr(6).to_int()
		elif arg.begins_with("after="):
			extra_min = arg.substr(6).to_int()
	_screen = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_screen)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	await create_timer(0.4).timeout

	# Pantalla de inicio (antes de arrancar).
	await _shoot_all("0_inicio")

	# Avanza en pausa hasta la hora pedida y oculta el velo de inicio.
	var host: SimulationHost = _screen.host
	_screen._overlay.visible = false
	_advance_to(host, at_time)
	_screen.select_service(select, false)
	await create_timer(0.3).timeout
	await _shoot_all("1_en_hora")

	# Inyecta el retraso y deja que se procese en el siguiente segundo de simulación.
	_screen.inject_demo_delay()
	host.session.advance_seconds(1)
	if extra_min > 0:
		_advance_to(host, at_time + extra_min * 60)
	await create_timer(0.3).timeout
	await _shoot_all("2_retraso")
	_screen.select_service("3105", false)
	await create_timer(0.3).timeout
	await _shoot_all("3_propagacion")
	quit()


func _advance_to(host: SimulationHost, target: int) -> void:
	while host.session.clock.now < target:
		host.session.advance_seconds(mini(30, target - host.session.clock.now))


func _shoot_all(stage: String) -> void:
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		DisplayServer.window_set_position(Vector2i(0, 0))
		await create_timer(SETTLE).timeout
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%dx%d_%s.png" % [OUT_DIR, size.x, size.y, stage]
		var err: Error = image.save_png(ProjectSettings.globalize_path(path))
		print("Captura %s -> %s (%s)" % [size, path, error_string(err)])
