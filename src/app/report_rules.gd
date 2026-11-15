class_name ReportRules
extends RefCounted
## Umbrales de la nota del informe final (data/rules/report.json). Puntuación = media ponderada de
## calidad y percepción (0-100). Valida al cargar; si el archivo no es válido usa valores por defecto.

const PATH: String = "res://data/rules/report.json"

var weight_quality: float = 0.5
var weight_perception: float = 0.5
## Umbrales descendentes: [{grade: StringName, min_score: float}], el último debe ser 0.
var grades: Array[Dictionary] = [
	{"grade": &"A", "min_score": 85.0}, {"grade": &"B", "min_score": 70.0},
	{"grade": &"C", "min_score": 55.0}, {"grade": &"D", "min_score": 0.0}]
var errors: Array[String] = []


static func load_default(path: String = PATH) -> ReportRules:
	var r: ReportRules = ReportRules.new()
	if not FileAccess.file_exists(path):
		r.errors.append("No existe «%s»" % path)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			r.errors.append("«%s»: JSON no válido" % path)
		else:
			r._parse(parsed as Dictionary)
	for msg: String in r.errors:
		push_error("report.json: " + msg)
	return r


func grade_for(score: float) -> StringName:
	for g: Dictionary in grades:
		if score >= float(g["min_score"]):
			return g["grade"] as StringName
	return &"D"


func score(quality: float, perception: float) -> float:
	var total: float = weight_quality + weight_perception
	return (quality * weight_quality + perception * weight_perception) / total if total > 0.0 else 0.0


func _parse(d: Dictionary) -> void:
	var w: Dictionary = d.get("weights", {}) as Dictionary
	var wq: float = float(w.get("quality", 0.5))
	var wp: float = float(w.get("perception", 0.5))
	if wq < 0.0 or wp < 0.0 or wq + wp <= 0.0:
		errors.append("weights: pesos negativos o suma 0")
	else:
		weight_quality = wq
		weight_perception = wp
	var raw: Variant = d.get("grades", null)
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		errors.append("grades: debe ser una lista no vacía")
		return
	var parsed: Array[Dictionary] = []
	var prev: float = INF
	for item: Variant in raw as Array:
		if typeof(item) != TYPE_DICTIONARY or not (item as Dictionary).has("grade") \
				or not (item as Dictionary).has("min_score"):
			errors.append("grades: cada entrada necesita grade y min_score")
			return
		var m: float = float((item as Dictionary)["min_score"])
		if m < 0.0 or m > 100.0 or m >= prev:
			errors.append("grades: min_score debe estar en 0-100 y ser estrictamente descendente")
			return
		prev = m
		parsed.append({"grade": StringName(String((item as Dictionary)["grade"])), "min_score": m})
	if float(parsed[parsed.size() - 1]["min_score"]) != 0.0:
		errors.append("grades: el último umbral debe ser 0")
		return
	grades = parsed
