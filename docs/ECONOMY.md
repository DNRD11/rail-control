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
| Precio medio por viajero-km | 0,10 € |
| Coste de explotación por km y vehículo | 12 € |
| Coste de personal por hora (maquinista / interventor) | 60 € / 40 € |
| Canon ordinario por km de servicio | 4 € |
| Coste fijo de reparación en ruta | 3 000 € |
| Coste de rescate (retirada de material averiado) | 8 000 € |
| Movilización de reserva | 2 500 € + coste por km en vacío |

## 5. Indicadores

- **Calidad del servicio (0-100)**: media ponderada por viajeros de la puntualidad en destino (100 en hora, 70 `MINOR`, 40 `MAJOR`, 0 `SEVERE`/cancelado).
- **Percepción (0-100)**: parte de 75; penalizaciones por minutos de retraso × afectados, cancelaciones y **falta de información**; bonificaciones por informar pronto (antes de N minutos desde la incidencia) y por mantener la continuidad del viaje. Valores en `perception.json`.
- **Resultado económico (€)**: suma del libro.

## 6. Equilibrado de la avería (objetivo de diseño)

Ninguna opción debe dominar. Tabla objetivo para la avería de 3103 (a validar con simulación en la fase 6):

| Contexto | Esperar | Sustituir | Cancelar |
|---|---|---|---|
| Reparación corta (≈ 20 min), margen de rotación 30 min | **Mejor**: 3105 casi no se afecta | Caro e innecesario | Pésimo |
| Reparación larga (≈ 60-90 min), reserva en ZAR | Indemnizaciones en 3103 y 3105 | **Mejor**: protege 3105, gasta la reserva | Malo |
| Reparación larga, reserva ya consumida | Única opción razonable o… | No disponible | …cancelar 3103 y proteger 3105 con otro material si existe |
| Baja ocupación, hora tardía | Aceptable | Coste desproporcionado | Puede ser razonable |

La incertidumbre del tiempo de reparación (rango, no valor exacto) es la clave para que la decisión no sea obvia.

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
