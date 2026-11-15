class_name Settings
extends RefCounted
## Ajustes de usuario persistidos en user://settings.cfg. Cada cambio emite `changed(key)`.

signal changed(key: StringName)

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const SPEEDS: Array[int] = [1, 2, 4]

## Velocidad con la que arranca la jornada (1, 2 o 4).
var default_speed: int = 1 : set = set_default_speed
## Pausar automáticamente al detectarse una incidencia.
var auto_pause_on_incident: bool = true : set = set_auto_pause_on_incident
## Escala de interfaz (0.8-1.5).
var ui_scale: float = 1.0 : set = set_ui_scale
## Volumen maestro 0-1 (reservado: aún no hay audio).
var volume: float = 0.8 : set = set_volume

var _path: String = PATH


static func load_from(path: String = PATH) -> Settings:
	var s: Settings = Settings.new()
	s._path = path
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	s.default_speed = int(cfg.get_value(SECTION, "default_speed", s.default_speed))
	s.auto_pause_on_incident = bool(cfg.get_value(SECTION, "auto_pause_on_incident", s.auto_pause_on_incident))
	s.ui_scale = float(cfg.get_value(SECTION, "ui_scale", s.ui_scale))
	s.volume = float(cfg.get_value(SECTION, "volume", s.volume))
	return s


func save() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "default_speed", default_speed)
	cfg.set_value(SECTION, "auto_pause_on_incident", auto_pause_on_incident)
	cfg.set_value(SECTION, "ui_scale", ui_scale)
	cfg.set_value(SECTION, "volume", volume)
	var err: Error = cfg.save(_path)
	if err != OK:
		push_error("No se pudieron guardar los ajustes en %s (error %d)" % [_path, err])
	return err == OK


func set_default_speed(v: int) -> void:
	var nv: int = v if SPEEDS.has(v) else 1
	if nv != default_speed:
		default_speed = nv
		changed.emit(&"default_speed")


func set_auto_pause_on_incident(v: bool) -> void:
	if v != auto_pause_on_incident:
		auto_pause_on_incident = v
		changed.emit(&"auto_pause_on_incident")


func set_ui_scale(v: float) -> void:
	var nv: float = clampf(v, 0.8, 1.5)
	if not is_equal_approx(nv, ui_scale):
		ui_scale = nv
		changed.emit(&"ui_scale")


func set_volume(v: float) -> void:
	var nv: float = clampf(v, 0.0, 1.0)
	if not is_equal_approx(nv, volume):
		volume = nv
		changed.emit(&"volume")
