class_name EconomyCalc
extends RefCounted
## Cálculos económicos puros de un servicio (km, viajeros-km, costes). Sin estado; importes en céntimos.


## Km del tramo entre las paradas `i` e `i+1` del servicio (por estaciones de la línea).
static func segment_km(world: World, s: Service, i: int) -> float:
	var a: Station = world.stations.get(s.stops[i].station_id)
	var b: Station = world.stations.get(s.stops[i + 1].station_id)
	return absf(b.km - a.km) if a != null and b != null else 0.0


## Km recorridos del itinerario entre las paradas `from_idx` y `to_idx` (ambas incluidas como extremos).
static func km_between(world: World, s: Service, from_idx: int, to_idx: int) -> float:
	var km: float = 0.0
	for i: int in range(maxi(from_idx, 0), mini(to_idx, s.stops.size() - 1)):
		km += segment_km(world, s, i)
	return km


## Viajeros-km del servicio completo según los viajeros a bordo en cada tramo.
static func passenger_km(world: World, s: Service) -> float:
	var total: float = 0.0
	for i: int in range(s.stops.size() - 1):
		total += float(PassengerCalc.aboard(world, s.id, i)) * segment_km(world, s, i)
	return total


## Importe total de los billetes del servicio (precio medio por viajero-km × viajeros-km).
static func fare_total_cents(world: World, s: Service) -> int:
	return roundi(passenger_km(world, s) * world.economy_rules.price_per_pax_km_cents)


## Importe de `pax` viajeros (parte proporcional del total de billetes) con un % aplicado.
static func share_cents(fare_total: int, pax: int, booked: int, percent: int = 100) -> int:
	if booked <= 0:
		return 0
	return roundi(float(fare_total) * float(pax) * float(percent) / float(booked * 100))


## Vehículos-km: composiciones asignadas (no sustituidas) × km recorridos hasta el último punto alcanzado.
static func vehicle_km(world: World, s: Service, last: int) -> float:
	var total: float = 0.0
	for a: ResourceAssignment in world.assignments.for_service(s.id):
		if a.resource_type != Enums.ResourceType.COMPOSITION or a.status == Enums.AssignmentStatus.REPLACED:
			continue
		var comp: Composition = world.compositions.get(a.resource_id)
		var n: int = comp.members.size() if comp != null else 1
		total += float(n) * km_between(world, s, a.from_stop_index, mini(a.to_stop_index, last))
	return total


## Coste de personal (céntimos, positivo): horas reales de cada asignación hasta el último punto alcanzado.
static func staff_cost_cents(world: World, s: Service, last: int) -> int:
	var rules: EconomyRules = world.economy_rules
	var total: float = 0.0
	for a: ResourceAssignment in world.assignments.for_service(s.id):
		var rate: int = 0
		if a.resource_type == Enums.ResourceType.DRIVER:
			rate = rules.driver_per_hour_cents
		elif a.resource_type == Enums.ResourceType.CONDUCTOR:
			rate = rules.conductor_per_hour_cents
		else:
			continue
		var end_idx: int = mini(a.to_stop_index, last)
		if end_idx <= a.from_stop_index:
			continue
		var start: ServiceStop = s.stops[a.from_stop_index]
		var stop: ServiceStop = s.stops[end_idx]
		var t0: int = start.act_dep if start.act_dep != SimTime.NONE else 				(start.est_dep if start.est_dep != SimTime.NONE else start.exit_time())
		var t1: int = stop.act_arr if stop.act_arr != SimTime.NONE else stop.act_dep
		if t1 == SimTime.NONE:
			t1 = stop.est_arr  # cierre de jornada: hora estimada
		if t1 == SimTime.NONE or t0 == SimTime.NONE:
			continue
		total += float(maxi(t1 - t0, 0)) / 3600.0 * float(rate)
	return roundi(total)
