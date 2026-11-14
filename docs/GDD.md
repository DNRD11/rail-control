# GDD — Rail Control

Documento de diseño de juego. Detalle técnico en [ARCHITECTURE.md](ARCHITECTURE.md), entidades en [DATA_MODEL.md](DATA_MODEL.md), reglas temporales en [SIMULATION.md](SIMULATION.md), economía en [ECONOMY.md](ECONOMY.md) e identidad visual en [VISUAL_DIRECTION.md](VISUAL_DIRECTION.md).

## 1. Fantasía del jugador

Eres responsable de turno del **CGO** de una operadora ferroviaria de alta velocidad. No conduces ni construyes: **decides**. Ves la línea en un esquema vivo, los servicios avanzando, las alertas entrando. Cada decisión (esperar, sustituir material, cancelar, informar) tiene un coste en minutos, en viajeros afectados, en euros y en la confianza del público.

La infraestructura pertenece al **administrador de infraestructuras**: el jugador recibe sus restricciones e información, pero no la gestiona.

## 2. Pilares

1. **Sensación de CGO real**: interfaz de consola profesional, terminología ferroviaria correcta, información precisa.
2. **Consecuencias encadenadas**: un retraso se propaga por las rotaciones de material y los turnos de personal.
3. **Decisiones sin respuesta única**: la mejor opción depende del contexto (hora, reserva disponible, ocupación, tiempo de reparación).
4. **Claridad bajo presión**: en una pantalla táctil, de un vistazo, se entiende qué pasa y qué requiere atención.

## 3. Bucle de juego

```
Briefing de jornada → Operación en tiempo real (x1/x2/x4, pausa)
   → Alertas / incidencias → Análisis (detalle de servicio, recursos, afectados)
   → Decisión → Consecuencias (retrasos, viajeros, costes, percepción)
   → … → Cierre de jornada → Informe y evaluación
```

- **Micro (segundos)**: observar, seleccionar servicios, leer estados.
- **Meso (minutos)**: gestionar una incidencia, informar a viajeros, vigilar la propagación.
- **Macro (jornada / campaña futura)**: indicadores de calidad, percepción y resultado económico; en el futuro, progresión y nuevas líneas.

## 4. Escenario MVP: «Jornada de mañana — Madrid-Barcelona»

### Línea (esquemática, horizontal, Madrid a la izquierda)

| # | Estación | Código | km aprox. | Tramo hasta la siguiente (min de recorrido sin parada) |
|---|---|---|---|---|
| 1 | Madrid-Puerta de Atocha | MAD | 0 | 17 |
| 2 | Guadalajara-Yebes | GUA | 56 | 37 |
| 3 | Calatayud | CAT | 221 | 21 |
| 4 | Zaragoza-Delicias | ZAR | 307 | 32 |
| 5 | Lleida | LLE | 442 | 19 |
| 6 | Camp de Tarragona | CTA | 521 | 24 |
| 7 | Barcelona-Sants | BCN | 621 | — |

Recorrido directo ≈ 2 h 30 min; cada parada añade ≈ 5 min (parada + pérdida por frenado/arranque). Valores ajustables en `data/lines/mad_bcn.json`.

### Contenido

- **10 servicios** programados entre 06:30 y ~14:00, con tres patrones de parada: directo (solo ZAR), semidirecto (ZAR, LLE, CTA) y todas las paradas. Incluye servicios cortos MAD-ZAR y ZAR-BCN.
- **6 vehículos** (1 serie ficticia, 404 plazas): 4 composiciones en servicio (C3 es una **composición doble** V3+V4, 808 plazas) y 1 vehículo de **reserva en Zaragoza-Delicias**.
- **Plantilla**: 6 maquinistas, 5 interventores; al menos un **relevo de maquinista en Zaragoza**.
- **Incidencia guionizada** (activable) + incidencias aleatorias opcionales con semilla.

### Borrador de malla (orientativo; se cierra en la fase 2)

| Servicio | Recorrido | Salida → Llegada | Paradas | Composición |
|---|---|---|---|---|
| 3101 | MAD → BCN | 06:30 → 09:05 | ZAR | C1 |
| 3103 | MAD → ZAR | 07:00 → 08:25 | GUA, CAT | C2 |
| 3105 | ZAR → BCN | 08:55 → 10:20 | LLE, CTA | C2 (rotación de 3103) |
| 3150 | BCN → MAD | 06:40 → 09:35 | todas | C3 (doble: V3+V4) |
| 3152 | BCN → MAD | 07:30 → 10:05 | ZAR | C4 |
| 3102 | BCN → MAD | 09:50 → 12:25 | ZAR | C1 (rotación de 3101) |
| 3107 | MAD → BCN | 10:15 → 13:10 | todas | C3 (rotación de 3150) |
| 3109 | MAD → BCN | 10:45 → 13:20 | ZAR | C4 (rotación de 3152) |
| 3106 | BCN → ZAR | 11:00 → 12:25 | CTA, LLE | C2 (rotación de 3105) |
| 3108 | ZAR → MAD | 12:55 → 14:20 | CAT, GUA | C2 (rotación de 3106) |

Convención: servicios impares MAD→BCN, pares BCN→MAD. La rotación 3103 → 3105 en Zaragoza (30 min de margen) es la cadena que la prueba de aceptación usa para la propagación de retrasos.

### Situación clave del MVP

3103 sufre una **avería de material** entre Calatayud y Zaragoza. El jugador puede:

| Opción | Efecto inmediato | Efecto en cadena |
|---|---|---|
| **Esperar a la reparación** | Retraso estimado (rango) en 3103 | 3105 sale tarde si el margen de 30 min no lo absorbe; posible indemnización en ambos |
| **Sustituir material** (reserva V5 desde ZAR) | Tiempo de posicionamiento + transbordo; coste de sustitución | 3105 sale con V5; C2 queda fuera de servicio; se pierde la reserva para el resto de la jornada |
| **Cancelar 3103** | Viajeros sin servicio → necesitan alternativa (PAT en el futuro; en MVP se contabilizan y se indemnizan) | C2 debe retirarse; 3105 necesita otro material o también se cancela |

Además, **información al viajero**: enviar avisos (a bordo y en estaciones) reduce el impacto en la percepción; no informar la empeora.

## 5. Indicadores

- **Calidad del servicio** (0-100): puntualidad y cancelaciones.
- **Percepción de los viajeros** (0-100): retrasos percibidos, información dada, gestión de afectados.
- **Resultado económico** (€): ingresos simplificados − costes − indemnizaciones.

Definición y fórmulas: [ECONOMY.md](ECONOMY.md).

## 6. Pantallas y navegación

```
Menú principal ─┬─ Selección de escenario ─ Briefing (inicio de jornada) ─ OPERACIÓN CGO ─ Informe final ─┐
                ├─ Continuar (partida guardada) ─────────────────────────────┘                         │
                └─ Configuración                                                                       │
                ◄──────────────────────────────────────────────────────────────────────────────────────┘
OPERACIÓN CGO (pantalla persistente; el resto son capas sobre ella):
  ├─ Hoja de detalle de servicio (panel derecho)
  ├─ Recursos: Material / Personal (panel inferior desplegable o lateral)
  ├─ Gestión de incidencia (modal de decisión, pausa automática opcional)
  ├─ Información al viajero (desde detalle de servicio o incidencia)
  └─ Menú de pausa (guardar, configuración, abandonar jornada)
```

MVP: operación CGO, gestión de incidencia, detalle de servicio, recursos (lectura) e informe final son obligatorios. Menú principal, selección de escenario, briefing y configuración se implementan en versión mínima pero con el sistema visual completo.

## 7. Fuera del alcance del MVP 0.1

PAT funcional, capacidad de infraestructura y regulación, normativa laboral completa, demanda dinámica, tarifas comerciales, viajeros individuales, campaña, varias líneas. El diseño de todo ello está contemplado en [DATA_MODEL.md](DATA_MODEL.md) y [ROADMAP.md](ROADMAP.md).
