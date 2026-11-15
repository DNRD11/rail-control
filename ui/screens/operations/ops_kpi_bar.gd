class_name OpsKpiBar
extends RefCounted
## Alimenta los tres RcKpiTile de la barra superior (calidad, percepción, resultado en €) con
## `session.query_indicators()`. Solo lee: marca «sucio» con indicators_changed / ledger_changed y
## refresca como mucho cada REFRESH_S (tiempo real) para no recalcular en cada paso de simulación.
## Guarda un historial de muestras (cada SAMPLE_S de jornada) para la tendencia y el micrográfico.

const REFRESH_S := 0.25
const SAMPLE_S := 600
const MAX_SAMPLES := 24

var _session: SimulationSession
var _quality: RcKpiTile
var _perception: RcKpiTile
var _result: RcKpiTile
var _dirty: bool = true
var _since: float = 0.0
var _last_sample: int = -1
var _hq: PackedFloat32Array = PackedFloat32Array()
var _hp: PackedFloat32Array = PackedFloat32Array()
var _hr: PackedFloat32Array = PackedFloat32Array()
var show_spark: bool = false


func setup(session: SimulationSession, quality: RcKpiTile, perception: RcKpiTile, result: RcKpiTile) -> void:
	_session = session
	_quality = quality
	_perception = perception
	_result = result
	for tile: RcKpiTile in [quality, perception, result]:
		tile.no_data = false
	session.indicators_changed.connect(func() -> void: _dirty = true)
	session.ledger_changed.connect(func(_e: LedgerEntry) -> void: _dirty = true)
	refresh()


## Se llama cada fotograma con el delta real.
func tick(delta: float) -> void:
	_since += delta
	if _dirty and _since >= REFRESH_S:
		refresh()


func refresh() -> void:
	_dirty = false
	_since = 0.0
	var ind: Indicators = _session.query_indicators()
	var now: int = _session.clock.now
	if _last_sample < 0 or now - _last_sample >= SAMPLE_S:
		_last_sample = now
		_push(_hq, ind.quality)
		_push(_hp, ind.perception)
		_push(_hr, float(ind.result_cents))
	_show(_quality, _hq, "%d" % int(roundf(ind.quality)), ind.quality)
	_show(_perception, _hp, "%d" % int(roundf(ind.perception)), ind.perception)
	_show(_result, _hr, RcFormat.eur_compact(ind.result_cents), float(ind.result_cents))
	_result.value_state = RcTokens.State.ALERT if ind.result_cents < 0 else -1


func _push(history: PackedFloat32Array, value: float) -> void:
	history.append(value)
	if history.size() > MAX_SAMPLES:
		history.remove_at(0)


func _show(tile: RcKpiTile, history: PackedFloat32Array, text: String, current: float) -> void:
	tile.value_text = text
	var previous: float = history[history.size() - 2] if history.size() >= 2 else current
	tile.show_trend = history.size() >= 2 and absf(current - previous) >= 0.5
	tile.trend_up = current >= previous
	tile.trend_state = RcTokens.State.OK if current >= previous else RcTokens.State.WARN
	tile.history = history if show_spark else PackedFloat32Array()
