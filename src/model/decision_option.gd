class_name DecisionOption
extends RefCounted
## Opción de decisión ofrecida para una incidencia, con su previsualización.

var option_type: StringName = &""
var available: bool = true
var unavailable_reason: String = ""
var preview: OptionPreview = OptionPreview.new()
var params: Dictionary = {}
