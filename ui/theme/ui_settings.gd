class_name UiSettings
extends RefCounted
## Preferencias que son solo de presentación y aplicación de los ajustes en la UI.
## Velocidad, pausa automática y escala viven en `AppFlow.settings` (Settings); «Reducir animaciones»
## no existe allí, así que se guarda en su propio ConfigFile (`user://ui_prefs.cfg`).

const PATH: String = "user://ui_prefs.cfg"
const SECTION: String = "ui"

static var _loaded: bool = false


static func reduce_motion() -> bool:
	_ensure_loaded()
	return RcTokens.reduce_motion


static func set_reduce_motion(on: bool) -> void:
	_ensure_loaded()
	RcTokens.reduce_motion = on
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "reduce_motion", on)
	var err: Error = cfg.save(PATH)
	if err != OK:
		push_error("No se pudieron guardar las preferencias de UI en %s (error %d)" % [PATH, err])


## Aplica animaciones reducidas y escala de interfaz. Se llama al abrir cada pantalla.
static func apply_all() -> void:
	_ensure_loaded()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.content_scale_factor = AppFlow.settings.ui_scale


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) == OK:
		RcTokens.reduce_motion = bool(cfg.get_value(SECTION, "reduce_motion", false))
