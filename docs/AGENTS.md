# Equipo de agentes

Rail Control se desarrolla con Claude Code usando un agente principal (coordinador) y cinco subagentes especializados. Mecanismo: **subagentes de proyecto de Claude Code**, archivos Markdown con frontmatter YAML en `.claude/agents/` (soportado por la versión instalada, 2.1.318). Las instrucciones del coordinador están en [`CLAUDE.md`](../CLAUDE.md), que se carga en todas las sesiones.

> Los agentes se cargan al iniciar la sesión. Tras crear o editar un archivo de `.claude/agents/`, reinicia la sesión o usa `/agents` para comprobar que aparecen.

## Resumen

| Agente | Archivo | Responsabilidad | Puede modificar | No modifica |
|---|---|---|---|---|
| **Coordinador / Arquitecto** | `CLAUDE.md` (sesión principal) | Visión global, arquitectura, reparto de tareas, integración, decisión de «terminado» | Todo, pero integra en lugar de implementar en exclusiva; dueño de `ARCHITECTURE.md`, `GDD.md`, `ROADMAP.md`, `CLAUDE.md` | — |
| **godot-dev** | `.claude/agents/godot-dev.md` | Infraestructura Godot, carga/validación de datos, guardado, navegación, `SimulationHost`, export Android; revisor de buenas prácticas GDScript | `src/core`, `src/data`, `src/save`, `src/app`, `project.godot` (con aprobación) | `src/model`, `src/sim`, `src/systems`, `ui/**`, valores de `data/` |
| **rail-sim** | `.claude/agents/rail-sim.md` | Modelo de datos, reloj, eventos, circulación, rotaciones, personal, retrasos, incidencias | `src/model`, `src/sim`, `src/systems` (salvo economía/viajeros/percepción), datos operativos en `data/`, `DATA_MODEL.md`, `SIMULATION.md` | `ui/**`, `src/data`, reglas económicas |
| **ux-ui** | `.claude/agents/ux-ui.md` | Sistema visual, tema, componentes, esquema ferroviario, pantallas, animaciones, táctil, revisión visual | `ui/**`, `assets/**`, `VISUAL_DIRECTION.md` | `src/**`, `data/**` |
| **qa-tester** | `.claude/agents/qa-tester.md` | Pruebas headless, regresiones, aceptación, informes de error reproducibles | `tests/**`, `tools/**` | Código de producción |
| **economy-design** | `.claude/agents/economy-design.md` | Costes, indemnizaciones, viajeros agregados, indicadores, equilibrado, diseño económico del PAT | `economy/passenger/perception_system.gd`, `data/rules/*` económicas, `ECONOMY.md` | Motor, UI, carga de datos |

## Cómo se invocan

- **Desde la sesión principal** (lo habitual): el coordinador delega con la herramienta de agentes indicando el nombre, p. ej. «Usa el agente `rail-sim` para implementar `EventQueue` según SIMULATION.md §3».
- **Por petición explícita del usuario**: «Pide a `qa-tester` que ejecute las pruebas de la fase 3» o mencionando al agente con `@`.
- **Gestión**: `/agents` lista, crea y edita agentes.

Los subagentes no pueden lanzar otros subagentes: toda la coordinación pasa por el agente principal.

## Protocolo de coordinación

1. **Encargo**: el coordinador da a cada agente un objetivo acotado, los documentos de referencia, los archivos que puede tocar y el criterio de terminado.
2. **Dependencias**: si un agente necesita cambiar un archivo ajeno, lo indica en su resumen en lugar de editarlo.
3. **Secuencia, no concurrencia** sobre los mismos archivos: el coordinador no lanza en paralelo dos agentes con ámbitos solapados. En paralelo solo trabajos independientes (p. ej. `ux-ui` con tema mientras `rail-sim` hace el reloj).
4. **Entrega**: cada agente termina con su bloque «Resumen para el coordinador» (cambios, archivos, pruebas ejecutadas, dependencias, riesgos).
5. **Integración**: el coordinador revisa el diff, ejecuta `tests/run_tests.gd`, pide revisión visual a `ux-ui` si hay UI y actualiza `ROADMAP.md`.

## Selección típica por fase

| Fase | Agentes |
|---|---|
| 1b Prototipo visual | ux-ui (+ godot-dev para el proyecto) |
| 2 Modelo y red | rail-sim, godot-dev (carga/validación), qa-tester |
| 3 Motor temporal | rail-sim, godot-dev (`SimulationHost`), qa-tester |
| 4 Operación | rail-sim, ux-ui (esquema), qa-tester |
| 5 Incidencias | rail-sim, economy-design, ux-ui, qa-tester |
| 6 Viajeros y economía | economy-design, qa-tester |
| 7 Interfaz e informe | ux-ui, godot-dev, qa-tester |
