extends Control
## Pantalla principal «Operación CGO». Usa la sesión que `AppFlow` deja en `AppFlow.host` (nueva o
## cargada) y delega la traducción sesión → presentación en OperationsPresenter; la navegación
## (pausa, guardar, informe) va en OpsFlowGlue. La UI solo emite comandos y nunca modifica el estado.

## Velocidad (índice del control segmentado → factor de simulación).
const SPEEDS: Array[int] = [0, 1, 2, 4]
## Ancho lógico a partir del cual la barra de indicadores muestra micrográficos.
const WIDE_W := 1500.0
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
var incident_presenter: OpsIncidentPresenter
var selected_code: String = ""

var _overlay: OpsStartOverlay
var _sheet: OpsDecisionSheet
var _pause_menu: OpsPauseMenu
var _kpis: OpsKpiBar
var _toasts: RcToast
var glue: OpsFlowGlue
var _dirty: bool = true
## Velocidad a restaurar tras decidir, si la pausa la hizo la incidencia (no el jugador).
var _resume_speed: int = 1
var _auto_paused: bool = false
var _focus_incident: StringName = &""


func _ready() -> void:
	_apply_layout()
	UiSettings.apply_all()
	_kpi_quality.caption = "Calidad"
	_kpi_perception.caption = "Percepción"
	_kpi_result.caption = "Resultado"
	for tile: RcKpiTile in [_kpi_quality, _kpi_perception, _kpi_result]:
		tile.no_data = true
		tile.value_text = "—"
	_overlay = OpsStartOverlay.new()
	_schematic.add_child(_overlay)
	_overlay.start_pressed.connect(_on_start_pressed)
	_schematic.service_selected.connect(_on_service_selected)
	_incidents.notice_selected.connect(select_service)
	_incidents.inject_requested.connect(inject_demo_delay)
	_incidents.manage_requested.connect(open_incident)
	_sheet = OpsDecisionSheet.new()
	_sheet.z_index = 40
	add_child(_sheet)
	_sheet.chosen.connect(decide)
	_sheet.inform_requested.connect(inform_passengers_for_incident)
	_detail.inform_requested.connect(func() -> void: inform_passengers(selected_code))
	_pause_menu = OpsPauseMenu.new()
	add_child(_pause_menu)
	_toasts = RcToast.new()
	add_child(_toasts)
	var menu_button := RcButton.new()
	menu_button.icon_name = "menu"
	menu_button.icon_only = true
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(func() -> void: glue.open_pause_menu())
	_top_bar.content.add_child(menu_button)
	_speed.selected_changed.connect(_on_speed_picked)
	resized.connect(_on_resized)
	_load_scenario()


func _process(delta: float) -> void:
	if presenter == null:
		return
	if _dirty:
		_dirty = false
		_refresh_state()
	presenter.update_positions(host.get_fraction())
	_kpis.tick(delta)


func _apply_layout() -> void:
	for side: String in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, RcTokens.MARGIN_SCREEN)
	_root.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_middle.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_top_bar.custom_minimum_size.y = RcTokens.TOPBAR_H
	_resources_bar.custom_minimum_size.y = RcTokens.BOTTOM_BAR_H
	_incidents_panel.custom_minimum_size.x = RcTokens.LEFT_PANEL_W
	_detail_panel.custom_minimum_size.x = RcTokens.RIGHT_PANEL_W


# --- Carga y arranque ----------------------------------------------------------

func _load_scenario() -> void:
	host = AppFlow.host
	if host.session == null and not AppFlow.start_new_day():  # escena abierta en solitario
		_overlay.show_error("No se pudo cargar el escenario. Revisa el registro de errores.")
		return
	var session: SimulationSession = host.session
	var scenario: ScenarioInfo = session.world.scenario
	var day_range: String = "Jornada %s – %s" % [SimTime.format(scenario.day_start), SimTime.format(scenario.day_end)]
	var resumed: bool = session.clock.now > scenario.day_start
	host.set_speed(0)
	host.clock_ticked.connect(func(_now: int) -> void: _on_sim_changed())
	host.service_updated.connect(func(_id: StringName) -> void: _on_sim_changed())
	host.speed_changed.connect(_on_speed_changed)
	host.incident_changed.connect(_on_incident_changed)
	glue = OpsFlowGlue.new()
	add_child(glue)
	glue.setup(host, _pause_menu, _sheet, _toasts, func() -> String: return presenter.clock_text())
	_kpis = OpsKpiBar.new()
	_kpis.show_spark = size.x >= WIDE_W
	_kpis.setup(session, _kpi_quality, _kpi_perception, _kpi_result)
	presenter = OperationsPresenter.new()
	presenter.setup(session, host)
	incident_presenter = OpsIncidentPresenter.new()
	incident_presenter.setup(session)
	_schematic.set_data(presenter.stations(), presenter.services())
	if resumed:
		_overlay.show_ready(scenario.name, "%s · jornada en curso, son las %s." % [day_range,
				SimTime.format(session.clock.now)], "Reanudar jornada")
	else:
		_overlay.show_ready(scenario.name, day_range + " · la simulación empieza en pausa.")
	var ids: Array[StringName] = session.service_ids()
	if not ids.is_empty():
		select_service((session.world.services[ids[0]] as Service).code, false)
	_on_sim_changed()


func _on_resized() -> void:
	if _kpis != null:
		_kpis.show_spark = size.x >= WIDE_W
		_kpis.refresh()


func _on_start_pressed() -> void:
	_overlay.visible = false
	host.set_speed(AppFlow.settings.default_speed)


func _on_speed_picked(index: int) -> void:
	if host != null:
		host.set_speed(SPEEDS[index])


func _on_speed_changed(speed: int) -> void:
	_speed.selected = maxi(SPEEDS.find(speed), 0)
	if speed > 0:
		_overlay.visible = false
		_auto_paused = false  # el jugador (o la reanudación) ya tomó el control del tiempo


func _on_sim_changed() -> void:
	_dirty = true
	_clock.text = presenter.clock_text()


# --- Incidencias ---------------------------------------------------------------------

## Una incidencia nueva pausa la simulación y abre la hoja de decisión; al decidirse se cierra
## la hoja y se reanuda a la velocidad anterior.
func _on_incident_changed(incident_id: StringName) -> void:
	var inc: Incident = host.session.query_incident(incident_id)
	if inc == null:
		return
	_dirty = true
	if inc.status == Enums.IncidentStatus.AWAITING_DECISION:
		_focus_incident = incident_id
		select_service(incident_presenter.service_code(inc), true)
		if AppFlow.settings.auto_pause_on_incident:
			open_incident(incident_id)
	elif _sheet.is_open_for(incident_id):
		_sheet.close()
		_resume_after_decision()


## Abre la hoja de decisión de una incidencia pendiente (pausa si la simulación corre).
func open_incident(incident_id: StringName) -> void:
	var model: Dictionary = incident_presenter.sheet_model(incident_id)
	if model.is_empty() or not bool(model["awaiting"]):
		return
	var speed: int = host.get_speed()
	if speed > 0:
		_resume_speed = speed
		_auto_paused = true
		host.set_speed(0)
	_sheet.open(model)


## Comando del jugador: elegir una opción de la incidencia abierta en la hoja.
func decide(incident_id: StringName, option_type: StringName) -> void:
	host.session.apply_command(ResolveIncidentCommand.make(incident_id, option_type))
	_dirty = true


func _resume_after_decision() -> void:
	if _auto_paused and incident_presenter.awaiting_count() == 0 and host.get_speed() == 0:
		host.set_speed(_resume_speed)
	_auto_paused = false


# --- Información al viajero, pausa y fin de jornada ---------------------------------

## Comando del jugador: informar a los viajeros del servicio `code` (por la incidencia que corresponda).
func inform_passengers(code: String) -> void:
	var sid: StringName = presenter.service_id_of(code)
	var model: Dictionary = incident_presenter.inform_model(sid)
	if bool(model["available"]):
		_send_inform(sid, model["incident_id"] as StringName, code)


func inform_passengers_for_incident(incident_id: StringName) -> void:
	var inc: Incident = host.session.query_incident(incident_id)
	if inc != null:
		_send_inform(inc.service_id, incident_id, incident_presenter.service_code(inc))


func _send_inform(service_id: StringName, incident_id: StringName, code: String) -> void:
	var ok: bool = host.session.apply_command(InformPassengersCommand.make(service_id, incident_id))
	_dirty = true
	if ok:
		_toasts.show_toast("Viajeros del servicio %s informados" % code)
	else:
		_toasts.show_toast("No se pudo informar a los viajeros del servicio %s" % code, RcTokens.State.WARN)


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
	_incidents.set_incidents(incident_presenter.open_cards())
	_incidents.set_history(incident_presenter.history())
	if _focus_incident != &"":
		_incidents.focus_incident(_focus_incident)
		_focus_incident = &""
	if _sheet.visible:
		_sheet.refresh(incident_presenter.sheet_model(_sheet.incident_id))
	var open_count: int = incident_presenter.open_count()
	if open_count > 0:
		_alert_counter.text = "%d incidencia%s" % [open_count, "" if open_count == 1 else "s"]
		_alert_counter.state = RcTokens.State.ALERT if incident_presenter.awaiting_count() > 0 else RcTokens.State.WARN
	elif notices.is_empty():
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
