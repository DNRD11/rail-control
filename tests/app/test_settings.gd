extends TestCase
## Settings: valores por defecto, validación/clamp, señales y persistencia en archivo (user://qa_tests/).

const DIR: String = "user://qa_tests"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	return "%s/%s.cfg" % [DIR, name]


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_defaults_when_file_missing() -> void:
	var s: Settings = Settings.load_from(_path("no_existe_nunca"))
	assert_eq(s.default_speed, 1)
	assert_true(s.auto_pause_on_incident)
	assert_near(s.ui_scale, 1.0)
	assert_near(s.volume, 0.8)


func test_settings_persist_across_load() -> void:
	var path: String = _path("persist")
	_remove(path)
	var s: Settings = Settings.load_from(path)
	s.default_speed = 4
	s.auto_pause_on_incident = false
	s.ui_scale = 1.25
	s.volume = 0.3
	assert_true(s.save())
	assert_true(FileAccess.file_exists(path))
	var r: Settings = Settings.load_from(path)
	assert_eq(r.default_speed, 4)
	assert_false(r.auto_pause_on_incident)
	assert_near(r.ui_scale, 1.25)
	assert_near(r.volume, 0.3)
	# guardar de nuevo con otros valores sobrescribe
	r.default_speed = 2
	assert_true(r.save())
	assert_eq(Settings.load_from(path).default_speed, 2)
	_remove(path)


func test_values_are_clamped_and_validated() -> void:
	var s: Settings = Settings.new()
	s.default_speed = 3
	assert_eq(s.default_speed, 1, "velocidad inválida vuelve a x1")
	s.default_speed = 4
	s.default_speed = 0
	assert_eq(s.default_speed, 1, "0 (pausa) no es una velocidad por defecto válida")
	s.ui_scale = 9.0
	assert_near(s.ui_scale, 1.5)
	s.ui_scale = 0.1
	assert_near(s.ui_scale, 0.8)
	s.volume = 5.0
	assert_near(s.volume, 1.0)
	s.volume = -1.0
	assert_near(s.volume, 0.0)


func test_invalid_values_in_file_are_sanitised_on_load() -> void:
	var path: String = _path("invalid")
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(Settings.SECTION, "default_speed", 7)
	cfg.set_value(Settings.SECTION, "ui_scale", 50.0)
	cfg.set_value(Settings.SECTION, "volume", -3.0)
	cfg.save(path)
	var s: Settings = Settings.load_from(path)
	assert_eq(s.default_speed, 1)
	assert_near(s.ui_scale, 1.5)
	assert_near(s.volume, 0.0)
	_remove(path)


func test_changed_signal_only_on_real_change() -> void:
	var s: Settings = Settings.new()
	var keys: Array[StringName] = []
	s.changed.connect(func(k: StringName) -> void: keys.append(k))
	s.default_speed = 1
	s.volume = 0.8
	assert_eq(keys.size(), 0, "sin cambios no hay señal")
	s.default_speed = 2
	s.auto_pause_on_incident = false
	s.ui_scale = 1.1
	s.volume = 0.5
	assert_eq(keys, [&"default_speed", &"auto_pause_on_incident", &"ui_scale", &"volume"] as Array[StringName])


func test_unwritable_path_reports_failure() -> void:
	var s: Settings = Settings.load_from("user://qa_tests/directorio_inexistente_xyz/sub/ajustes.cfg")
	assert_false(s.save(), "no se puede guardar en una ruta inexistente")
