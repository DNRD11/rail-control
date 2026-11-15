# Rail Control — Simulador CGO ferroviario

Videojuego de simulación de gestión ferroviaria para Android (horizontal). El jugador dirige el **Centro de Gestión de Operaciones (CGO)** de una operadora de alta velocidad: supervisa la circulación de los servicios, el material, los maquinistas e interventores, resuelve incidencias y asume sus consecuencias operativas, para los viajeros y económicas.

Escenario inicial (MVP 0.1): **LAV Madrid-Barcelona** (7 estaciones), con datos operativos ficticios y simplificados.

> Estado: **Fase 4 — Operación** completada: la pantalla CGO muestra la simulación en vivo (reloj, velocidades, retrasos y propagación). Ver [docs/ROADMAP.md](docs/ROADMAP.md).

## Requisitos

- Godot **4.7.2** estable (sin .NET). En esta máquina: `C:\Users\lozan\Godot_v4.7.2-stable_win64\`.
- Para exportar a Android: ver [Export Android](#export-android).
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

## Export Android

Preset `Android debug` en `export_presets.cfg`: APK de depuración, `arm64-v8a`, horizontal, renderer Mobile, sin Gradle (usa la plantilla precompilada `android_debug.apk`), paquete `com.railcontrol.cgo`. El proyecto activa `rendering/textures/vram_compression/import_etc2_astc` (obligatorio para Android).

Requisitos (verificados en esta máquina):

- Plantillas de exportación 4.7.2 en `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- JDK 17 (Eclipse Adoptium 17.0.20) y Android SDK (`platform-tools`, `build-tools;36.0.0`, `platforms;android-36`).
- En Editor Settings: `export/android/java_sdk_path`, `export/android/android_sdk_path` y `export/android/debug_keystore` (alias `androiddebugkey`, contraseña `android`). Crear la keystore: `keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 9999 -dname "CN=Android Debug,O=Android,C=US"`.

Exportación headless:

```powershell
$g = "C:\Users\lozan\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --path . --import
& $g --headless --path . --export-debug "Android debug" build/rail-control-debug.apk
adb install -r build/rail-control-debug.apk
```

Estado (2026-11-14): la exportación generó y firmó `build/rail-control-debug.apk` (~29 MB, `arm64-v8a`, minSdk 24, horizontal). **No se ha instalado ni ejecutado en dispositivo o emulador**; la revisión táctil real sigue pendiente. `build/` está en `.gitignore`.

## Guardado y ajustes

Autoguardado en `user://saves/autosave.json` (guardado determinista, ver ARCHITECTURE §4) y ajustes en `user://settings.cfg`.
