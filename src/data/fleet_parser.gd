class_name FleetParser
extends RefCounted
## Clases de material, vehículos, composiciones y personal → World.


static func parse(classes_raw: Dictionary, vehicles_raw: Dictionary, compositions_raw: Dictionary,
		staff_raw: Dictionary, world: World, report: ValidationReport) -> void:
	_parse_classes(classes_raw, world, report)
	_parse_vehicles(vehicles_raw, world, report)
	_parse_compositions(compositions_raw, world, report)
	_parse_staff(staff_raw, world, report)


static func _parse_classes(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "vehicle_classes").read_dicts(raw, "classes")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var r: DictReader = DictReader.new(report, "vehicle_classes[%d]" % i)
		var c: VehicleClass = VehicleClass.new()
		c.id = r.read_id(d, "id")
		c.name = r.read_string(d, "name", false, String(c.id))
		c.seats = r.read_int(d, "seats")
		c.max_speed_kmh = r.read_int(d, "max_speed_kmh", false, 0)
		c.can_couple = r.read_bool(d, "can_couple", false, false)
		c.max_coupled = r.read_int(d, "max_coupled", false, 1)
		c.cost_per_km = r.read_float(d, "cost_per_km", false, 0.0)
		c.length_m = r.read_int(d, "length_m", false, 0)
		if _dup(world.vehicle_classes, c.id, "vehicle_classes[%d]" % i, report):
			continue
		world.vehicle_classes[c.id] = c


static func _parse_vehicles(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "vehicles").read_dicts(raw, "vehicles")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var r: DictReader = DictReader.new(report, "vehicles[%d]" % i)
		var v: Vehicle = Vehicle.new()
		v.id = r.read_id(d, "id")
		v.number = r.read_int(d, "number", false, 0)
		v.class_id = r.read_id(d, "class")
		v.status = r.read_enum(d, "status", Enums.VehicleStatus, false, Enums.VehicleStatus.AVAILABLE) as Enums.VehicleStatus
		v.location_station_id = r.read_id(d, "location")
		v.km_since_maintenance = r.read_float(d, "km_since_maintenance", false, 0.0)
		if _dup(world.vehicles, v.id, "vehicles[%d]" % i, report):
			continue
		world.vehicles[v.id] = v


static func _parse_compositions(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "compositions").read_dicts(raw, "compositions")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var ctx: String = "compositions[%d]" % i
		var r: DictReader = DictReader.new(report, ctx)
		var c: Composition = Composition.new()
		c.id = r.read_id(d, "id")
		c.status = r.read_enum(d, "status", Enums.CompositionStatus, false, Enums.CompositionStatus.ACTIVE) as Enums.CompositionStatus
		c.formed_at = r.read_time(d, "formed_at", false, 0)
		c.dissolved_at = r.read_time(d, "dissolved_at", false, SimTime.NONE)
		var members: Array[Dictionary] = r.read_dicts(d, "members")
		for j: int in members.size():
			var mr: DictReader = DictReader.new(report, "%s.members[%d]" % [ctx, j])
			var m: CompositionMember = CompositionMember.new()
			m.vehicle_id = mr.read_id(members[j], "vehicle")
			m.position = mr.read_int(members[j], "position", false, j + 1)
			m.from_time = mr.read_time(members[j], "from_time", false, c.formed_at)
			m.to_time = mr.read_time(members[j], "to_time", false, SimTime.NONE)
			c.members.append(m)
		if _dup(world.compositions, c.id, ctx, report):
			continue
		world.compositions[c.id] = c


static func _parse_staff(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "staff").read_dicts(raw, "staff")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var r: DictReader = DictReader.new(report, "staff[%d]" % i)
		var s: StaffMember = StaffMember.new()
		s.id = r.read_id(d, "id")
		s.name = r.read_string(d, "name", false, String(s.id))
		s.role = r.read_enum(d, "role", Enums.StaffRole) as Enums.StaffRole
		s.base_station_id = r.read_id(d, "base")
		s.shift_start = r.read_time(d, "shift_start")
		s.shift_end = r.read_time(d, "shift_end")
		s.qualifications = r.read_ids(d, "qualifications", false)
		s.status = r.read_enum(d, "status", Enums.StaffStatus, false, Enums.StaffStatus.AVAILABLE) as Enums.StaffStatus
		if _dup(world.staff, s.id, "staff[%d]" % i, report):
			continue
		world.staff[s.id] = s


static func _dup(dict: Dictionary, id: StringName, ctx: String, report: ValidationReport) -> bool:
	if dict.has(id):
		report.error(&"DUPLICATE_ID", "%s: id duplicado «%s»" % [ctx, id])
		return true
	return false
