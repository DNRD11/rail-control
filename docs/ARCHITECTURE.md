# Arquitectura técnica

Godot 4.7.2 · GDScript con tipado estático · 2D · renderer Mobile · horizontal. Sin dependencias externas.

## 1. Capas

```
┌────────────────────────────────────────────────────────────────────┐
│ PRESENTACIÓN  (ui/)  Nodes, escenas, tema, tweens, _draw           │
│   lee: snapshots y signals de la sesión · escribe: Commands        │
└───────────────▲──────────────────────────────┬─────────────────────┘
        signals │                              │ apply_command()
┌───────────────┴──────────────────────────────▼─────────────────────┐
│ PUENTE  (src/app/)  SimulationHost (Node): reloj real → pasos sim, │
│         velocidad/pausa, reenvía signals. App (autoload): navegación│
└───────────────▲──────────────────────────────┬─────────────────────┘
                │                              │ advance_seconds(n)
┌───────────────┴──────────────────────────────▼─────────────────────┐
│ SIMULACIÓN  (src/sim, src/systems)  RefCounted puro, headless       │
│   SimulationSession = World + SimClock + EventQueue + Systems + RNG │
└───────────────▲─────────────────────────────────────────────────────┘
                │ construye
┌───────────────┴─────────────────────────────────────────────────────┐
│ MODELO (src/model)  entidades tipadas   DATOS (src/data) JSON → World│
└─────────────────────────────────────────────────────────────────────┘
```

**Regla de dependencias**: las flechas solo apuntan hacia abajo. `src/model` no depende de nada; `src/sim` y `src/systems` dependen de `model`; `src/app` de `sim`; `ui` de `app` y de las clases de lectura de `model`. `src/` nunca importa nada de `ui/`.

## 2. Módulos

| Módulo | Clase(s) principal(es) | Responsabilidad | Dueño |
|---|---|---|---|
| Core | `SimTime`, `Ids`, `Enums`, `ValidationReport` | Formato de horas, ids, enums compartidos | godot-dev |
| Datos | `ScenarioLoader`, `DataValidator`, `WorldBuilder` | Leer JSON, validar esquema y referencias, construir `World` | godot-dev |
| Modelo | `World`, `Line`, `Station`, `Section`, `Service`, `ServiceStop`, `Vehicle`, `VehicleClass`, `Composition`, `ResourceAssignment`, `StaffMember`, `Incident`, `LedgerEntry`… | Estado puro, sin lógica temporal | rail-sim |
| Reloj y eventos | `SimClock`, `EventQueue`, `SimEvent` | Tiempo entero, cola ordenada determinista | rail-sim |
| Sesión | `SimulationSession` | Orquesta sistemas, aplica comandos, emite signals, expone consultas | rail-sim (+ coordinador) |
| Circulación | `MovementSystem` | Salidas, llegadas, pasos, paradas, estimaciones | rail-sim |
| Recursos | `AssignmentSystem`, `RotationGraph` | Asignaciones, solapamientos, dependencias entre servicios, propagación | rail-sim |
| Incidencias | `IncidentSystem`, `IncidentType` (datos), `DecisionOption` | Generar, presentar opciones, aplicar decisiones | rail-sim |
| Viajeros | `PassengerSystem` | Cifras agregadas por servicio y afectación | economy-design |
| Economía | `EconomySystem`, `Ledger` | Costes, ingresos, indemnizaciones | economy-design |
| Indicadores | `PerceptionSystem`, `QualityTracker` | Calidad, percepción | economy-design |
| Informe | `DayReportBuilder` | Agrega el log en el informe final | economy-design / rail-sim |
| PAT (futuro) | `PatSystem`, `AlternativeTransportPlan` | Ver DATA_MODEL §8 | — |
| Infraestructura (futuro) | `InfrastructureManager` | Restricciones, capacidad, autorizaciones | — |
| Guardado | `SaveService` | Serializar sesión a `user://saves/*.json` | godot-dev |
| App | `App` (autoload), `SimulationHost` | Navegación, ajustes, puente sim↔escena | godot-dev |
| UI | tema, componentes, esquema, pantallas | Presentación e interacción | ux-ui |

### Sistemas y orden de ejecución

`SimulationSession.advance_seconds(n)` procesa, segundo a segundo de simulación agrupado por eventos (ver [SIMULATION.md](SIMULATION.md)):

1. Extrae de la `EventQueue` los eventos con `time ≤ now`.
2. Despacha cada evento al sistema que lo maneja (`handles(event_type)`): Movement → Assignment → Incident → Passenger → Economy → Perception.
3. Los sistemas pueden programar nuevos eventos y registran entradas en el `OperationalLog`.
4. Al final del paso, la sesión emite signals agregadas (`services_changed`, `clock_ticked`…).

Los sistemas no se llaman entre sí directamente salvo por consultas de solo lectura al `World`; se comunican mediante eventos y un bus interno de la sesión. Esto evita el «GameManager» monolítico y permite añadir `PatSystem` o `InfrastructureSystem` registrándolos en la sesión.

### Comandos (acciones del jugador)

La UI nunca modifica el modelo. Envía objetos `Command` (`SetSpeedCommand`, `ResolveIncidentCommand`, `SendPassengerInfoCommand`, `CancelServiceCommand`…). La sesión los valida, los registra con su hora de simulación (para repetición determinista y guardado) y los aplica.

### Signals de la sesión (contrato con la UI)

`clock_ticked(now: int)`, `speed_changed(speed: int)`, `service_updated(service_id: StringName)`, `service_stop_event(service_id, stop_index, kind)`, `incident_opened(incident_id)`, `incident_updated(incident_id)`, `decision_required(incident_id)`, `kpis_changed(snapshot: KpiSnapshot)`, `ledger_entry_added(entry_id)`, `day_finished(report: DayReport)`.

La UI obtiene la posición de cada servicio con `session.query_service_position(service_id) -> ServicePosition` (tramo, fracción 0-1, sentido), e interpola visualmente entre pasos con el resto de tiempo real.

## 3. Estructura de carpetas

```
res://
├─ data/
│  ├─ lines/mad_bcn.json             estaciones, tramos, km, tiempos
│  ├─ rolling_stock/vehicle_classes.json
│  ├─ rules/                          incident_types, economy, compensation, perception, infra_charges
│  └─ scenarios/mvp_mad_bcn_morning/  scenario, services, vehicles, compositions, staff, assignments, passengers
├─ src/
│  ├─ core/        SimTime, Ids, Enums, ValidationReport
│  ├─ model/       entidades
│  ├─ data/        ScenarioLoader, DataValidator, WorldBuilder
│  ├─ sim/         SimulationSession, SimClock, EventQueue, SimEvent, commands/
│  ├─ systems/     movement, assignment, incident, passenger, economy, perception, report
│  ├─ save/        SaveService
│  └─ app/         app.gd (autoload), simulation_host.gd
├─ ui/
│  ├─ theme/       rc_theme.tres, tokens.gd
│  ├─ components/  RcPanel, RcButton, RcStatusChip, RcKpiTile, …
│  ├─ schematic/   line_schematic, service_marker, station_node
│  └─ screens/     main_menu, scenario_select, briefing, operations, report, settings
├─ assets/  fonts/ icons/ sfx/
├─ tests/   run_tests.gd, framework/, fixtures/, model/, sim/, systems/, acceptance/
├─ tools/   capture_screens.gd
└─ docs/
```

## 4. Decisiones técnicas

| Decisión | Motivo |
|---|---|
| JSON para datos de escenario | Editable a mano, diffs legibles, ampliable sin tocar código. Se convierte a objetos tipados al cargar. |
| `RefCounted` para modelo y simulación | Pruebas headless sin árbol de escenas, determinismo, sin coste de nodos. |
| Tiempo entero en segundos | Determinismo y comparaciones exactas. |
| Cola de eventos + estado continuo derivado | Eventos discretos para cambios; la posición se calcula analíticamente, sin «mover» nada cada frame. |
| Runner de pruebas propio | Evita addons (GUT) cumpliendo «sin dependencias externas»; suficiente para el MVP. |
| Guardado JSON en `user://` | Sin SQLite; guarda estado + log de comandos (permite reconstrucción determinista). |
| Un `Theme` + tokens | Consistencia visual y cambios globales sin tocar pantallas. |
| Resolución base 1280×720, `canvas_items` + `expand` | Interfaz grande y legible en móvil; se adapta a 16:9, 20:9 y 16:10. |

## 5. Riesgos técnicos

| Riesgo | Mitigación |
|---|---|
| Diferencias de API de Godot 4.7 respecto a la documentación conocida | Verificar con el motor instalado (`--doctool`, scripts mínimos); los agentes tienen esta instrucción. |
| Capturas de pantalla: el modo `--headless` no renderiza | `tools/capture_screens.gd` ejecuta con ventana (renderer real) en varias resoluciones y guarda PNG en `user://captures`. |
| Rendimiento del glow/sombras en Android de gama media | Efectos con `StyleBoxFlat` (sombra) y shaders ligeros opcionales; ajuste de calidad. |
| Export Android: SDK, JDK y plantillas no instalados | Verificar en la fase 7; no bloquea las fases 2-6 (se prueba en escritorio). |
| Crecimiento del modelo (PAT, infraestructura) | Asignaciones genéricas por tipo de recurso, ledger por categorías, sistemas registrables. |
| Determinismo roto por iteración de diccionarios o floats | Ids ordenados al iterar, enteros en el estado, prueba de hash del log. |
| Tipografías y licencias | Solo fuentes OFL (IBM Plex) incluidas en el repositorio con su licencia. |
| Proyecto no versionado (no hay repositorio git) | Recomendado `git init` antes de la fase 2. |
