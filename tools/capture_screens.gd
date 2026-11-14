extends SceneTree
## Captura la pantalla principal en las resoluciones de revisión visual.
## Autorizado excepcionalmente a ux-ui en la fase 1b. Requiere ventana (no headless):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tools/capture_screens.gd
## Salida: docs/captures/phase1b/<ancho>x<alto>[_selCODIGO].png

const SCENE_PATH := "res://ui/screens/operations/operations_screen.tscn"
const OUT_DIR := "res://docs/captures/phase1b"
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 800)]
## Segundos de espera tras cambiar el tamaño (deja terminar las animaciones de entrada).
const SETTLE := 1.6


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var screen: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(screen)
	# Opcional: `-- select=3150` simula tocar ese servicio y añade el sufijo al archivo.
	var suffix: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("select="):
			var code: String = arg.substr(7)
			var schematic: LineSchematic = screen.get_node("%Schematic") as LineSchematic
			schematic.select_service(code)
			schematic.service_selected.emit(code)
			suffix = "_sel" + code
	# Sin bordes para que el sistema no recorte la ventana al tamaño pedido.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		DisplayServer.window_set_position(Vector2i(0, 0))
		await create_timer(SETTLE).timeout
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%dx%d%s.png" % [OUT_DIR, size.x, size.y, suffix]
		var err: Error = image.save_png(ProjectSettings.globalize_path(path))
		print("Captura %s -> %s (%dx%d, %s)" % [size, path, image.get_width(), image.get_height(), error_string(err)])
	quit()
