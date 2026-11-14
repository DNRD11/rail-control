# Rail Control — Simulador CGO ferroviario

Videojuego de simulación de gestión ferroviaria para Android (horizontal). El jugador dirige el **Centro de Gestión de Operaciones (CGO)** de una operadora de alta velocidad: supervisa la circulación de los servicios, el material, los maquinistas e interventores, resuelve incidencias y asume sus consecuencias operativas, para los viajeros y económicas.

Escenario inicial (MVP 0.1): **LAV Madrid-Barcelona** (7 estaciones), con datos operativos ficticios y simplificados.

> Estado: **Fase 2 — modelo y datos** completada (sin simulación todavía). Ver [docs/ROADMAP.md](docs/ROADMAP.md).

## Requisitos

- Godot **4.7.2** estable (sin .NET). En esta máquina: `C:\Users\lozan\Godot_v4.7.2-stable_win64\`.
- Para Android (fase posterior): plantillas de export 4.7.2, Android SDK y JDK 17 configurados en Godot.
- Sin dependencias externas ni addons.

## Ejecución

```powershell
# Editor
& "C:\Users\lozan\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --path . -e

# Ejecutar el juego (cuando exista escena principal)
& "C:\Users\lozan\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --path .

# Pruebas headless (antes, una vez tras añadir clases: ... --headless --path . --import)
& "C:\Users\lozan\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd
```

## Documentación

| Documento | Contenido |
|---|---|
| [docs/GDD.md](docs/GDD.md) | Diseño de juego, escenario MVP, bucle de juego, navegación |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitectura técnica, módulos y estructura de carpetas |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | Entidades, relaciones múltiples, asignaciones, modelo del PAT |
| [docs/SIMULATION.md](docs/SIMULATION.md) | Reloj, eventos, circulación, retrasos, incidencias |
| [docs/ECONOMY.md](docs/ECONOMY.md) | Costes, indemnizaciones, indicadores, PAT y cánones |
| [docs/VISUAL_DIRECTION.md](docs/VISUAL_DIRECTION.md) | Identidad visual, componentes y pantalla principal |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Fases, criterios de aceptación y estado |
| [docs/AGENTS.md](docs/AGENTS.md) | Equipo de agentes de Claude Code |
| [CLAUDE.md](CLAUDE.md) | Reglas del proyecto para Claude Code (coordinador) |

## Aviso

La geografía y las estaciones son reales; horarios, material, plantillas, tarifas, indemnizaciones y cánones son **ficticios** y configurables, y no representan a ninguna operadora real ni al administrador de infraestructuras.
