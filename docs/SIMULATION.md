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

Clasificación del retraso (umbrales en `data/rules/perception.json`): `ON_TIME` ≤ 3 min, `MINOR` ≤ 15 min, `MAJOR` ≤ 60 min, `SEVERE` > 60 min.

## 6. Incidencias: avería de material (MVP)

### Ciclo

```
INCIDENT_TRIGGER → Incident(DETECTED) → servicio HELD en tramo o estación
   → opciones calculadas con previsualización → AWAITING_DECISION (pausa automática opcional)
   → Decision (jugador o DECISION_TIMEOUT) → efectos → IN_PROGRESS → RESOLVED → CLOSED (registro)
```

- **Origen**: guionizada en `scenario.json` (`{ "service": "svc_3103", "at_section": "CAT-ZAR", "fraction": 0.4, "repair_s": [1500, 3600] }`) o aleatoria según `probability_per_hour` con el RNG de la sesión.
- El tiempo de reparación real se sortea al crear la incidencia; el jugador solo ve un **rango** (incertidumbre deliberada).

### Opciones

| Opción | Disponible si | Efectos simulados |
|---|---|---|
| `WAIT_REPAIR` | siempre | `INCIDENT_RESOLVED` a `now + repair_s` (sorteado); el servicio reanuda con retraso; propagación |
| `SUBSTITUTE_ROLLING_STOCK` | existe composición/vehículo `RESERVE`/`AVAILABLE` y maquinista disponible | servicio `EMPTY_RUN` de posicionamiento desde la estación de la reserva hasta el punto de la avería (o la siguiente estación), transbordo (`transfer_s`), nueva asignación `source = INCIDENT_REPLACEMENT` para el resto del itinerario, asignación original `REPLACED`; el material averiado pasa a `FAILED` y queda fuera de rotación hasta reparación/retirada; se re-planifica la cadena dependiente |
| `CANCEL_SERVICE` | siempre | servicio `CANCELLED`/`PARTIALLY_CANCELLED`; viajeros a bordo y pendientes ⇒ `needing_alternative`; material averiado retirado (rescate); servicios dependientes del material quedan **sin composición** y generan aviso de decisión |

En el MVP, si un servicio dependiente se queda sin material, el jugador puede asignarle otra composición disponible o cancelarlo (comandos ya existentes). PAT y servicio especial se añadirán como nuevas opciones sin cambiar el ciclo.

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
