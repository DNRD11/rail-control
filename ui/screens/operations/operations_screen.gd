extends Control
## Pantalla principal «Operación CGO» — prototipo visual estático (fase 1b).
## Los datos vienen de OperationsMockData; no hay simulación.

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
@onready var _clock: Label = %Clock
@onready var _kpi_quality: RcKpiTile = %KpiQuality
@onready var _kpi_perception: RcKpiTile = %KpiPerception
@onready var _kpi_result: RcKpiTile = %KpiResult

var _services: Array[SchematicService] = []


func _ready() -> void:
	_apply_layout()
	_clock.text = OperationsMockData.CLOCK_TEXT
	_fill_kpi(_kpi_quality, "Calidad", OperationsMockData.kpis()["quality"])
	_fill_kpi(_kpi_perception, "Percepción", OperationsMockData.kpis()["perception"])
	_fill_kpi(_kpi_result, "Resultado", OperationsMockData.kpis()["result"])
	_services = OperationsMockData.services()
	_schematic.set_data(OperationsMockData.stations(), _services)
	_schematic.service_selected.connect(_on_service_selected)
	_schematic.select_service(OperationsMockData.SELECTED_DEFAULT, false)
	_show_detail(OperationsMockData.SELECTED_DEFAULT, false)


func _process(delta: float) -> void:
	# Solo animación visual de comprobación; no es simulación.
	OperationsMockData.advance(_services, delta)


func _apply_layout() -> void:
	for side: String in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, RcTokens.MARGIN_SCREEN)
	_root.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_middle.add_theme_constant_override("separation", RcTokens.GAP_MODULES)
	_top_bar.custom_minimum_size.y = RcTokens.TOPBAR_H
	_resources_bar.custom_minimum_size.y = RcTokens.BOTTOM_BAR_H
	_incidents_panel.custom_minimum_size.x = RcTokens.LEFT_PANEL_W
	_detail_panel.custom_minimum_size.x = RcTokens.RIGHT_PANEL_W


func _fill_kpi(tile: RcKpiTile, caption: String, data: Dictionary) -> void:
	tile.caption = caption
	tile.value_text = data["value"]
	tile.suffix = data.get("suffix", "")
	tile.trend_up = data["up"]
	tile.trend_state = data["state"]
	tile.history = data["history"]


func _on_service_selected(code: String) -> void:
	_show_detail(code, true)


func _show_detail(code: String, animate: bool) -> void:
	var data: Dictionary = OperationsMockData.detail(code)
	_detail_panel.title = "Servicio %s" % code
	_detail.show_service(data, animate)
	var eta: Array = OperationsMockData.eta_for(code)
	_schematic.set_eta(eta[0], eta[1], eta[2])
