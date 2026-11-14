class_name DictReader
extends RefCounted
## Lector tipado de campos de un Dictionary de JSON. Reporta problemas en el ValidationReport
## con contexto «archivo[idx].campo». Un int válido puede llegar como float entero.

var report: ValidationReport
var context: String


func _init(p_report: ValidationReport, p_context: String) -> void:
	report = p_report
	context = p_context


func read_string(d: Dictionary, key: String, required: bool = true, default: String = "") -> String:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
		_bad_type(key, "texto")
		return default
	return String(v)


func read_id(d: Dictionary, key: String, required: bool = true, default: StringName = &"") -> StringName:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
		_bad_type(key, "identificador (texto)")
		return default
	var s: String = String(v).strip_edges()
	if s.is_empty() and required:
		report.error(&"BAD_VALUE", "%s.%s: identificador vacío" % [context, key])
		return default
	return StringName(s)


func read_int(d: Dictionary, key: String, required: bool = true, default: int = 0) -> int:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) == TYPE_INT:
		return v as int
	if typeof(v) == TYPE_FLOAT and is_equal_approx(floorf(v as float), v as float):
		return int(v as float)
	_bad_type(key, "entero")
	return default


func read_float(d: Dictionary, key: String, required: bool = true, default: float = 0.0) -> float:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return v as float
	_bad_type(key, "número")
	return default


func read_bool(d: Dictionary, key: String, required: bool = true, default: bool = false) -> bool:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_BOOL:
		_bad_type(key, "booleano")
		return default
	return v as bool


## "HH:MM[:SS]" → segundos. Si falta y no es obligatorio devuelve `default` (SimTime.NONE).
func read_time(d: Dictionary, key: String, required: bool = true, default: int = SimTime.NONE) -> int:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING:
		_bad_type(key, "hora «HH:MM»")
		return default
	var t: int = SimTime.parse(v as String)
	if t == SimTime.NONE:
		report.error(&"BAD_VALUE", "%s.%s: hora no válida «%s»" % [context, key, v])
		return default
	return t


func read_enum(d: Dictionary, key: String, enum_dict: Dictionary, required: bool = true, default: int = 0) -> int:
	if not _present(d, key, required):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING:
		_bad_type(key, "texto de enumeración")
		return default
	var value: int = Enums.parse(enum_dict, v as String, -1)
	if value == -1:
		report.error(&"BAD_VALUE", "%s.%s: valor desconocido «%s»" % [context, key, v])
		return default
	return value


func read_ids(d: Dictionary, key: String, required: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	if not _present(d, key, required):
		return out
	var v: Variant = d[key]
	if typeof(v) != TYPE_ARRAY:
		_bad_type(key, "lista de identificadores")
		return out
	for item: Variant in v as Array:
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			_bad_type(key, "lista de identificadores (texto)")
			return out
		out.append(StringName(String(item)))
	return out


func read_dicts(d: Dictionary, key: String, required: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _present(d, key, required):
		return out
	var v: Variant = d[key]
	if typeof(v) != TYPE_ARRAY:
		_bad_type(key, "lista de objetos")
		return out
	for item: Variant in v as Array:
		if typeof(item) != TYPE_DICTIONARY:
			_bad_type(key, "lista de objetos")
			return out
		out.append(item as Dictionary)
	return out


func _present(d: Dictionary, key: String, required: bool) -> bool:
	if d.has(key) and d[key] != null:
		return true
	if required:
		report.error(&"MISSING_FIELD", "%s: falta el campo «%s»" % [context, key])
	return false


func _bad_type(key: String, expected: String) -> void:
	report.error(&"BAD_TYPE", "%s.%s: se esperaba %s" % [context, key, expected])
