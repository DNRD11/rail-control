# Simulación: reloj, eventos, circulación y reglas

Entidades en [DATA_MODEL.md](DATA_MODEL.md); arquitectura en [ARCHITECTURE.md](ARCHITECTURE.md); efectos económicos en [ECONOMY.md](ECONOMY.md).

## 1. Principios

- La simulación es `RefCounted`, headless, y **no conoce** la interfaz, los FPS ni las animaciones.
- Estado temporal en **segundos enteros** desde las 00:00 de la jornada.
- **Determinista**: mismo escenario + misma semilla + mismos comandos a la misma hora de simulación ⇒ mismo resultado, a cualquier velocidad y con cualquier tamaño de paso.

## 2. Reloj (`SimClock`)

| Campo | Notas |
|---|---|
| `now: int` | hora de simulación |
| `speed: int` | `0` (pausa), `1`, `2`, `4` |
| `time_scale: int` | segundos de simulación por segundo real a x1 (escenario MVP: **30**, es decir, 1 h de jornada ≈ 2 min reales a x1 y 30 s a x4) |
| `day_start`, `day_end` | límites de la jornada |

`SimulationHost` (Node) acumula `delta` real: `acc += delta * time_scale * speed`; toma la parte entera `n = floor(acc)`, resta `n` y llama a `session.advance_seconds(n)`. Con la pausa (`speed = 0`) no se llama a la sesión: **la pausa es real**, el estado no cambia. El resto fraccional solo se usa para interpolar la posición visual.

Por robustez, `advance_seconds` limita el máximo por frame (p. ej. 600 s) para evitar saltos tras una pausa del sistema operativo; el exceso se procesa en frames siguientes.

## 3. Cola de eventos (`EventQueue`)

Montículo mínimo ordenado por `(time, priority, seq)`; `seq` es un contador creciente que garantiza orden estable.

`advance_seconds(n)`: `target = now + n`; mientras el primer evento tenga `time ≤ target`: `now = event.time`, despachar. Al final `now = target`. Así, avanzar 600 s de golpe o 600 × 1 s produce el mismo resultado.

### Tipos de evento (`SimEventType`)

| Evento | Prioridad | Efecto principal |
|---|---|---|
| `INCIDENT_RESOLVED` | 10 | libera el servicio/recurso afectado |
| `SERVICE_ARRIVAL` | 20 | registra `act_arr`, inicia parada o finaliza servicio |
| `SERVICE_PASS` | 25 | registra paso sin parada |
| `STOP_END` / `SERVICE_DEPARTURE` | 30 | registra `act_dep`, programa la siguiente llegada/paso |
| `ASSIGNMENT_START` / `ASSIGNMENT_END` | 40 | cambia de estado recursos y asignaciones; relevos |
| `DELAY_APPLIED` | 50 | suma un retraso a un servicio y recalcula estimaciones |
| `INCIDENT_TRIGGER` | 60 | crea una incidencia (guionizada o aleatoria) |
| `DECISION_TIMEOUT` | 70 | si el jugador no decide, se aplica la opción por defecto |
| `SERVICE_CANCELLED` | 80 | cancela total o parcialmente |
| `PASSENGER_INFO_SENT` | 90 | efecto en percepción |
| `DAY_END` | 100 | cierra la jornada y construye el informe |

La lista es extensible: cada sistema declara los tipos que maneja.

## 4. Circulación

Un servicio en marcha está siempre en uno de dos estados espaciales:

- **En estación** `i` (entre `act_arr` y `act_dep`).
- **En tramo** entre los puntos `i` e `i+1` del itinerario, con `leg_start` (salida o paso por `i`) y `leg_end_est` (llegada o paso estimado en `i+1`).

Posición: `fraction = clamp((now − leg_start) / (leg_end_est − leg_start), 0, 1)` sobre la distancia en km del tramo. Si el servicio está `HELD` (detenido por avería), la fracción se congela en el valor del momento de la detención y `leg_end_est` se desplaza.

**Tiempo de recorrido** entre dos puntos = suma de `run_time_s` de las secciones + `stop_penalty_s` si se para en el origen o el destino del tramo. Las horas programadas de `services.json` deben ser coherentes con esto; el validador avisa si difieren más de un umbral, y la simulación usa los tiempos de las secciones para las **estimaciones** cuando hay retraso.

**Recuperación de retraso**: cada servicio tiene un margen de recuperación (`recovery_pct`, p. ej. 3 % del tiempo de recorrido) que permite reducir retraso en marcha; las paradas pueden recortarse hasta `min_dwell_s`.

**Salida**: un servicio sale a `max(sched_dep, ready_time)`, donde `ready_time` es el máximo entre: llegada de la composición asignada + `min_turnaround_s`, llegada de su maquinista + tiempo de toma de servicio, e interventores mínimos disponibles.

## 5. Retrasos y propagación

1. Un retraso entra por un evento (`DELAY_APPLIED`, avería, salida tardía).
2. Se recalculan `est_*` del servicio desde el punto actual.
3. El `RotationGraph` ([DATA_MODEL.md §6](DATA_MODEL.md)) da los servicios dependientes por material y personal. Para cada arista `A → B`: `ready_B = est_arr_A(fin de asignación) + turnaround`; si `ready_B > sched_dep_B`, `B` hereda `ready_B − sched_dep_B` de retraso estimado.
4. Se repite en cascada (en orden temporal, sin ciclos porque las cadenas son crecientes en el tiempo).
5. Las estimaciones se recalculan de nuevo cuando ocurren los hechos reales: la propagación es **predicción visible** para el jugador (p. ej. «3105: +18 min previstos por rotación de material»), no un hecho hasta que sucede.

**Implementación (Fase 4)**: `DelaySystem` maneja `DELAY_APPLIED` (`data.seconds`, `data.cause`, `data.recovery_pct` opcional, 0 por defecto). El retraso se suma al próximo punto pendiente (llegada, o salida si está detenido); en cada parada la espera se recorta hasta `min_dwell_s` (`est_dep = max(sched_dep, est_arr + min_dwell_s)`) y, si `recovery_pct > 0`, se recupera ese % del tiempo de recorrido programado de cada tramo (sin superar el retraso acumulado). Solo se retrasa (max con lo vigente). La propagación itera hasta punto fijo sobre los servicios aguas abajo ordenados por salida programada; si B ya salió del punto de relevo no se toca. `MovementSystem` programa siempre desde `est_*`; los eventos reprogramados se invalidan con `SimEvent.cancelled` (la sesión los descarta) y hay como mucho uno vigente por servicio. Log: `DELAY_APPLIED` y `DELAY_PROPAGATED` (`seconds`, `cause`, `source`, `resource`). `InjectDelayCommand` programa el evento a `now` y lo procesa de inmediato (`process_due_events`). Consultas: `delay_of`, `delay_info`, `query_service_position_at`, `query_scheduled_position`, `query_service_resources`, `query_service_chain`, `query_resource_states`, `query_service_summary`, `service_ids` (`SessionQueries`, `ResourceStateCalc`).

Clasificación del retraso (umbrales en `data/rules/perception.json`): `ON_TIME` ≤ 3 min, `MINOR` ≤ 15 min, `MAJOR` ≤ 60 min, `SEVERE` > 60 min.

## 6. Incidencias: avería de material (MVP)

### Ciclo

```
INCIDENT_TRIGGER → Incident(DETECTED) → servicio HELD en tramo o estación
   → opciones con previsualización → AWAITING_DECISION
   → Decision (jugador o tiempo agotado) → efectos → IN_PROGRESS → RESOLVED
```

`CLOSED` está reservado en el enum (archivo/registro final) y todavía no se usa.

- **Origen guionizado**: `scenario.json › scripted_incidents` (`id`, `type`, `service`, `section` + `time`, `severity`, `enabled`).
- **Origen aleatorio**: `scenario.rules.random_incidents` con `probability_per_hour` por tipo. Las tiradas se hacen **al arrancar** la sesión con el RNG con semilla (determinista) y programan `INCIDENT_TRIGGER`.
- El tiempo real de reparación (`repair_s`) se sortea al crear la incidencia dentro de `[repair_min_s, repair_max_s]` del tipo (1500–3600 s). El jugador y el log solo ven el **rango** (`repair_range_s`).
- **Retraso al detectar**: el servicio queda detenido y se aplica una cota inferior = `min(reparación mínima, transfer_s)`; el resto del retraso se aplica **al reanudar**. Así la propagación a dependientes es visible desde el principio sin adelantar información oculta.
- **Tiempo agotado**: si el jugador no decide en `decision_timeout_s` (900 s), se toma `default_option` (`WAIT_REPAIR`) con `Decision.automatic = true`.

### Opciones (implementación Fase 5)

| Opción | Disponible si | Efectos simulados |
|---|---|---|
| `WAIT_REPAIR` | siempre | `INCIDENT_RESOLVED` a `detected_at + repair_s`; el servicio reanuda con el retraso restante; propagación a dependientes. Coste `repair_on_route` |
| `SUBSTITUTE_ROLLING_STOCK` | hay vehículo de reserva con plazas (si no, `unavailable_reason`; `seats_short` informa del déficit) | La reserva trae **su propia tripulación**: el personal del servicio no se reasigna (simplificación MVP). Se crea la composición `cmp_res_<vehículo>`; se traspasan a ella el resto del servicio y **todos los servicios posteriores del material averiado**; las asignaciones originales pasan a `REPLACED`, las nuevas `source = INCIDENT_REPLACEMENT`. El servicio reanuda en `now + posicionamiento + transfer_s`. El material averiado queda `FAILED`. Log `SUBSTITUTION_DISPATCHED` |
| `CANCEL_SERVICE` | siempre | Servicio `PARTIALLY_CANCELLED` (ya había salido) o `CANCELLED`; viajeros a bordo y pendientes ⇒ `needing_alternative`. Los servicios dependientes pasan a la composición de reserva si esta cubre su estación de salida; si no, se cancelan. Coste de rescate |

**Posicionamiento en vacío**: se modela solo como tiempo (`km / positioning_speed_kmh`) y coste (`empty_run_per_km_cents`); **no se crea un `Service` `EMPTY_RUN`** (queda para fases futuras).

**Limitación conocida**: tras cancelar, el retraso previsto ya aplicado a los dependientes no se retrocede (permanece como estimación pesimista).

### Comando y log

`ResolveIncidentCommand(incident_id, option_type)` valida disponibilidad y aplica la decisión. Entradas de log nuevas: `INCIDENT_DETECTED`, `DECISION_TAKEN`, `INCIDENT_RESOLVED`, `INCIDENT_SKIPPED` (disparo ignorado, p. ej. servicio ya terminado o cancelado), `SUBSTITUTION_DISPATCHED`, `SERVICE_CANCELLED`.

Costes de las decisiones: ver [ECONOMY.md §8](ECONOMY.md). PAT y servicio especial se añadirán como nuevas opciones sin cambiar el ciclo.

## 7. Comandos del jugador

`SetSpeedCommand`, `ResolveIncidentCommand(incident_id, option_type, params)`, `CancelServiceCommand`, `ReassignResourceCommand`, `SendPassengerInfoCommand`. Cada comando se valida, se registra con `now` y se aplica dentro de la sesión; el log de comandos permite **repetir** una partida y es la base del guardado.

## 8. Log operativo

Cada hecho relevante (salida, llegada, paso, retraso, cambio de asignación, incidencia, decisión, cancelación, transacción) añade un `LogEntry { time, type, refs, data }`. Es el historial que consulta la UI y la fuente del informe final. La prueba de determinismo compara el hash de este log.

## 9. Escenario MVP: parámetros

| Parámetro | Valor inicial |
|---|---|
| Jornada | 06:00 – 15:00 |
| `time_scale` | 30 (≈ 18 min reales a x1, ≈ 4,5 min a x4) |
| `min_turnaround_s` | 1200 (20 min) en cabeceras, 900 en ZAR |
| `transfer_s` (transbordo en sustitución) | 900 |
| Semilla | fija por escenario, modificable en ajustes de depuración |

Todos los valores se ajustarán en el equilibrado (fases 5-6).

## Economía y viajeros (Fase 6)

`SimulationSession` conecta `service_updated` e `incident_changed` a `PassengerSystem` y `EconomySystem` (síncrono y determinista) y emite `ledger_changed(entry)` e `indicators_changed()`. `PASSENGER_INFO_SENT` (prioridad 90) lo programa `InformPassengersCommand` a la hora actual y lo procesa `PassengerSystem`. En `DAY_END` se liquidan los servicios sin terminar con horas estimadas. El rango de reparación de la avería de material pasa a 1 200 – 5 400 s. Detalle en [ECONOMY.md](ECONOMY.md).
