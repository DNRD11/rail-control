extends TestCase


func test_parse_hh_mm() -> void:
	assert_eq(SimTime.parse("06:30"), 6 * 3600 + 30 * 60)
	assert_eq(SimTime.parse("00:00"), 0)


func test_parse_with_seconds_and_spaces() -> void:
	assert_eq(SimTime.parse(" 07:48:15 "), 7 * 3600 + 48 * 60 + 15)


func test_parse_allows_next_day_hours() -> void:
	assert_eq(SimTime.parse("25:10"), 25 * 3600 + 600)


func test_parse_invalid_returns_none() -> void:
	for bad: String in ["", "abc", "12", "12:60", "12:00:60", "48:00", "-1:00", "1:2:3:4", "12:xx"]:
		assert_eq(SimTime.parse(bad), SimTime.NONE, "texto «%s»" % bad)


func test_format() -> void:
	assert_eq(SimTime.format(6 * 3600 + 30 * 60), "06:30")
	assert_eq(SimTime.format(7 * 3600 + 48 * 60 + 5, true), "07:48:05")


func test_format_none() -> void:
	assert_eq(SimTime.format(SimTime.NONE), "--:--")
	assert_eq(SimTime.format(SimTime.NONE, true), "--:--:--")


func test_roundtrip() -> void:
	for t: int in [0, 59, 3600, 45296, 86399]:
		assert_eq(SimTime.parse(SimTime.format(t, true)), t)
