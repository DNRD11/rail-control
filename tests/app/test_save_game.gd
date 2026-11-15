extends TestCase
## Guardado/restauración (SaveGame): una jornada guardada a mitad, con la avería ya decidida, termina con el
## mismo hash que una jornada sin guardar. Usa user://qa_tests/ y lo limpia.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const DIR: String = "user://qa_tests"
const SEED: int = 777


func _path(name: String) -> String:
	return "%s/%s.json" % [DIR, name]


func _new_session() -> SimulationSession:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(ScenarioFixture.MVP)
	assert_true(res.ok)
	return SimulationSession.create(res.world, SEED)


## Jornada con los mismos comandos a las mismas horas; `save_at` > 0 guarda en ese instante y devuelve la sesión
## restaurada (sin tocar la original).
func _play_until(s: SimulationSession, option: StringName, until: int) -> void:
	if s.clock.now < D.t("07:00") and until >= D.t("07:00"):
		D.run_to_text(s, "07:00")
		s.apply_command(SetSpeedCommand.make(2))
	if s.clock.now < D.t("08:12") and until >= D.t("08:12"):
		D.run_to_text(s, "08:12", 600)
		F.decide(s, option)
	if s.clock.now < D.t("08:20") and until >= D.t("08:20"):
		D.run_to_text(s, "08:20", 600)
		s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id))
	D.run_to(s, until, 600)


func test_roundtrip_midday_with_decided_incident_matches_uninterrupted_day() -> void:
	for option: StringName in OptionType.ALL:
		var path: String = _path("mid_%s" % option)
		var saved: SimulationSession = _new_session()
		_play_until(saved, option, D.t("10:00"))
		assert_true(SaveGame.save(saved, ScenarioFixture.MVP, path), "guardado (%s)" % option)
		var restored: SimulationSession = SaveGame.load(path)
		assert_ne(restored, null, "carga con hash válido (%s)" % option)
		if restored == null:
			continue
		assert_eq(StateHash.of(restored), StateHash.of(saved), "mismo estado al restaurar")
		assert_eq(restored.clock.now, D.t("10:00"))
		assert_eq(restored.command_log.size(), saved.command_log.size())
		assert_eq(F.incident(restored).decision.option_type, option, "la decisión sobrevive al guardado")
		assert_eq(restored.rng.seed, SEED)
		# continuar ambas sesiones y compararlas con una jornada sin guardar
		D.run_to(restored, restored.clock.day_end, 450)
		var reference: SimulationSession = _new_session()
		_play_until(reference, option, reference.clock.day_end)
		assert_true(restored.clock.is_day_over())
		assert_eq(StateHash.of(restored), StateHash.of(reference), "hash final igual al de una jornada sin guardar (%s)" % option)
		assert_eq(restored.log.digest(), reference.log.digest())
		assert_eq(restored.query_ledger().total_cents(), reference.query_ledger().total_cents())
		SaveGame.delete(path)


func test_save_before_decision_then_decide_after_restore() -> void:
	var path: String = _path("pre_decision")
	var s: SimulationSession = _new_session()
	D.run_to_text(s, "08:12", 600)
	assert_eq(F.incident(s).status, Enums.IncidentStatus.AWAITING_DECISION)
	assert_true(SaveGame.save(s, ScenarioFixture.MVP, path))
	var r: SimulationSession = SaveGame.load(path)
	assert_ne(r, null)
	if r == null:
		return
	assert_eq(F.incident(r).status, Enums.IncidentStatus.AWAITING_DECISION, "sigue pendiente de decisión")
	assert_eq(F.incident(r).repair_s, F.incident(s).repair_s, "misma duración de reparación (RNG restaurado)")
	assert_true(F.decide(r, OptionType.SUBSTITUTE_ROLLING_STOCK))
	assert_true(F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK))
	D.run_to(r, r.clock.day_end)
	D.run_to(s, s.clock.day_end)
	assert_eq(StateHash.of(r), StateHash.of(s))
	SaveGame.delete(path)


func test_save_at_day_end_and_peek() -> void:
	var path: String = _path("end")
	var s: SimulationSession = _new_session()
	_play_until(s, OptionType.WAIT_REPAIR, s.clock.day_end)
	assert_true(SaveGame.save(s, ScenarioFixture.MVP, path))
	assert_true(SaveGame.exists(path))
	var head: Dictionary = SaveGame.peek(path)
	assert_eq(head["scenario_id"], ScenarioFixture.MVP)
	assert_eq(head["now"], s.clock.day_end)
	assert_eq(head["version"], SaveGame.VERSION)
	var r: SimulationSession = SaveGame.load(path)
	assert_ne(r, null)
	if r != null:
		assert_true(r.clock.is_day_over())
		assert_eq(StateHash.of(r), StateHash.of(s))
	SaveGame.delete(path)
	assert_false(SaveGame.exists(path), "delete borra el archivo")


func test_save_is_deterministic_text() -> void:
	var a: String = _path("det_a")
	var b: String = _path("det_b")
	var s1: SimulationSession = _new_session()
	var s2: SimulationSession = _new_session()
	_play_until(s1, OptionType.WAIT_REPAIR, D.t("09:00"))
	_play_until(s2, OptionType.WAIT_REPAIR, D.t("09:00"))
	SaveGame.save(s1, ScenarioFixture.MVP, a)
	SaveGame.save(s2, ScenarioFixture.MVP, b)
	assert_eq(FileAccess.get_file_as_string(a), FileAccess.get_file_as_string(b), "mismo estado, mismo guardado")
	SaveGame.delete(a)
	SaveGame.delete(b)


func test_tampered_hash_is_rejected() -> void:
	var path: String = _path("tamper")
	var s: SimulationSession = _new_session()
	_play_until(s, OptionType.WAIT_REPAIR, D.t("09:00"))
	SaveGame.save(s, ScenarioFixture.MVP, path)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	d["hash"] = "0".repeat(64)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	assert_eq(SaveGame.load(path), null, "el hash no coincide: no se restaura")
	SaveGame.delete(path)


func test_corrupt_missing_and_wrong_version_are_rejected() -> void:
	var path: String = _path("bad")
	DirAccess.make_dir_recursive_absolute(DIR)
	assert_eq(SaveGame.load(_path("no_existe")), null)
	assert_eq(SaveGame.peek(_path("no_existe")), {})
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ esto no es json")
	f.close()
	assert_eq(SaveGame.load(path), null, "JSON corrupto")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "scenario_id": ScenarioFixture.MVP, "seed": 1, "now": 0,
			"commands": [], "hash": ""}))
	f.close()
	assert_eq(SaveGame.load(path), null, "versión no soportada")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "scenario_id": ScenarioFixture.MVP}))
	f.close()
	assert_eq(SaveGame.load(path), null, "guardado incompleto")
	SaveGame.delete(path)


func test_unknown_scenario_is_rejected() -> void:
	var path: String = _path("unknown_scn")
	var s: SimulationSession = _new_session()
	SaveGame.save(s, "escenario_que_no_existe", path)
	assert_eq(SaveGame.load(path), null)
	SaveGame.delete(path)
