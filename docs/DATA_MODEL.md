# Modelo de datos

Entidades, relaciones y formato de datos. Reglas temporales en [SIMULATION.md](SIMULATION.md); economía en [ECONOMY.md](ECONOMY.md).

Convenciones: ids `StringName` legibles y estables (`"svc_3103"`, `"veh_v2"`, `"stf_d03"`); horas en `int` segundos desde las 00:00 de la jornada (en JSON se escriben como `"07:00"` o `"07:00:30"`); enums en `UPPER_SNAKE`.

## 1. Mapa de relaciones

```
Line 1───* Station (ordenadas, km)        VehicleClass 1───* Vehicle
Line 1───* Section (tramo entre estaciones adyacentes)
                                           Composition *───* Vehicle   (CompositionMember con posición y periodo)
Service 1───* ServiceStop (itinerario: parada o paso)
Service 1───* ResourceAssignment *───1 recurso { Composition | Vehicle | StaffMember | (futuro) RoadVehicle… }
Service 1───1 ServicePassengerLoad
Service *───* Incident   (Incident.affected_service_ids; Service.incident_ids)
Incident 1───* DecisionOption ; Incident 0..1── Decision tomada
Incident *───* AlternativeTransportPlan (futuro)
LedgerEntry *───1 referencia { Service | Incident | Pat | Day }
OperationalLog 1───* LogEntry (historial)
```

## 2. Red

| Entidad | Campos |
|---|---|
| `Line` | `id`, `name`, `station_ids: Array[StringName]` (orden canónico), `section_ids` |
| `Station` | `id`, `code` (MAD…), `name`, `km: float`, `min_dwell_s`, `min_turnaround_s`, `is_depot: bool`, `schematic_label` |
| `Section` | `id`, `from_station_id`, `to_station_id`, `length_km`, `run_time_s` (sin parada), `stop_penalty_s` (pérdida por parar), `track_count` |

El sentido se expresa como `Direction.ASCENDING` (orden de la línea, MAD→BCN) o `DESCENDING`. Una futura red con ramales usará varias `Line` que comparten `Station`; los servicios definen su itinerario como lista de paradas, no como «línea + sentido», para poder atravesar varias líneas.

## 3. Servicios

### `Service`

| Campo | Tipo | Notas |
|---|---|---|
| `id`, `code` | StringName, String | `svc_3103`, `"3103"` |
| `kind` | `ServiceKind` | `COMMERCIAL`, `SPECIAL` (PAT/futuro), `EMPTY_RUN` (posicionamiento en vacío) |
| `origin_station_id`, `destination_station_id` | StringName | |
| `stops` | `Array[ServiceStop]` | itinerario completo, incluidas estaciones de paso |
| `status` | `ServiceStatus` | `SCHEDULED`, `BOARDING`, `RUNNING`, `STOPPED_AT_STATION`, `HELD` (detenido en plena vía), `TERMINATED`, `CANCELLED`, `PARTIALLY_CANCELLED` |
| `passengers` | `ServicePassengerLoad` | ver §6 |
| `incident_ids` | `Array[StringName]` | historial de incidencias |
| `origin_ref` | StringName | para servicios especiales: id del PAT que lo creó |

**No hay campos de recurso en `Service`**. Las consultas «qué composición lleva» o «quién conduce ahora» se resuelven sobre las asignaciones: `world.assignments.for_segment(service_id, type, segment)` (recursos que cubren un segmento) o `at_stop(service_id, type, stop_index)` (en un relevo aparecen ambos).

### `ServiceStop`

| Campo | Notas |
|---|---|
| `station_id`, `index` | posición en el itinerario |
| `stop_type` | `ORIGIN`, `STOP`, `PASS`, `DESTINATION` |
| `sched_arr`, `sched_dep` | horario programado (`-1` si no aplica) |
| `est_arr`, `est_dep` | horario estimado vigente (lo recalcula la simulación) |
| `act_arr`, `act_dep` | horario real (`-1` hasta que ocurre) |
| `min_dwell_s` | mínimo de parada |
| `status` | `PENDING`, `ARRIVED`, `DEPARTED`, `PASSED`, `SKIPPED`, `CANCELLED` |

Retraso de un servicio en un instante = `est − sched` del próximo evento pendiente (o `act − sched` del último ocurrido).

## 4. Material: vehículos, composiciones y asignaciones

Tres conceptos separados:

1. **Vehículo (`Vehicle`)**: recurso físico individual.
2. **Composición (`Composition`)**: agrupación de vehículos que circulan acoplados durante un periodo. Puede formarse, acoplarse o dividirse.
3. **Asignación (`ResourceAssignment`)**: vincula una composición (o, excepcionalmente, un vehículo) a un servicio en un tramo y horario.

| Entidad | Campos |
|---|---|
| `VehicleClass` | `id`, `name` (serie ficticia), `seats`, `max_speed_kmh`, `can_couple`, `max_coupled`, `cost_per_km`, `length_m` |
| `Vehicle` | `id`, `number`, `class_id`, `status` (`AVAILABLE`, `IN_SERVICE`, `RESERVE`, `FAILED`, `UNDER_REPAIR`, `MAINTENANCE`, `OUT_OF_SERVICE`), `location_station_id` (último conocido), `km_since_maintenance`, `fault_ids` |
| `Composition` | `id`, `members: Array[CompositionMember]`, `formed_at`, `dissolved_at` (`-1` = vigente), `status` |
| `CompositionMember` | `vehicle_id`, `position` (1 = cabeza), `from_time`, `to_time` |

La capacidad de un servicio en un tramo = suma de plazas de los vehículos de las composiciones asignadas a ese tramo. Una composición doble (V3+V4) es **una** composición con dos miembros; acoplar en ruta = cerrar una composición y abrir otra con más miembros.

## 5. Personal

| Entidad | Campos |
|---|---|
| `StaffMember` | `id`, `name`, `role` (`DRIVER` = maquinista, `CONDUCTOR` = interventor), `base_station_id`, `shift_start`, `shift_end`, `qualifications: Array[StringName]` (series de material, líneas — preparado, no validado en el MVP), `status` (`AVAILABLE`, `ON_DUTY`, `RESTING`, `ABSENT`) |
| `Shift` (futuro) | `id`, `staff_id`, `segments` (servicio, viaje como pasajero, descanso, reserva) — permitirá normativa laboral |

## 6. Asignaciones de recursos

### `ResourceAssignment`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | StringName | |
| `service_id` | StringName | |
| `resource_type` | `ResourceType` | `COMPOSITION`, `VEHICLE`, `DRIVER`, `CONDUCTOR`; futuro: `ROAD_VEHICLE`, `TAXI`… |
| `resource_id` | StringName | |
| `role` | StringName | `LEAD`, `ASSISTANT`, `CHIEF_CONDUCTOR`… (opcional) |
| `from_stop_index`, `to_stop_index` | int | tramo del itinerario cubierto (permite relevos) |
| `from_station_id`, `to_station_id` | StringName | redundantes y validados, para legibilidad y consultas |
| `planned_start`, `planned_end` | int | horario planificado |
| `actual_start`, `actual_end` | int | `-1` hasta que ocurre |
| `status` | `AssignmentStatus` | `PLANNED`, `ACTIVE`, `COMPLETED`, `CANCELLED`, `REPLACED` |
| `source` | `AssignmentSource` | `PLAN`, `PLAYER`, `INCIDENT_REPLACEMENT`, `PAT` |
| `replaces_assignment_id` | StringName | trazabilidad de sustituciones |

Ejemplo — 3101 MAD→BCN (itinerario de 7 puntos, índice 3 = Zaragoza) con relevo de maquinista en Zaragoza y dos interventores, uno de ellos solo hasta Zaragoza:

```json
[
  {"id":"asg_3101_c1","service_id":"svc_3101","resource_type":"COMPOSITION","resource_id":"cmp_c1","from_stop_index":0,"to_stop_index":6},
  {"id":"asg_3101_d1","service_id":"svc_3101","resource_type":"DRIVER","resource_id":"stf_d01","from_stop_index":0,"to_stop_index":3},
  {"id":"asg_3101_d2","service_id":"svc_3101","resource_type":"DRIVER","resource_id":"stf_d04","from_stop_index":3,"to_stop_index":6},
  {"id":"asg_3101_i1","service_id":"svc_3101","resource_type":"CONDUCTOR","resource_id":"stf_c01","from_stop_index":0,"to_stop_index":6,"role":"CHIEF_CONDUCTOR"},
  {"id":"asg_3101_i2","service_id":"svc_3101","resource_type":"CONDUCTOR","resource_id":"stf_c04","from_stop_index":0,"to_stop_index":3}
]
```

`planned_start/end` se derivan del horario de las paradas si no se indican.

### Reglas de validación (al cargar y al aplicar comandos)

| Regla | Severidad |
|---|---|
| Un recurso no puede tener dos asignaciones con intervalos solapados | error |
| Continuidad espacial: la siguiente asignación de un recurso empieza en la estación donde terminó la anterior (o hay un `EMPTY_RUN` / desplazamiento) | error |
| Tiempo mínimo de rotación de material (`min_turnaround_s` por estación/serie) | aviso (genera riesgo de propagación) |
| Cada tramo de un servicio comercial tiene al menos una composición y un maquinista | error |
| Interventores mínimos por tramo según la regla del escenario | aviso |
| Asignación dentro del turno del personal (`shift_start..shift_end`) | aviso |
| Vehículo no disponible (`FAILED`, `MAINTENANCE`) asignado | error |
| `from_stop_index < to_stop_index` y dentro del itinerario | error |

### Dependencias derivadas: `RotationGraph`

Ordenando las asignaciones de cada recurso por `planned_start`, se obtiene su **cadena** (rotación de material o secuencia de servicios de un maquinista). Cada par consecutivo genera una arista `servicio A → servicio B` con su margen (`B.dep − A.arr − min_turnaround`). Estas aristas son las que propagan retrasos ([SIMULATION.md §5](SIMULATION.md)). No se almacenan: se recalculan al cambiar asignaciones.

## 7. Viajeros (agregados)

`ServicePassengerLoad`: `booked: int`, `boardings_by_stop: Dictionary[int, int]`, `alightings_by_stop: Dictionary[int, int]`, y contadores derivados: `affected`, `continuing`, `needing_alternative`, `compensation_eligible`, `informed: bool`, `last_info_time`.

`PassengerInfoMessage`: `id`, `service_id`, `channel` (`ON_BOARD`, `STATION`, `APP`), `template_id`, `time`, `incident_id`.

## 8. Incidencias y decisiones

| Entidad | Campos |
|---|---|
| `IncidentType` (datos) | `id` (`ROLLING_STOCK_FAILURE`…), `category` (`ROLLING_STOCK`, `STAFF`, `INFRASTRUCTURE`, `WEATHER`, `SECURITY`, `PASSENGER`), `severity_levels`, `repair_time_range_s`, `probability_per_hour`, `options: Array[option_type]` |
| `Incident` | `id`, `type_id`, `severity`, `status` (`DETECTED`, `AWAITING_DECISION`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`), `detected_at`, `resolved_at`, `location` (`station_id` o `section_id` + fracción), `affected_service_ids`, `affected_resource_refs`, `options: Array[DecisionOption]`, `decision_id`, `estimated_repair_s` (oculto, se muestra como rango), `log` |
| `DecisionOption` | `option_type` (`WAIT_REPAIR`, `SUBSTITUTE_ROLLING_STOCK`, `CANCEL_SERVICE`; futuro: `CREATE_PAT`, `REQUEST_SPECIAL_SERVICE`…), `available: bool`, `unavailable_reason`, `preview` (estimaciones mostradas al jugador: retraso, afectados, coste) , `params` (p. ej. vehículo de reserva propuesto) |
| `Decision` | `id`, `incident_id`, `option_type`, `params`, `time`, `outcome_refs` (eventos, asignaciones y ledger generados) |

Los efectos de una decisión se expresan como **comandos y eventos** ordinarios (nueva asignación, retraso, cancelación, entradas de ledger), para que cualquier tipo de incidencia futura reutilice los mismos mecanismos.

## 9. Economía

`LedgerEntry`: `id`, `time`, `category` (ver [ECONOMY.md](ECONOMY.md)), `amount_cents: int` (positivo = ingreso, negativo = coste), `ref_type`, `ref_id`, `description_key`, `details: Dictionary`.

`ChargeRule` (canon / tarifas configurables, futuro): `id`, `applies_to` (`SPECIAL_SERVICE`, `COMMERCIAL`, …), `method` (`FIXED`, `PER_KM`, `PER_SECTION`, `PER_TIME_BAND`, `SURCHARGE`), `amount`, `section_ids`, `time_bands`, `conditions`.

## 10. PAT — diseño futuro (no implementado en el MVP)

Separación conceptual estricta: **incidencia** (causa) → **PAT** (plan) → **recursos** (medios) → **viajeros** (distribución) → **costes** (ledger).

```
Incident *──* AlternativeTransportPlan 1──* PatLeg ──1 recurso
                         │                    ├─ ROAD_BUS / TAXI / OTHER_ROAD → RoadTransportResource (proveedor, capacidad, coste)
                         │                    └─ RAIL_SPECIAL → Service(kind = SPECIAL) + ResourceAssignment (material, maquinista, interventores)
                         │                                         └─ InfrastructureCapacityRequest → administrador de infraestructuras
                         ├──* PassengerAllocation (from_service_id, from_station, pat_leg_id, count)
                         └──* LedgerEntry (PAT_ROAD, SPECIAL_SERVICE_OPERATION, INFRA_CHARGE_EXTRA, …)
```

| Entidad | Campos clave |
|---|---|
| `AlternativeTransportPlan` | `id`, `incident_ids`, `status` (`DRAFT`, `REQUESTED`, `ACTIVE`, `COMPLETED`, `CANCELLED`), `created_at`, `closed_at`, `legs`, `allocations`, `ledger_entry_ids` |
| `PatLeg` | `id`, `mode` (`ROAD_BUS`, `TAXI`, `OTHER_ROAD`, `RAIL_SPECIAL`), `origin_station_id`, `destination_station_id`, `intermediate_stops`, `departure`, `arrival`, `capacity`, `resource_ref` (proveedor de carretera o `service_id` especial), `status` |
| `RoadTransportResource` | `id`, `provider`, `mode`, `capacity`, `availability_window`, `mobilization_time_s`, `cost_model` (fijo, por km, por hora) |
| `InfrastructureCapacityRequest` | `id`, `service_id`, `sections`, `time_window`, `status` (`PENDING`, `APPROVED`, `REJECTED`, `MODIFIED`), `response_time_s`, `charge_rule_ids` |
| `PassengerAllocation` | `from_service_id`, `from_stop_index`, `pat_leg_id`, `count` |

Decisiones del MVP que dejan esto preparado: `Service.kind = SPECIAL` y `origin_ref`; `ResourceType` y `AssignmentSource` extensibles; contadores `needing_alternative` en viajeros; categorías de ledger reservadas; `DecisionOption.option_type` abierto; `ChargeRule` definido en datos.

## 11. Formato de datos (JSON)

Un escenario es una carpeta en `data/scenarios/<id>/`:

| Archivo | Contenido |
|---|---|
| `scenario.json` | metadatos, `line_ids`, `day_start`, `day_end`, `time_scale` (s de simulación por s real a x1), `seed`, incidencias guionizadas, reglas de reglas a usar |
| `services.json` | servicios con itinerario (`stops` con `station`, `type`, horas programadas) |
| `vehicles.json`, `compositions.json` | flota y composiciones iniciales |
| `staff.json` | maquinistas e interventores |
| `assignments.json` | asignaciones planificadas |
| `passengers.json` | viajeros previstos por servicio y distribución por parada |

Cada archivo lleva `"schema_version": 1`. `DataValidator` comprueba tipos, referencias cruzadas y las reglas de §6 y devuelve un `ValidationReport` con errores y avisos.
