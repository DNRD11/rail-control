# Dirección visual y sistema de interfaz

Fuente de verdad del aspecto del juego. Dueño: agente `ux-ui`. Navegación en [GDD.md §6](GDD.md).

## 1. Concepto: «Consola de precisión»

Un CGO de alta velocidad contemporáneo: superficies de grafito azulado en capas, una línea luminosa que cruza la pantalla y datos tipográficos nítidos. La luz es **información**: solo brilla lo que está vivo (servicios en marcha), seleccionado o en alerta. Referentes de tono: salas de control ferroviarias y aeroportuarias modernas, instrumentación técnica, cartelería ferroviaria. Anti-referentes: dashboards corporativos genéricos, HUD de ciencia ficción, neón por todas partes.

Palabras clave: **preciso · sereno · vivo · legible · creíble**.

## 2. Tokens

Definidos en `ui/theme/tokens.gd` y aplicados en `ui/theme/rc_theme.tres`.

### Color

| Token | Valor | Uso |
|---|---|---|
| `bg_base` | `#070B11` | fondo de la aplicación (con viñeta sutil y retícula de 32 px al 3 %) |
| `bg_panel` | `#0E1520` | módulos de consola |
| `bg_raised` | `#141E2C` | tarjetas, filas seleccionables |
| `bg_overlay` | `#1A2738` | hojas modales, menús |
| `stroke_subtle` | `#1F2C3D` | separadores |
| `stroke_strong` | `#2C3E55` | bordes de panel, vía del esquema |
| `text_primary` | `#E8EFF7` | texto principal |
| `text_secondary` | `#93A5BA` | etiquetas |
| `text_muted` | `#70849B` | metadatos, deshabilitado |
| `accent` | `#38D6F5` | cian: selección, foco, línea activa, acción primaria |
| `accent_deep` | `#1E7FFF` | azul eléctrico: gradientes, progreso |
| `state_ok` | `#3DDC97` | en hora / disponible |
| `state_warn` | `#FFB547` | retraso leve / aviso |
| `state_alert` | `#FF5C6A` | retraso grave / incidencia / avería |
| `state_special` | `#B48CFF` | servicios especiales, PAT, vacío |
| `state_idle` | `#6B7F96` | programado / finalizado / reserva |

Contraste: `text_primary` sobre `bg_panel` ≈ 15:1; `text_secondary` ≈ 6.8:1; `text_muted` ≈ 4.7:1 (subido desde `#5E7187`, que daba 3.6:1, en la fase 1b). Los colores de estado sobre `bg_panel` superan 4.5:1.

### Tipografía (OFL, incluidas en `assets/fonts/`)

| Rol | Fuente | Tamaño base (1280×720) |
|---|---|---|
| Reloj principal | IBM Plex Mono Medium, cifras tabulares | 34 |
| Títulos de panel | IBM Plex Sans Condensed SemiBold, mayúsculas, tracking +6 % | 13 |
| Texto | IBM Plex Sans Regular/Medium | 16 (mínimo absoluto 13) |
| Datos (horas, códigos, retrasos, €) | IBM Plex Mono Regular | 15 |
| Códigos de estación en el esquema | IBM Plex Sans Condensed Bold | 15 |

### Espaciado, forma y movimiento

- Rejilla de **8 px**; márgenes de pantalla 16 px; separación entre módulos 12 px.
- Radios: 6 px (chips), 10 px (tarjetas), 14 px (paneles).
- Paneles: borde 1 px `stroke_strong` al 60 % + filete superior de 1 px `accent` al 25 % (sensación de «módulo encendido») + sombra suave.
- Objetivos táctiles ≥ 48×48 px; separación mínima de 8 px entre objetivos.
- Duraciones: 120 ms (pulsación), 180 ms (cambios de estado), 240 ms (paneles). Curva `EASE_OUT`/`TRANS_CUBIC`. Ajuste «Reducir animaciones» → 0 ms.

## 3. Componentes (`ui/components/`)

| Componente | Descripción |
|---|---|
| `RcPanel` | módulo de consola con cabecera (icono + título condensado + acción opcional) |
| `RcButton` | variantes `primary` (relleno `accent`, texto oscuro), `secondary` (contorno), `danger`, `ghost`; feedback: escala 0.97 + destello 120 ms |
| `RcSegmentedControl` | selector de velocidad ⏸ x1 x2 x4, opción activa iluminada |
| `RcStatusChip` | icono + texto + color semántico (EN HORA, +12′, AVERÍA, CANCELADO) |
| `RcKpiTile` | valor grande, etiqueta, tendencia (▲▼) y micrográfico de la jornada |
| `RcAlertCard` | incidencia: barra lateral de prioridad, título, servicio, hora, acción «Gestionar»; animación de entrada por deslizamiento y pulso único |
| `RcListRow` | fila táctil de 56 px para servicios, vehículos y personal |
| `RcDetailSheet` | panel lateral deslizante para el detalle de servicio/recurso |
| `RcDecisionCard` | opción de decisión con previsualización (retraso, afectados, coste, percepción) y estado deshabilitado con motivo |
| `RcToast` | notificaciones breves apiladas, arriba a la derecha |
| `RcTimelineBar` | barra de paradas de un servicio (programado vs. estimado) |
| `RcSparkline` | micrográfico para indicadores |

Iconos: SVG propios, trazo 2 px, extremos redondeados, rejilla de 24 px, un único peso.

## 4. Pantalla principal (Operación CGO) — primera propuesta

Resolución base 1280×720 (`canvas_items`, `expand`). En pantallas 20:9 el espacio extra se da al esquema.

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ ◈ CGO · MAD–BCN   Jornada de mañana     07:42:15  [⏸|x1|x2|x4]   CALIDAD 92 ▲  PERCEPCIÓN 78 ▼  RESULTADO +12,4 k€   ⚠ 1 │ 64 px
├───────────────┬───────────────────────────────────────────────────────┬──────────────┤
│ INCIDENCIAS   │                                                       │ SERVICIO 3103│
│ ▌AVERÍA  3103 │   ◄ BCN→MAD  ────●──────────●────[3150 +4′]●──────●── │ MAD → ZAR    │
│ ▌07:38 CAT-ZAR│                                                       │ ● RETENIDO   │
│ [Gestionar]   │  MAD    GUA          CAT     ZAR       LLE   CTA   BCN│ +14′  ▲      │
│               │                                                       │ ──paradas──  │
│ AVISOS        │   ────●──[3101]──●──────────●─[3103 ⚠]─●──────●────── │ Composición  │
│ · 3105 +9′    │                                    MAD→BCN ►          │ C2 (V2)      │
│   previsto    │   0 km     ·    ·    ·    300 km    ·    ·    621 km  │ Maquinista … │
│               │                                                       │ Viajeros 286 │
├───────────────┴───────────────────────────────────────────────────────┴──────────────┤
│ RECURSOS ▲   Material 4/5 en servicio · Reserva: V5 (ZAR) · Maquinistas 5/6 · Interv. 5/5 │ 56 px (desplegable)
└──────────────────────────────────────────────────────────────────────────────────────┘
   260 px                        esquema (flexible)                           300 px
```

### El esquema (protagonista)

- Dos vías paralelas horizontales: superior BCN→MAD, inferior MAD→BCN; escala proporcional a km (con compresión mínima para que GUA no quede pegada a MAD).
- Vías: trazo 3 px `stroke_strong`; el tramo recorrido por un servicio se ilumina tenuemente tras él (estela de 2-3 s de opacidad decreciente).
- Estaciones: cápsula vertical que cruza ambas vías; código grande (MAD) + nombre completo pequeño; hora local de la próxima llegada al seleccionar.
- **Servicios**: marcador en forma de punta de flecha (indica sentido) con el código y un chip de retraso. Color = estado. Movimiento continuo interpolado.
- **«Sombra programada»** (rasgo de identidad): para un servicio con retraso, un marcador fantasma con contorno discontinuo indica dónde debería estar según horario, unido al marcador real por un segmento ámbar/rojo. El retraso se *ve* como distancia.
- Selección: anillo `accent` con un pulso al seleccionar; el resto de servicios bajan al 70 % de opacidad y se resalta la cadena de rotación (servicios siguientes del mismo material) con línea punteada.
- Incidencia en tramo: icono de avería sobre el marcador, halo rojo de pulso lento (1 pulso/2 s) — el único elemento que pulsa de forma continua.

### Jerarquía y densidad

1. Esquema y reloj. 2. Incidencias activas. 3. Detalle del seleccionado. 4. Indicadores. 5. Recursos (plegados por defecto).

En pantallas estrechas (< 1100 px lógicos de ancho útil) el panel de incidencias se reduce a un carril de iconos con contador y el detalle pasa a hoja superpuesta.

### Gestión de incidencia

Hoja modal sobre el esquema atenuado (el esquema sigue visible y animado detrás). Arriba: qué ha pasado, dónde, cuándo, viajeros a bordo, rango de reparación. Debajo: tres `RcDecisionCard` en fila con previsualización comparable (mismas métricas en el mismo orden). Botón «Informar a viajeros» siempre presente.

## 5. Proceso de revisión visual

`tools/capture_screens.gd` lanza la pantalla con datos reales de la simulación en 1280×720, 1920×1080, 2400×1080 y 1280×800, y guarda PNG en `user://captures/`. `ux-ui` revisa cada captura con la lista de [.claude/agents/ux-ui.md](../.claude/agents/ux-ui.md) antes de dar una pantalla por terminada.

## 6. Pantalla de Operación con simulación (Fase 4)

- `OperationsScreen` carga `mvp_mad_bcn_morning`, crea la sesión y un `SimulationHost` hijo; arranca en pausa con un velo «Iniciar jornada» (`OpsStartOverlay`). Un error de carga se muestra en ese mismo velo.
- `OperationsPresenter` (ui/screens/operations/) traduce sesión → `SchematicService` (km interpolado con `query_service_position_at(now + fracción)`, sombra con `query_scheduled_position`, cadena con `query_service_chain`), detalle, avisos y franja de recursos. Solo lee; los cambios son comandos (`SetSpeedCommand`, `InjectDelayCommand`).
- Estado visual por nivel de retraso (`DelayInfo.level`): ON_TIME → verde, MINOR → ámbar, MAJOR/SEVERE → rojo. Solo se dibujan los servicios en marcha.
- Indicadores sin cifras (Fase 6): `RcKpiTile.no_data` muestra «—» sin tendencia ni micrográfico.
- Nombres de estación del esquema se acortan con «…» si chocan con la vecina. Rutas del detalle con etiquetas cortas («Madrid → Zaragoza»).
- Control de depuración «Inyectar retraso 3103 (+25′)» en el panel izquierdo, solo con `OS.is_debug_build()`.
- Capturas: `docs/captures/phase4/` (etapas 0_inicio, 1_en_hora, 2_retraso, 3_propagacion).

## 7. Incidencias y decisión (Fase 5)

- `SimulationHost` reexpone `incident_changed`. Al detectarse una avería (`AWAITING_DECISION`) la pantalla selecciona el servicio, **pausa** (guardando la velocidad anterior solo si corría) y abre `OpsDecisionSheet`; al decidir (o expirar la decisión automática) cierra la hoja y reanuda a la velocidad previa. «Gestionar» en la tarjeta reabre la hoja (y pausa si hacía falta). «Decidir más tarde» cierra sin reanudar.
- `OpsIncidentsView` (ahora `ScrollContainer`, barra fina temada): tarjetas `RcAlertCard` por incidencia abierta (chip AVERÍA / EN CURSO, cuenta atrás en el texto, sin botón si ya hay decisión), sección **Historial** (opción elegida, coste, «automática» o «decidida por ti») y Avisos. El contador de la barra superior cuenta incidencias (rojo si esperan decisión, ámbar si solo están en curso) y, si no hay, avisos de retraso.
- `OpsIncidentPresenter` convierte `Incident`/`DecisionOption`/`OptionPreview` en modelos; usa `query_incident_fresh` para refrescar previsualizaciones en cada tic mientras la hoja está abierta. `RcFormat` da formato español (`3.000 €`, `+25–90′`, `hasta +25′`, `mm:ss`).
- **Hoja de decisión** (`PanelSheet`, ancho máx. 1136 px, sobre velo al 72 %): cabecera con chip, qué/dónde/cuándo/viajeros a bordo/rango de reparación, cuenta atrás grande + barra (ámbar en el último tercio) y tres `RcDecisionCard` con las mismas cuatro métricas en el mismo orden (retraso propio, viajeros afectados, coste estimado, reanudación), lista de servicios afectados (máx. 3 + «y N más»), avisos como chip (`Faltan N plazas` ámbar, `N necesitan alternativa` violeta) y botón de confirmación de 48 px (una pulsación). Cancelar usa `RcButton.Kind.DANGER`. Opción no disponible: tarjeta atenuada, chip «No disponible» y motivo, botón deshabilitado.
- Nuevos elementos del tema: `PanelSheet`, `RcButtonDanger`, barra `VScrollBar` fina. La hoja usa `bg_panel` (no `bg_overlay`) para que las tarjetas `bg_raised` queden elevadas sobre ella.
- Capturas: `docs/captures/phase5/` (1_averia_detectada, 2_espera_en_curso, 3_espera_resuelta, 4_sustituir, 5_cancelar) con `tools/capture_screens.gd`.

## 8. Pantallas de aplicación e informe (Fase 7)

Flujo: Menú → Selección de escenario → Briefing → Operación → Informe (`AppFlow.go`). Todas las pantallas de aplicación heredan de `RcScreenFrame` (fondo de consola, cabecera de 64 px con marca + kicker + título + botón volver opcional, cuerpo, pie con acciones y `RcToast`) y solo implementan `_build()`.

| Pantalla | Escena | Composición |
|---|---|---|
| Menú principal | `ui/screens/menu/` | Identidad a la izquierda (kicker, «Rail Control», chips) y panel «Jornada» de 380 px con botones grandes de 56 px (Nueva jornada primario, Continuar solo si hay guardado, Configuración, Salir ghost). Ilustración inferior `MenuBackdrop`: dos vías con servicios que avanzan lentamente (se detiene con «Reducir animaciones»). |
| Selección de escenario | `ui/screens/scenario_select/` | Lista de `RcListRow` altas (72 px, selección con borde acento) + ficha con tres `RcKpiTile` (franja, servicios, incidencias) y «Qué vas a hacer». Escenarios futuros como filas atenuadas con chip «Próximamente». |
| Briefing | `ui/screens/briefing/` | Tres módulos: Objetivos (derivados de `data/rules/report.json`), Resumen del escenario (descripción + 4 tiles) y Recursos disponibles (filas). Pie: nota sobre la pausa inicial y «Comenzar jornada». `BriefingPresenter` solo lee el escenario. |
| Configuración | `ui/screens/settings/` | Panel centrado de 780 px: velocidad inicial (segmentado), pausa automática (`RcToggle`), tamaño de interfaz (Pequeña/Normal/Grande) y reducir animaciones. Lee y guarda `AppFlow.settings` (`Settings.save()`); «Reducir animaciones» no existe en `Settings` y se guarda en `user://ui_prefs.cfg` vía `UiSettings`. Volver regresa a Operación si hay jornada en curso (se llegó desde la pausa) o al menú. |
| Informe final | `ui/screens/report/` | Columna izquierda: `RcGradeBadge` (A verde, B cian, C ámbar, D rojo; arco = puntuación) + los tres indicadores con `RcMeter` (marcas en los cortes de nota 55/70/85), lectura textual y chip. Centro: desglose económico con `RcBarRow` (ingresos verde, ordinarios gris, incidencias rojo, indemnizaciones ámbar) y total grande; fila de 4 tiles de viajeros. Derecha: servicios con retraso e incidencias con decisión y coste (listas desplazables). Pie: Menú principal / Reintentar. `ReportPresenter` es el único punto que conoce las claves reales de `DayReport.to_dict()` (`ledger_by_category`, `passengers{}`, `services[]` con `status`/`delay_s`, `incidents[]` con `decision`/`cost_cents`); lista como «con retraso» los servicios cancelados/parciales o con ≥ 5′. |

### Operación (cambios Fase 7)

- Barra superior: `OpsKpiBar` alimenta calidad (0-100), percepción (0-100) y resultado (`RcFormat.eur_compact`, rojo si es negativo) desde `query_indicators()`; se marca «sucio» con `indicators_changed`/`ledger_changed` y se refresca ≤ 4 veces/s. Tendencia ▲▼ solo si la variación ≥ 0,5; micrográfico solo en pantallas anchas (≥ 1500 px lógicos). Botón de menú (48 px) a la derecha.
- Información al viajero: `OpsInformBlock` (chip SIN INFORMAR ámbar / INFORMADOS verde, texto y botón «Informar a los viajeros» con icono) en el detalle de servicio y en la hoja de decisión; emite `InformPassengersCommand`. Confirmación con `RcToast`.
- Menú de pausa (`OpsPauseMenu`): Reanudar, Guardar, Configuración y, separado y en rojo, Abandonar jornada con segunda confirmación. Abrirlo pausa y cerrarlo restaura la velocidad.
- `OpsFlowGlue` (nodo hijo de Operación) agrupa el pegamento con `AppFlow`: menú de pausa, `autosave()`, ir a Configuración, `abandon_day()` y `day_finished` → `finish_day()` (diferido). La pantalla usa siempre `AppFlow.host` (el host cuelga del autoload y sobrevive a los cambios de escena). Si se entra con una jornada ya empezada, el velo ofrece «Reanudar jornada».

### Nuevos componentes y tokens

`RcToggle`, `RcGradeBadge`, `RcMeter`, `RcBarRow`, `RcListRow` (por fin implementado), `RcBullet`, `RcToast`, `RcScreenFrame`; `RcButton` gana `icon_name` (SVG de `assets/icons/`, blancos y teñidos por el tema), `large` (56 px) e `icon_only`; `RcSegmentedControl.segment_width`; `RcKpiTile.show_trend` y `value_state`. Tema: `LabelDisplay`, `LabelTitle`, `LabelKicker`, `LabelBigData`, `PanelRow`, `PanelRowSelected` (borde acento suave 1 px al 45 %, sin glow fuerte). Tokens: `BUTTON_LARGE_H`, `ROW_H`, `ROW_TALL_H`, `MENU_PANEL_W`, `FS_DISPLAY`, `FS_TITLE`.

### Revisión táctil

Todos los botones ≥ 48 px (56 px en menús y pies), filas ≥ 56 px, interruptor con zona de 64×48; las filas seleccionables reaccionan al soltar (no roban el arrastre del scroll) y no hay hover como único affordance. Acciones destructivas (Abandonar) separadas 16 px del resto y con confirmación.

### Capturas

`docs/captures/phase7/<ancho>x<alto>_<etapa>.png` en 1280×720, 1920×1080, 2400×1080 y 1600×720 (2400×1080 y 1600×720 comparten 20:9 → mismo diseño lógico de 1600×720). Etapas: 1_menu, 2_scenario_select, 3_briefing, 4_settings, 5_report_sustituir/cancelar/sin_decidir (jornadas reales simuladas hasta el final con `DayReport.from_session`), 6_ops_en_curso, 7_ops_averia_decision, 8_ops_informados, 9_ops_pausa.
