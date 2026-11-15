class_name EconomyRules
extends RefCounted
## Reglas económicas ordinarias (data/rules/economy.json). Mecánica del simulador, no tarifas reales.

## Precio medio por viajero-km, en céntimos (admite decimales para afinar el equilibrado).
var price_per_pax_km_cents: float = 0.0
var operating_cost_per_vehicle_km_cents: int = 0
var driver_per_hour_cents: int = 0
var conductor_per_hour_cents: int = 0
## Canon ordinario por km de servicio recorrido.
var infra_charge_per_km_cents: int = 0
