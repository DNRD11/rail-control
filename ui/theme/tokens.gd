class_name RcTokens
extends RefCounted
## Tokens del sistema visual «Consola de precisión» (docs/VISUAL_DIRECTION.md §2).
## Única fuente de colores, espaciados, radios, duraciones y tipografías.

enum State { OK, WARN, ALERT, SPECIAL, IDLE }

# --- Color -----------------------------------------------------------------
const BG_BASE := Color("070B11")
const BG_PANEL := Color("0E1520")
const BG_RAISED := Color("141E2C")
const BG_OVERLAY := Color("1A2738")
const STROKE_SUBTLE := Color("1F2C3D")
const STROKE_STRONG := Color("2C3E55")
const TEXT_PRIMARY := Color("E8EFF7")
const TEXT_SECONDARY := Color("93A5BA")
const TEXT_MUTED := Color("70849B")
const ACCENT := Color("38D6F5")
const ACCENT_DEEP := Color("1E7FFF")
const STATE_OK := Color("3DDC97")
const STATE_WARN := Color("FFB547")
const STATE_ALERT := Color("FF5C6A")
const STATE_SPECIAL := Color("B48CFF")
const STATE_IDLE := Color("6B7F96")

# --- Espaciado (rejilla de 8 px) ------------------------------------------
const SP_1 := 4
const SP_2 := 8
const SP_3 := 12
const SP_4 := 16
const SP_5 := 24
const SP_6 := 32
const MARGIN_SCREEN := 16
const GAP_MODULES := 12
const TOUCH_MIN := 48

# --- Layout de la pantalla principal ---------------------------------------
const TOPBAR_H := 64
const LEFT_PANEL_W := 260
const RIGHT_PANEL_W := 300
const BOTTOM_BAR_H := 56

# --- Radios ----------------------------------------------------------------
const RADIUS_CHIP := 6
const RADIUS_CARD := 10
const RADIUS_PANEL := 14

# --- Duraciones (s) --------------------------------------------------------
const DUR_PRESS := 0.12
const DUR_STATE := 0.18
const DUR_PANEL := 0.24
const DUR_PULSE_LOOP := 2.0

# --- Tamaños tipográficos (1280x720) --------------------------------------
const FS_CLOCK := 34
const FS_PANEL_TITLE := 13
const FS_TEXT := 16
const FS_DATA := 15
const FS_STATION := 15
const FS_SMALL := 13
const FS_HEADING := 18

## Ajuste «Reducir animaciones»: todas las duraciones pasan a 0.
static var reduce_motion: bool = false

const _PATH_SANS := "res://assets/fonts/IBMPlexSans-Regular.ttf"
const _PATH_SANS_MEDIUM := "res://assets/fonts/IBMPlexSans-Medium.ttf"
const _PATH_SANS_SEMIBOLD := "res://assets/fonts/IBMPlexSans-SemiBold.ttf"
const _PATH_COND_SEMIBOLD := "res://assets/fonts/IBMPlexSansCondensed-SemiBold.ttf"
const _PATH_COND_BOLD := "res://assets/fonts/IBMPlexSansCondensed-Bold.ttf"
const _PATH_MONO := "res://assets/fonts/IBMPlexMono-Regular.ttf"
const _PATH_MONO_MEDIUM := "res://assets/fonts/IBMPlexMono-Medium.ttf"

static var _fonts: Dictionary[String, Font] = {}


static func _font(path: String, spacing: int = 0) -> Font:
	var key: String = "%s|%d" % [path, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = load(path) as Font
	var result: Font = base
	if spacing != 0:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = spacing
		result = variation
	_fonts[key] = result
	return result


static func font_text() -> Font:
	return _font(_PATH_SANS)


static func font_text_medium() -> Font:
	return _font(_PATH_SANS_MEDIUM)


static func font_text_semibold() -> Font:
	return _font(_PATH_SANS_SEMIBOLD)


## Títulos de panel y etiquetas: condensada seminegrita con tracking ~ +6 %.
static func font_title() -> Font:
	return _font(_PATH_COND_SEMIBOLD, 1)


static func font_station() -> Font:
	return _font(_PATH_COND_BOLD)


static func font_mono() -> Font:
	return _font(_PATH_MONO)


static func font_mono_medium() -> Font:
	return _font(_PATH_MONO_MEDIUM)


static func dur(seconds: float) -> float:
	return 0.0 if reduce_motion else seconds


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


static func state_color(state: State) -> Color:
	match state:
		State.OK:
			return STATE_OK
		State.WARN:
			return STATE_WARN
		State.ALERT:
			return STATE_ALERT
		State.SPECIAL:
			return STATE_SPECIAL
		_:
			return STATE_IDLE


## StyleBoxFlat estándar del sistema (radio uniforme, borde opcional).
static func make_box(fill: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.anti_aliasing = true
	return sb
