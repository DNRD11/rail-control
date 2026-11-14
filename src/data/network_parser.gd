class_name NetworkParser
extends RefCounted
## Líneas, estaciones y tramos → World.


## `lines_raw`: un Dictionary por archivo de línea.
static func parse(lines_raw: Array[Dictionary], world: World, report: ValidationReport) -> void:
	for i: int in lines_raw.size():
		_parse_line(lines_raw[i], "lines[%d]" % i, world, report)


static func _parse_line(raw: Dictionary, ctx: String, world: World, report: ValidationReport) -> void:
	var r: DictReader = DictReader.new(report, ctx)
	var line: Line = Line.new()
	line.id = r.read_id(raw, "id")
	line.name = r.read_string(raw, "name", false, String(line.id))
	if world.lines.has(line.id):
		report.error(&"DUPLICATE_ID", "%s: línea duplicada «%s»" % [ctx, line.id])
		return
	var stations: Array[Dictionary] = r.read_dicts(raw, "stations")
	for j: int in stations.size():
		var st: Station = _parse_station(stations[j], "%s.stations[%d]" % [ctx, j], report)
		if world.stations.has(st.id):
			report.error(&"DUPLICATE_ID", "%s.stations[%d]: estación duplicada «%s»" % [ctx, j, st.id])
			continue
		world.stations[st.id] = st
		line.station_ids.append(st.id)
	var sections: Array[Dictionary] = r.read_dicts(raw, "sections")
	for j: int in sections.size():
		var sec: Section = _parse_section(sections[j], "%s.sections[%d]" % [ctx, j], report)
		if world.sections.has(sec.id):
			report.error(&"DUPLICATE_ID", "%s.sections[%d]: tramo duplicado «%s»" % [ctx, j, sec.id])
			continue
		world.sections[sec.id] = sec
		line.section_ids.append(sec.id)
	world.lines[line.id] = line


static func _parse_station(d: Dictionary, ctx: String, report: ValidationReport) -> Station:
	var r: DictReader = DictReader.new(report, ctx)
	var s: Station = Station.new()
	s.id = r.read_id(d, "id")
	s.code = r.read_string(d, "code", false, String(s.id))
	s.name = r.read_string(d, "name", false, s.code)
	s.km = r.read_float(d, "km")
	s.min_dwell_s = r.read_int(d, "min_dwell_s", false, 120)
	s.min_turnaround_s = r.read_int(d, "min_turnaround_s", false, 900)
	s.is_depot = r.read_bool(d, "is_depot", false, false)
	s.schematic_label = r.read_string(d, "schematic_label", false, s.name)
	return s


static func _parse_section(d: Dictionary, ctx: String, report: ValidationReport) -> Section:
	var r: DictReader = DictReader.new(report, ctx)
	var s: Section = Section.new()
	s.id = r.read_id(d, "id")
	s.from_station_id = r.read_id(d, "from")
	s.to_station_id = r.read_id(d, "to")
	s.length_km = r.read_float(d, "length_km")
	s.run_time_s = r.read_int(d, "run_time_s")
	s.stop_penalty_s = r.read_int(d, "stop_penalty_s", false, 180)
	s.track_count = r.read_int(d, "track_count", false, 2)
	return s
