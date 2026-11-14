class_name ValidationReport
extends RefCounted
## Resultado de cargar/validar datos: errores (bloquean) y avisos (informan).

enum Severity { ERROR, WARNING }

class Issue extends RefCounted:
	var severity: Severity
	var code: StringName
	var message: String

	func _init(p_severity: Severity, p_code: StringName, p_message: String) -> void:
		severity = p_severity
		code = p_code
		message = p_message

	func _to_string() -> String:
		var tag: String = "ERROR" if severity == Severity.ERROR else "AVISO"
		return "[%s %s] %s" % [tag, code, message]

var issues: Array[Issue] = []


func error(code: StringName, message: String) -> void:
	issues.append(Issue.new(Severity.ERROR, code, message))


func warning(code: StringName, message: String) -> void:
	issues.append(Issue.new(Severity.WARNING, code, message))


func has_errors() -> bool:
	return error_count() > 0


func error_count() -> int:
	return _count(Severity.ERROR)


func warning_count() -> int:
	return _count(Severity.WARNING)


func count_code(code: StringName) -> int:
	var n: int = 0
	for issue: Issue in issues:
		if issue.code == code:
			n += 1
	return n


func has_code(code: StringName) -> bool:
	return count_code(code) > 0


func merge(other: ValidationReport) -> void:
	issues.append_array(other.issues)


## Texto multilínea para consola/logs.
func summary() -> String:
	var lines: PackedStringArray = []
	for issue: Issue in issues:
		lines.append(str(issue))
	lines.append("%d errores, %d avisos" % [error_count(), warning_count()])
	return "\n".join(lines)


func _count(severity: Severity) -> int:
	var n: int = 0
	for issue: Issue in issues:
		if issue.severity == severity:
			n += 1
	return n
