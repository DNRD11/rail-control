extends Control
## Pantalla principal «Operación CGO». Carga el escenario, crea la sesión y un SimulationHost
## hijo, y delega la traducción sesión → presentación en OperationsPresenter. La UI solo emite
## comandos (SetSpeedCommand, InjectDelayCommand) y nunca modifica el estado de la simulación.

const SCENARIO_ID := "mvp_mad_bcn_morning"
## Velocidad (índice del control segmentado → factor de simulación).
const SPEEDS: Array[int] = [0, 1, 2, 4]
const DEBUG_DELAY_SERVICE := &"svc_3103"
const DEBUG_DELAY_SECONDS := 1500

@onready var _margin: MarginContainer = %Margin
@onready var _root: VBoxContainer = %Root
@onready var _middle: HBoxContainer = %Middle
@onready var _top_bar: RcPanel = %TopBar
@onready var _incidents_panel: RcPanel = %IncidentsPanel
@onready var _schematic_panel: RcPanel = %SchematicPanel
@onready var _detail_panel: RcPanel = %DetailPanel
@onready var _resources_bar: RcPanel = %ResourcesBar
@onready var _schematic: LineSchematic = %Schematic
@onready var _detail: OpsServiceDetail = %DetailView
@onready var _incidents: OpsIncidentsView = %IncidentsView
@onready var _resources: OpsResourcesStrip = %ResourcesStrip
@onready var _clock: Label = %Clock
@onready var _speed: RcSegmentedControl = %Speed
@onready var _alert_counter: RcStatusChip = %AlertCounter
@onready var _kpi_quality: RcKpiTile = %KpiQuality
@onready var _kpi_perception: RcKpiTile = %KpiPerception
@onready var _kpi_result: RcKpiTile = %KpiResult

var host: SimulationHost
var presenter: OperationsPresenter
var selected_code: String = ""

var _overlay: OpsStartOverlay
var _dirty: bool = true


func _ready() -> void:
	_apply_layout()
	_fill_kpi(_kpi_quality, "Calidad")
	_fill_kpi(_kpi_perception, "Percepción")
	_fill_kpi(_kpi_result, "Resultado")
	_overlay = OpsStartOverlay.new()
	_schematic.add_child(_overlay)
	_overlay.start_pressed.connect(_on_start_pressed)
	_schematic.service_selected.connect(_on_service_selected)
	_incidents.notice_selected.connect(select_service)
	_incidents.inject_requested.connect(inject_demo_delay)
	_speed.selected_changed.connect(_on_speed_picked)
	_load_scenario()


func _process(_delta: float) -> void:
	if presenter == null:
		return
	if _dirty:
		_dirty = false
		_refresh_state()
	presenter.update_positions(host.get_fraction())


func _apply_layout() -> void:
	for side: String in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, RcTokens.MARGIN_SCREEN)
	_root.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_middle.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_top_bar.custom_minimum_size.y = RcTokens.TOPBAR_H
	_resources_bar.custom_minimum_size.y = RcTokens.BOTTOM_BAR_H
	_incidents_panel.custom_minimum_size.x = RcTokens.LEFT_PANEL_W
	_detail_panel.custom_minimum_size.x = RcTokens.RIGHT_PANEL_W


## Indicadores económicos y de calidad: llegan en la Fase 6; no se inventan cifras.
func _fill_kpi(tile: RcKpiTile, caption: String) -> void:
	tile.caption = caption
	tile.value_text = "—"
	tile.no_data = true


# --- Carga y arranque ----------------------------------------------------------

func _load_scenario() -> void:
	var result: ScenarioLoadResult = ScenarioLoader.load_scenario(SCENARIO_ID)
	if not result.ok:
		var lines: PackedStringArray = PackedStringArray()
		for issue: ValidationReport.Issue in result.report.issues:
			if issue.severity == ValidationReport.Severity.ERROR and lines.size() < 4:
				lines.append(issue.message)
		_overlay.show_error("\n".join(lines))
		return
	var session: SimulationSession = SimulationSession.create(result.world)
	host = SimulationHost.new()
	add_child(host)
	host.start(session)
	host.set_speed(0)
	host.clock_ticked.connect(func(_now: int) -> void: _on_sim_changed())
	host.service_updated.connect(func(_id: StringName) -> void: _on_sim_changed())
	host.speed_changed.connect(_on_speed_changed)
	presenter = OperationsPresenter.new()
	presenter.setup(session, host)
	_schematic.set_data(presenter.stations(), presenter.services())
	var scenario: ScenarioInfo = result.world.scenario
	_overlay.show_ready(scenario.name, "Jornada %s – %s · la simulación empieza en pausa." % [
			SimTime.format(scenario.day_start), SimTime.format(scenario.day_end)])
	var ids: Array[StringName] = session.service_ids()
	if not ids.is_empty():
		select_service((result.world.services[ids[0]] as Service).code, false)
	_on_sim_changed()


func _on_start_pressed() -> void:
	_overlay.visible = false
	host.set_speed(1)


func _on_speed_picked(index: int) -> void:
	if host != null:
		host.set_speed(SPEEDS[index])


func _on_speed_changed(speed: int) -> void:
	_speed.selected = maxi(SPEEDS.find(speed), 0)
	if speed > 0:
		_overlay.visible = false


func _on_sim_changed() -> void:
	_dirty = true
	_clock.text = presenter.clock_text()


# --- Selección y refresco ------------------------------------------------------

func _on_service_selected(code: String) -> void:
	select_service(code, true)


func select_service(code: String, animate: bool = true) -> void:
	selected_code = code
	_schematic.select_service(code, animate)
	_detail_panel.title = "Servicio %s" % code
	_detail.show_service(presenter.detail(code), animate)
	_show_eta()


func _show_eta() -> void:
	var eta: Array = presenter.eta_for(selected_code)
	_schematic.set_eta(eta[0], eta[1], eta[2])


func _refresh_state() -> void:
	presenter.update_state()
	var notices: Array[Dictionary] = presenter.notices()
	_incidents.set_notices(notices)
	_incidents.set_summary(presenter.summary())
	_resources.set_data(presenter.resource_strip())
	if notices.is_empty():
		_alert_counter.text = "Sin avisos"
		_alert_counter.state = RcTokens.State.OK
	else:
		_alert_counter.text = "%d aviso%s" % [notices.size(), "" if notices.size() == 1 else "s"]
		_alert_counter.state = RcTokens.State.WARN
	if not selected_code.is_empty():
		_detail.update_service(presenter.detail(selected_code))
		_show_eta()


# --- Depuración -------------------------------------------------------------------

## Control de depuración: retraso de +25′ al 3103 (la avería real llega en la Fase 5).
func inject_demo_delay() -> void:
	if host == null or host.session == null:
		return
	var cmd: InjectDelayCommand = InjectDelayCommand.make(DEBUG_DELAY_SERVICE, DEBUG_DELAY_SECONDS)
	host.session.apply_command(cmd)
	_dirty = true
