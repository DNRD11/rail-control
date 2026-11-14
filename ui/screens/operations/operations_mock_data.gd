class_name OperationsMockData
extends RefCounted
## Datos de prueba locales de la fase 1b (SIN simulación). Imitan el escenario MVP.
## Los horarios son ilustrativos y se ajustan para ser coherentes con el reloj 07:42:15.

const CLOCK_TEXT := "07:42:15"
const SELECTED_DEFAULT := "3103"

## Movimiento visual lento (km/s, desde, hasta) solo para comprobar fluidez.
const _DRIFT: Dictionary[String, Vector3] = {
	"3101": Vector3(2.2, 95.0, 160.0),
	"3150": Vector3(2.0, 350.0, 410.0),
	"3152": Vector3(1.8, 545.0, 590.0),
}
const _LEAD_KM: Dictionary[String, float] = {"3150": 30.0}


static func stations() -> Array[SchematicStation]:
	var list: Array[SchematicStation] = [
		SchematicStation.make("MAD", "Madrid", 0.0),
		SchematicStation.make("GUA", "Guadalajara", 56.0),
		SchematicStation.make("CAT", "Calatayud", 221.0),
		SchematicStation.make("ZAR", "Zaragoza", 307.0),
		SchematicStation.make("LLE", "Lleida", 442.0),
		SchematicStation.make("CTA", "Tarragona", 521.0),
		SchematicStation.make("BCN", "Barcelona", 621.0),
	]
	return list


static func _service(code: String, direction: int, km: float, delay: int, state: RcTokens.State) -> SchematicService:
	var s := SchematicService.new()
	s.code = code
	s.direction = direction
	s.km = km
	s.scheduled_km = km
	s.delay_min = delay
	s.state = state
	return s


static func services() -> Array[SchematicService]:
	var list: Array[SchematicService] = []
	list.append(_service("3101", 1, 120.0, 0, RcTokens.State.OK))
	var broken: SchematicService = _service("3103", 1, 254.0, 14, RcTokens.State.ALERT)
	broken.scheduled_km = 307.0
	broken.broken = true
	broken.chain_km = 307.0
	broken.chain_label = "3105 · sale 08:06 +9′"
	list.append(broken)
	var late: SchematicService = _service("3150", -1, 380.0, 4, RcTokens.State.WARN)
	late.scheduled_km = 350.0
	list.append(late)
	list.append(_service("3152", -1, 565.0, 0, RcTokens.State.OK))
	return list


## Mueve visualmente los servicios (ida y vuelta lenta dentro de un rango).
static func advance(list: Array[SchematicService], delta: float) -> void:
	for s: SchematicService in list:
		if not _DRIFT.has(s.code):
			continue
		var d: Vector3 = _DRIFT[s.code]
		s.km += float(s.direction) * d.x * delta
		if s.direction > 0 and s.km > d.z:
			s.km = d.y
		elif s.direction < 0 and s.km < d.y:
			s.km = d.z
		s.scheduled_km = s.km + float(s.direction) * float(_LEAD_KM.get(s.code, 0.0))


static func kpis() -> Dictionary:
	return {
		"quality": {"value": "92", "up": true, "state": RcTokens.State.OK,
				"history": PackedFloat32Array([88, 90, 89, 91, 93, 92])},
		"perception": {"value": "78", "up": false, "state": RcTokens.State.WARN,
				"history": PackedFloat32Array([84, 83, 82, 80, 79, 78])},
		"result": {"value": "+12,4", "suffix": "k€", "up": true, "state": RcTokens.State.OK,
				"history": PackedFloat32Array([2, 4, 5, 8, 11, 12.4])},
	}


static func eta_for(code: String) -> Array:
	match code:
		"3103":
			return ["ZAR", "07:50 · +14′", RcTokens.State.ALERT]
		"3150":
			return ["LLE", "07:52 · +4′", RcTokens.State.WARN]
		"3101":
			return ["CAT", "07:49", RcTokens.State.OK]
		"3152":
			return ["CTA", "07:58", RcTokens.State.OK]
	return ["", "", RcTokens.State.IDLE]


## Detalle del servicio seleccionado (panel derecho).
static func detail(code: String) -> Dictionary:
	match code:
		"3103":
			return {
				"code": "3103", "route": "Madrid → Zaragoza", "status": "AVERÍA", "state": RcTokens.State.ALERT,
				"delay": "+14′", "note": "Retenido entre Calatayud y Zaragoza · avería de material",
				"stops": [
					["MAD", "06:15", "06:15", "done"], ["GUA", "06:32", "06:32", "done"],
					["CAT", "07:09", "07:11", "done"], ["ZAR", "07:36", "07:50", "next"]],
				"composition": "C2 · vehículo V2", "driver": "L. Prieto", "conductor": "J. Vidal",
				"passengers": "286 / 404", "primary": "Gestionar", "secondary": "Informar",
			}
		"3150":
			return {
				"code": "3150", "route": "Barcelona → Madrid", "status": "RETRASO", "state": RcTokens.State.WARN,
				"delay": "+4′", "note": "Parada prolongada en Camp de Tarragona",
				"stops": [
					["BCN", "06:40", "06:40", "done"], ["CTA", "07:04", "07:08", "done"],
					["LLE", "07:48", "07:52", "next"], ["ZAR", "08:11", "08:15", "pending"],
					["MAD", "09:35", "09:39", "pending"]],
				"composition": "C3 · doble V3 + V4", "driver": "A. Ferrer", "conductor": "M. Soler",
				"passengers": "341 / 404", "primary": "Detalle", "secondary": "Informar",
			}
		"3101":
			return {
				"code": "3101", "route": "Madrid → Barcelona", "status": "EN HORA", "state": RcTokens.State.OK,
				"delay": "0′", "note": "Circula según horario",
				"stops": [
					["MAD", "07:05", "07:05", "done"], ["ZAR", "08:10", "08:10", "next"],
					["BCN", "09:40", "09:40", "pending"]],
				"composition": "C1 · vehículo V1", "driver": "R. Navarro", "conductor": "E. Gil",
				"passengers": "168 / 202", "primary": "Detalle", "secondary": "Informar",
			}
	return {
		"code": "3152", "route": "Barcelona → Madrid", "status": "EN HORA", "state": RcTokens.State.OK,
		"delay": "0′", "note": "Circula según horario",
		"stops": [
			["BCN", "07:30", "07:30", "done"], ["ZAR", "09:05", "09:05", "next"],
			["MAD", "10:05", "10:05", "pending"]],
		"composition": "C4 · composición simple", "driver": "C. Mora", "conductor": "P. Ibáñez",
		"passengers": "176 / 202", "primary": "Detalle", "secondary": "Informar",
	}


static func station_name(code: String) -> String:
	for st: SchematicStation in stations():
		if st.code == code:
			return st.short_name
	return code
