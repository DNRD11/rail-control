# CLAUDE.md — Rail Control (Simulador CGO ferroviario)

Este archivo contiene las instrucciones del **agente principal (Coordinador / Arquitecto)**. Lo cargan automáticamente todas las sesiones de Claude Code en este proyecto.

## Proyecto

Videojuego de gestión ferroviaria para Android (horizontal). El jugador dirige el **Centro de Gestión de Operaciones (CGO)** de una operadora en la LAV Madrid-Barcelona. Godot 4.7.2 + GDScript con tipado estático. Proyecto 2D, renderer Mobile.

Documentación de referencia (consultar antes de modificar sistemas):

| Documento | Contenido |
|---|---|
| [README.md](README.md) | Requisitos, ejecución, pruebas |
| [docs/GDD.md](docs/GDD.md) | Diseño de juego, escenario MVP, navegación |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Módulos, capas, dependencias, carpetas |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | Entidades, relaciones, asignaciones, PAT futuro |
| [docs/SIMULATION.md](docs/SIMULATION.md) | Reloj, eventos, circulación, retrasos, incidencias |
| [docs/ECONOMY.md](docs/ECONOMY.md) | Costes, indemnizaciones, indicadores, cánones |
| [docs/VISUAL_DIRECTION.md](docs/VISUAL_DIRECTION.md) | Identidad visual, tokens, componentes, pantalla principal |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Fases y estado |
| [docs/AGENTS.md](docs/AGENTS.md) | Equipo de agentes y protocolo de coordinación |

## Entorno

- Godot (consola, para headless/pruebas): `C:\Users\lozan\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`
- Pruebas: `<godot_console> --headless --path . -s res://tests/run_tests.gd`
- Shell: Windows (PowerShell; Git Bash disponible).

## Terminología obligatoria (código, datos, UI y documentación)

- **Material / vehículos** (no «tren») para el material rodante. **Composición** = vehículos que circulan acoplados.
- **Servicio** = circulación comercial o especial.
- **Maquinista** (conducción), **Interventor** (acompañamiento).
- **PAT** = Plan Alternativo de Transporte.
- **Administrador de infraestructuras** = entidad externa dueña de la infraestructura.
- En código (inglés): `Service`, `Vehicle`, `Composition`, `ResourceAssignment`, `StaffMember` (`role = DRIVER | CONDUCTOR`), `Incident`, `AlternativeTransportPlan`, `InfrastructureManager`. Nunca `Train` como entidad.
- Textos visibles al jugador: en español.

## Reglas de arquitectura (no negociables)

1. **Simulación desacoplada de la UI.** `src/` no puede referenciar `ui/` ni nodos de escena. La simulación es `RefCounted` puro, ejecutable headless.
2. **Tiempo de simulación entero (segundos de jornada)**, avanzado por pasos fijos. Nunca depende de FPS, `delta` de animaciones ni tweens.
3. **Determinismo:** toda aleatoriedad pasa por el `RandomNumberGenerator` con semilla de la sesión. Orden de eventos estable `(time, priority, seq)`.
4. **Sin campos únicos de recurso en `Service`** (`vehicle_id`, `driver_id`, …). Todo recurso se vincula mediante `ResourceAssignment`.
5. **Datos fuera del código:** líneas, estaciones, servicios, material, personal, tarifas y reglas en `data/**/*.json`. Añadir una línea no debe requerir tocar el motor.
6. **Nada de GameManager monolítico.** Sistemas pequeños con responsabilidad única, coordinados por `SimulationSession`.
7. **Signals** para comunicar cambios de la simulación hacia la presentación.
8. **Sin dependencias externas** (ni C#, ni addons, ni SQLite) salvo aprobación explícita del usuario.
9. Toda la UI usa el tema y componentes de `ui/theme` y `ui/components`. Prohibidos los estilos improvisados por pantalla.

## Convenciones GDScript

- Tipado estático en todo: variables, parámetros, retornos, `Array[T]`, `Dictionary[K, V]`.
- `class_name` en entidades y sistemas reutilizables. `snake_case` para archivos y funciones, `PascalCase` para clases, `UPPER_SNAKE` para constantes y valores de enum.
- Un archivo = una clase. Archivos de < ~300 líneas como guía.
- Sin `get_node()` con rutas largas entre escenas; usar `%UniqueName` dentro de la escena y signals entre escenas.
- Errores de datos: validar al cargar y reportar con `push_error` + lista de errores del validador; nunca fallar silenciosamente.

## Rol del coordinador

- Mantiene la visión global, la arquitectura y la coherencia entre documentos.
- Divide el trabajo en tareas pequeñas y elige qué agentes intervienen (ver [docs/AGENTS.md](docs/AGENTS.md)). No es obligatorio usar todos.
- Es el **único** que integra contribuciones: revisa el resumen de cada agente, comprueba archivos tocados y ejecuta las pruebas antes de aceptar.
- No avanza de fase con errores importantes o funcionalidades sin validar.
- Actualiza [docs/ROADMAP.md](docs/ROADMAP.md) al cerrar cada tarea relevante.
- Ciclo por fase: explicar → archivos afectados → agentes → cambios pequeños → pruebas → corrección → documentación → revisión visual (si hay UI) → resumen.
