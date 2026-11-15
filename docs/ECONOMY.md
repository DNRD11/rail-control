# Economía, viajeros e indicadores

Las cifras y criterios de este documento son **mecánicas del simulador**, configurables en `data/rules/*.json`. No reproducen tarifas, cánones ni compromisos de puntualidad reales de ninguna operadora ni del administrador de infraestructuras.

Entidades: [DATA_MODEL.md §7, §9, §10](DATA_MODEL.md). Eventos: [SIMULATION.md](SIMULATION.md).

## 1. Categorías del libro (`LedgerEntry.category`)

| Categoría | MVP | Descripción |
|---|---|---|
| `REVENUE` | ✔ | ingreso simplificado por viajero transportado (precio medio por tramo) |
| `OPERATING_COST` | ✔ | coste ordinario por km de servicio (energía, mantenimiento) |
| `STAFF_COST` | ✔ | coste por hora de maquinista/interventor asignado (simplificado) |
| `INFRA_CHARGE_ORDINARY` | ✔ | canon ordinario por km de servicio programado (valor fijo simple) |
| `INCIDENT_COST` | ✔ | reparación, rescate, horas extra derivadas |
| `SUBSTITUTION_COST` | ✔ | movilización de material de reserva, posicionamiento en vacío, transbordo |
| `COMPENSATION` | ✔ | indemnizaciones a viajeros |
| `PAT_ROAD` | — | autobuses, taxis, otros medios |
| `SPECIAL_SERVICE_OPERATION` | — | material y personal de un servicio especial |
| `INFRA_CHARGE_EXTRA` | — | canon adicional por circulación especial |

## 2. Viajeros agregados (MVP)

- `booked` por servicio y distribución de subidas/bajadas por parada (`passengers.json`).
- **Afectados**: a bordo o pendientes de subir cuando un servicio sufre retraso `≥ MINOR` o cancelación.
- **Continúan**: afectados que siguen en el servicio (o en el material sustituto).
- **Necesitan alternativa**: viajeros de un servicio cancelado (total o parcialmente). En el MVP se contabilizan, generan coste de indemnización completa y fuerte impacto en percepción; en el futuro serán la entrada del PAT.
- **Con derecho a indemnización**: según los umbrales de §3 aplicados al retraso **en destino** de cada viajero (aproximado por parada de bajada).

## 3. Indemnizaciones (configurables)

`data/rules/compensation.json` (valores iniciales de juego):

| Retraso en llegada | % del precio medio del trayecto |
|---|---|
| < 30 min | 0 % |
| 30 – 59 min | 25 % |
| 60 – 89 min | 50 % |
| ≥ 90 min o cancelación sin alternativa | 100 % |

## 4. Valores iniciales propuestos (a equilibrar)

| Parámetro | Valor |
|---|---|
| Precio medio por viajero-km | 0,10 € (`economy.json`, 10 céntimos) |
| Coste de explotación por km y vehículo | 12 € |
| Coste de personal por hora (maquinista / interventor) | 60 € / 40 € |
| Canon ordinario por km de servicio | 4 € |
| Coste fijo de reparación en ruta | 3 000 € |
| Coste de rescate (retirada de material averiado) | 8 000 € |
| Movilización de reserva | 2 500 € + 12 € por km en vacío |
| Rango de reparación de avería de material | 1 200 – 5 400 s (20 – 90 min) |

Los costes de incidencia viven en `data/rules/incidents.json` (`costs.*`, céntimos); los ordinarios en `data/rules/economy.json`; los umbrales en `compensation.json`; la percepción en `perception.json`. Orden de magnitud: sustituir cuesta 8 000 € de rescate + 2 500 € de movilización + 12 €/km en vacío (≈ 11 100 € con la reserva de Zaragoza); esperar cuesta 3 000 € más las indemnizaciones por retraso en el servicio y en los que heredan el retraso por rotación del material. El billete medio del 3103 (307 km) es ≈ 31 €, unos 8 900 € por servicio de 290 viajeros.

**Liquidación de un servicio** (`EconomySystem`, al terminar o cancelarse; al cierre de jornada se liquidan los pendientes con sus horas estimadas):
- Ingreso = billete total (viajeros-km × precio) × parte de viajeros que llegan a destino.
- Explotación = vehículos-km (composición asignada, sin contar asignaciones sustituidas) × coste/km. Canon = km recorridos × canon/km. Personal = horas reales de cada asignación (incluye el retraso) × tarifa de maquinista o interventor.
- Indemnización = billete total × Σ(viajeros de cada parada de bajada × % del tramo de retraso en esa parada) / reservados. Cancelación (paradas de bajada no alcanzadas) = `cancellation_percent` (100 %), y esos viajeros cuentan como «necesitan alternativa». Los ingresos de viajeros no transportados no se cobran; su importe se acumula en `lost_revenue_cents` (informativo, no es un apunte).
- Los costes de la decisión (`Decision.cost_lines`) se vuelcan al tomarla con `ref_type = INCIDENT`; el resto, con `ref_type = SERVICE`.
- Simplificación: al cancelar no se cuenta la fracción del tramo en curso (solo paradas alcanzadas).

## 5. Indicadores

- **Calidad del servicio (0-100)**: media ponderada por **todos** los viajeros previstos (denominador fijo: cancelar no sube la media) de la puntualidad en destino: 100 en hora (≤ 3 min), 85 `MINOR`, 65 `MAJOR`, 30 `SEVERE`, 0 cancelado. Usa la hora real si la parada se alcanzó y la estimada si no.
- **Percepción (0-100)**: parte de 75 y suma o resta, con coeficientes «por 1000 viajeros» de `perception.json`: −0,3 por 1000 viajeros-minuto de retraso (sobre la tolerancia de 3 min); −90 por 1000 viajeros que necesitan alternativa; −25 por 1000 afectados sin informar (ventana de 600 s desde que quedan afectados; fuera de ventana se aplica el 50 %); +15 por 1000 afectados informados dentro de la ventana; +10 por 1000 afectados que continúan en un servicio con incidencia no cancelado. Se informa con `InformPassengersCommand(service_id, incident_id)`, una vez por servicio.
- **Resultado económico (€)**: suma del libro.

## 6. Equilibrado de la avería (resultados reales, Fase 6)

Resultado del día completo (€, suma del libro) / percepción, avería del 3103 a las 08:12, informando al 3103 a tiempo, reparación fija. Línea base sin avería: ≈ 53 460 €. Precio 0,10 €/viajero-km, umbrales de §3 y costes de §4. Simulado con `SimFixture.session_with_incident` (semilla 12345).

| Contexto | Esperar | Sustituir | Cancelar |
|---|---|---|---|
| Reparación 20 min, reserva en ZAR | **53 462 / 65,9** | 43 375 / 63,1 | 30 594 / 53,3 |
| Reparación 30 min | **51 516 / 63,3** | 43 375 / 63,1 | 30 594 / 53,3 |
| Reparación 45 min | 45 766 / 43,7 | 43 375 / **63,1** | 30 594 / 53,3 |
| Reparación 60 min | 43 809 / 29,3 | 43 375 / **63,1** | 30 594 / 53,3 |
| Reparación 75 min | 32 252 / 21,5 | **43 375 / 63,1** | 30 594 / 53,3 |
| Reparación 90 min | 26 515 / 13,6 | **43 375 / 63,1** | 30 594 / 53,3 |
| **Reserva consumida**, cualquier reparación | 53 462 (20 min) … 26 515 (90 min): única opción razonable | no disponible | −12 708 / 0 (cancela también 4 servicios dependientes) |
| **Baja ocupación** (3103 con 40 viajeros), 90 min | 26 515 / 13,9 | 38 404 / 58,9 | 37 222 / **72,0** |
| Baja ocupación, 20 min | **46 834 / 60,9** | 38 404 / 58,9 | 37 222 / 72,0 |

Lectura:
- **Esperar** gana con reparaciones cortas (< 40 min): no indemniza y cuesta solo 3 000 €. A partir de ≈ 45 min el retraso se hereda por la rotación del material (hasta 5 servicios más) y la factura crece.
- **Sustituir** cuesta un fijo (≈ 11 100 € más ≈ 1 900 € de indemnizaciones residuales) que no depende del tiempo de reparación: es un seguro que compensa desde ≈ 50 min y mantiene la percepción en 63. Con reparación uniforme entre 20 y 90 min el resultado medio de esperar (≈ 42 000 €) es casi igual al de sustituir (43 375 €), pero esperar tiene una cola de riesgo (90 min: 26 515 €) y peor percepción: esa es la tensión buscada.
- **Reserva consumida**: solo queda esperar; cancelar arrastra a los servicios que usan el mismo material y es pésimo.
- **Cancelar** con la ocupación normal del escenario está **dominado**: sustituir es mejor en resultado y en percepción en todos los contextos con reserva (cancelar paga rescate y el 100 % del billete, y pierde el ingreso). Solo es no dominado con **baja ocupación** del servicio averiado: resultado casi igual al de sustituir (−1 200 €) y percepción más alta (72 frente a 58,9), pues no hay retrasos en cadena ni apenas viajeros a indemnizar. Ese contexto se reproduce reduciendo `booked` del 3103 (no está en los datos del escenario). Hallazgo abierto: para que cancelar compita con la ocupación normal hacen falta mecánicas futuras (un PAT que absorba a los viajeros, una segunda reserva distinta de la usada para sustituir, o `seats_short` que deje viajeros sin plaza al sustituir). `cancellation_percent` es configurable, pero 100 % es el criterio de §3.

Cancelar no sube la calidad (denominador fijo): 91,7 frente a 94,6 de esperar 25 min.

La incertidumbre del tiempo de reparación (rango 20–90 min, no un valor exacto) es la clave para que la decisión no sea obvia.

## 7. Futuro: PAT, servicios especiales y cánones

**Costes de un PAT** = Σ recursos por carretera (fijo de movilización + por km o por hora, según proveedor) + Σ servicios ferroviarios especiales + Σ cánones adicionales.

**Servicio ferroviario especial** (`Service.kind = SPECIAL`):
- `SPECIAL_SERVICE_OPERATION`: material (coste por km), personal (horas, posibles horas extra), posicionamiento en vacío.
- `INFRA_CHARGE_EXTRA`: calculado con `ChargeRule` del archivo `infra_charges.json`, combinables:

| Método | Ejemplo de configuración |
|---|---|
| `FIXED` | 1 500 € por circulación especial solicitada |
| `PER_KM` | 6 € por km recorrido |
| `PER_SECTION` | suplemento por utilizar tramos concretos (p. ej. acceso a grandes estaciones) |
| `PER_TIME_BAND` | multiplicador en horas punta |
| `SURCHARGE` | suplemento por solicitud urgente (< X min de antelación) |

No todos los servicios especiales tienen el mismo canon: las reglas se seleccionan por condiciones (tramos, franja, antelación, tipo de servicio). La autorización del administrador de infraestructuras (`InfrastructureCapacityRequest`) puede retrasar, modificar o denegar el servicio especial, lo que hace que el PAT por carretera compita con él en tiempo y coste.

## 8. Contabilización de incidencias: Fase 5 frente a Fase 6

**Ya en Fase 5** (`IncidentEffects`): cada decisión deja sus costes en `Decision.cost_lines`, lista de `{category, key, amount_cents}` con importe **negativo** en céntimos:

| Opción | Líneas |
|---|---|
| `WAIT_REPAIR` | `INCIDENT_COST / repair_on_route` |
| `SUBSTITUTE_ROLLING_STOCK` | `INCIDENT_COST / rescue`, `SUBSTITUTION_COST / reserve_mobilization`, `SUBSTITUTION_COST / empty_run` (km × `empty_run_per_km_cents`) |
| `CANCEL_SERVICE` | `INCIDENT_COST / rescue` y, si la reserva cubre dependientes, `SUBSTITUTION_COST / reserve_mobilization` |

`OptionPreview.cost_cents` muestra al jugador el total estimado antes de decidir. **No se escribe aún en ningún libro**: no existe `Ledger` hasta la Fase 6.

**Fase 6 (hecha)**: `EconomySystem` escucha `incident_changed` y vuelca `Decision.cost_lines` al `Ledger` (`ref_type = INCIDENT`, `ref_id = incident_id`, `description_key = incident_<key>`); al terminar o cancelarse un servicio (`service_updated`) lo liquida (ver §4). Consultas: `session.query_ledger()`, `query_indicators()`, `query_service_passengers(id)`. Señales: `ledger_changed(entry)`, `indicators_changed()`.
