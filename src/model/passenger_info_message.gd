class_name PassengerInfoMessage
extends RefCounted
## Aviso a los viajeros de un servicio afectado por una incidencia (DATA_MODEL.md §6/§7).

const CHANNEL_ON_BOARD: StringName = &"ON_BOARD"
const CHANNEL_STATION: StringName = &"STATION"
const CHANNEL_APP: StringName = &"APP"

var id: StringName = &""
var service_id: StringName = &""
var channel: StringName = CHANNEL_APP
var template_id: StringName = &"DELAY_NOTICE"
var time: int = 0
var incident_id: StringName = &""
