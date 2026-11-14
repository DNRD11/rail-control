class_name StaffMember
extends RefCounted
## Maquinista o interventor.

var id: StringName = &""
var name: String = ""
var role: Enums.StaffRole = Enums.StaffRole.DRIVER
var base_station_id: StringName = &""
var shift_start: int = 0
var shift_end: int = 0
var qualifications: Array[StringName] = []
var status: Enums.StaffStatus = Enums.StaffStatus.AVAILABLE
