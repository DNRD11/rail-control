class_name TestCase
extends RefCounted
## Clase base de las pruebas. El runner crea una instancia nueva por cada método `test_*`,
## llama a `before_each()` antes y recoge `failures` después.

var failures: Array[String] = []
var assertions: int = 0


func before_each() -> void:
	pass


func _fail(message: String) -> void:
	failures.append(message)


func assert_true(cond: bool, message: String = "") -> void:
	assertions += 1
	if not cond:
		_fail("se esperaba true. %s" % message)


func assert_false(cond: bool, message: String = "") -> void:
	assertions += 1
	if cond:
		_fail("se esperaba false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("esperado %s pero se obtuvo %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("no se esperaba %s. %s" % [var_to_str(unexpected), message])


func assert_has_code(report: ValidationReport, code: StringName, message: String = "") -> void:
	assertions += 1
	if not report.has_code(code):
		_fail("el informe debería contener %s. %s\n%s" % [code, message, report.summary()])


func assert_lacks_code(report: ValidationReport, code: StringName, message: String = "") -> void:
	assertions += 1
	if report.has_code(code):
		_fail("el informe no debería contener %s. %s\n%s" % [code, message, report.summary()])


func assert_no_errors(report: ValidationReport, message: String = "") -> void:
	assertions += 1
	if report.has_errors():
		_fail("se esperaban 0 errores. %s\n%s" % [message, report.summary()])
