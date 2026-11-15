# Roadmap

Estado: ✅ hecho · 🔄 en curso · ⏳ pendiente. Cada fase sigue el ciclo de [CLAUDE.md](../CLAUDE.md) y no se avanza con errores importantes abiertos.

## MVP 0.1 — Madrid-Barcelona

| Fase | Contenido | Agentes | Criterio de terminado | Estado |
|---|---|---|---|---|
| **1. Inspección, agentes y diseño** | Agentes, arquitectura, modelo de datos, motor temporal, dirección visual, plan | coordinador | Documentación aprobada por el usuario | ✅ |
| **1b. Prototipo visual de la pantalla principal** | Tema, tokens, fuentes, 4-5 componentes base, escena estática de Operación CGO con datos simulados, capturas en 4 resoluciones | ux-ui, godot-dev | Dirección artística validada por el usuario con capturas | 🔄 prototipo entregado (capturas en `docs/captures/phase1b/`), pendiente de validación |
| **2. Modelo y red** | Entidades `src/model`, JSON del escenario, `ScenarioLoader`, `DataValidator`, `RotationGraph`, runner de pruebas | rail-sim, godot-dev, qa-tester | Escenario carga sin errores; pruebas de relaciones múltiples, relevos, solapamientos y continuidad | ✅ 65 pruebas OK (2026-11-14) |
| **3. Motor temporal** | `SimClock`, `EventQueue`, `SimulationSession`, `MovementSystem`, `SimulationHost`, comandos de velocidad | rail-sim, godot-dev, qa-tester | Pausa real, x1/x2/x4 equivalentes, llegadas/salidas/pasos a hora, determinismo por hash | ✅ 105 pruebas OK (2026-11-14) |
| **4. Operación** | Esquema conectado a la simulación, marcadores interpolados, sombra programada, asignaciones activas, rotaciones y propagación de retrasos | rail-sim, ux-ui, qa-tester | Retraso inyectado en 3103 se propaga a 3105; visible en el esquema | ✅ 163 pruebas OK, capturas en `docs/captures/phase4/` (2026-11-14) |
| **5. Incidencias** | `IncidentSystem`, avería guionizada y aleatoria, tres opciones con previsualización, hoja de decisión, historial | rail-sim, economy-design, ux-ui, qa-tester | Las tres opciones producen consecuencias distintas y registradas | ✅ 218 pruebas OK, capturas en `docs/captures/phase5/` (2026-11-14) |
| **6. Viajeros y economía** | `PassengerSystem`, `EconomySystem`, `PerceptionSystem`, información al viajero, equilibrado | economy-design, qa-tester | Tabla de equilibrado de ECONOMY §6 verificada por simulación | ✅ 260 pruebas OK (2026-11-14); sin UI de indicadores (pasa a Fase 7); cancelar solo es no dominado con baja ocupación (ECONOMY §6) |
| **7. Interfaz e informe** | Menú, selección de escenario, briefing, recursos, informe final, ajustes, guardado, revisión táctil, export Android de prueba | ux-ui, godot-dev, qa-tester | Prueba de aceptación completa, capturas revisadas, APK de depuración instalable | 🔄 321 pruebas OK, flujo extremo a extremo verificado (42 comprobaciones), capturas en `docs/captures/phase7/`, APK generado y firmado; pendiente probarlo en dispositivo/emulador y validación del usuario |

## Prueba de aceptación del MVP (automatizada en `tests/acceptance/` + manual)

1. Iniciar una jornada.
2. Observar al menos dos servicios con su material circulando por la línea.
3. Verificar su posición y avance temporal.
4. Provocar una avería en 3103.
5. Observar el retraso generado.
6. Comprobar el efecto sobre 3105 (mismo material, rotación en ZAR).
7. Tomar una decisión operativa.
8. Comprobar las consecuencias en viajeros y economía.
9. Finalizar la jornada y consultar el informe.

Además: relaciones múltiples de material y personal, asignación por tramos y horarios, solapamientos, reloj a distintas velocidades, pausa real y propagación de retrasos.

## Después del MVP

| Versión | Contenido |
|---|---|
| 0.2 | PAT por carretera (autobuses, taxis); incidencias de personal; más servicios y franja de tarde |
| 0.3 | Servicios ferroviarios especiales, solicitudes de capacidad al administrador de infraestructuras, cánones adicionales (`ChargeRule`) |
| 0.4 | Restricciones de infraestructura (limitaciones de velocidad, cortes de vía), meteorología |
| 0.5 | Turnos y normativa laboral básica, habilitaciones de material |
| 0.6 | Segunda línea (Madrid-Sevilla o Madrid-Valencia) compartiendo Atocha |
| 1.0 | Campaña, progresión, varios escenarios, pulido para publicación |
