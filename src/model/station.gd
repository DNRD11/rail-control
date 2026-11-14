class_name Station
extends RefCounted
## Estación o apeadero de una línea.

var id: StringName = &""
var code: String = ""
var name: String = ""
var km: float = 0.0
var min_dwell_s: int = 120
var min_turnaround_s: int = 900
var is_depot: bool = false
var schematic_label: String = ""
