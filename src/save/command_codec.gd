class_name CommandCodec
extends RefCounted
## Serializa/deserializa los comandos del `command_log` a diccionarios JSON. Vive en src/save porque src/sim
## no tiene to_dict/from_dict; si se añaden comandos nuevos, registrarlos aquí (o moverlo a cada Command).


## Diccionario vacío si el comando no es serializable (el guardado falla en voz alta).
static func to_dict(cmd: Command) -> Dictionary:
	var d: Dictionary = {"kind": String(cmd.kind), "applied_at": cmd.applied_at}
	if cmd is SetSpeedCommand:
		d["speed"] = (cmd as SetSpeedCommand).speed
	elif cmd is InjectDelayCommand:
		d["service_id"] = String((cmd as InjectDelayCommand).service_id)
		d["seconds"] = (cmd as InjectDelayCommand).seconds
	elif cmd is InformPassengersCommand:
		d["service_id"] = String((cmd as InformPassengersCommand).service_id)
		d["incident_id"] = String((cmd as InformPassengersCommand).incident_id)
	elif cmd is ResolveIncidentCommand:
		var rc: ResolveIncidentCommand = cmd as ResolveIncidentCommand
		d["incident_id"] = String(rc.incident_id)
		d["option_type"] = String(rc.option_type)
		d["params"] = rc.params.duplicate(true)
	else:
		push_error("Comando no serializable: %s" % cmd.kind)
		return {}
	return d


static func from_dict(d: Dictionary) -> Command:
	var cmd: Command = null
	match String(d.get("kind", "")):
		"SET_SPEED":
			cmd = SetSpeedCommand.make(int(d.get("speed", 1)))
		"INJECT_DELAY":
			cmd = InjectDelayCommand.make(StringName(String(d.get("service_id", ""))), int(d.get("seconds", 0)))
		"INFORM_PASSENGERS":
			cmd = InformPassengersCommand.make(StringName(String(d.get("service_id", ""))),
					StringName(String(d.get("incident_id", ""))))
		"RESOLVE_INCIDENT":
			cmd = ResolveIncidentCommand.make(StringName(String(d.get("incident_id", ""))),
					StringName(String(d.get("option_type", ""))), (d.get("params", {}) as Dictionary).duplicate(true))
	if cmd != null:
		cmd.applied_at = int(d.get("applied_at", -1))
	return cmd
