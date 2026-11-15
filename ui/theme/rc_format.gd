class_name RcFormat
extends RefCounted
## Formato de cifras para el jugador (español): importes, retrasos y cuentas atrás.


## Entero con separador de miles «.»: 1740 → «1.740».
static func count(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("−" if value < 0 else "") + digits + out


## Importe en euros con separador de miles «.» y decimales «,» solo si hacen falta: «3.000 €», «4.200,50 €».
static func eur(cents: int) -> String:
	var negative: bool = cents < 0
	var abs_cents: int = absi(cents)
	var whole: String = str(abs_cents / 100)
	var grouped: String = ""
	while whole.length() > 3:
		grouped = "." + whole.substr(whole.length() - 3) + grouped
		whole = whole.substr(0, whole.length() - 3)
	grouped = whole + grouped
	var rest: int = abs_cents % 100
	if rest != 0:
		grouped += ",%02d" % rest
	return "%s%s €" % ["−" if negative else "", grouped]


## Importe compacto para indicadores de espacio reducido: «8.900 €», «53,5 k€», «−12,7 k€».
static func eur_compact(cents: int) -> String:
	if absi(cents) < 1000000:
		return eur(cents / 100 * 100)
	var tenths: int = int(roundf(absf(float(cents)) / 10000.0))  # décimas de k€
	return "%s%d,%d k€" % ["−" if cents < 0 else "", tenths / 10, tenths % 10]


## Importe con signo explícito para resultados: «+1.200 €», «−350 €», «0 €».
static func eur_signed(cents: int) -> String:
	return ("+" + eur(cents)) if cents > 0 else eur(cents)


## Hora de jornada «HH:MM» a partir de segundos.
static func hhmm(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60]


## Minutos redondeados de una duración en segundos.
static func minutes(seconds: int) -> int:
	return int(roundf(float(seconds) / 60.0))


## Retraso o rango de retraso: «+25′» o «+25–90′».
static func delay_range(min_s: int, max_s: int) -> String:
	var lo: int = minutes(min_s)
	var hi: int = minutes(max_s)
	if lo >= hi:
		return "+%d′" % hi
	if lo <= 0:
		return "hasta +%d′" % hi
	return "+%d–%d′" % [lo, hi]


## Duración «mm:ss» (cuenta atrás).
static func mmss(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	return "%02d:%02d" % [s / 60, s % 60]
