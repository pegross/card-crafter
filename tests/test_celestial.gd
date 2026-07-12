extends RefCounted
## CELESTIAL CLOCK: the wandering body uses the exact 05:00/08:00 and 18:00/21:00
## boundaries shared by the environment daylight curve.

func run(_tree, h) -> void:
	h.expect(CelestialArc.is_sun_time(5 * 60), "sun rises onto the arc at 05:00")
	h.expect(CelestialArc.is_sun_time(20 * 60 + 59), "sun remains on the arc through dusk")
	h.expect(not CelestialArc.is_sun_time(21 * 60), "moon takes over at 21:00")
	h.expect(not CelestialArc.is_sun_time(4 * 60 + 59), "moon remains on the arc before dawn")
	h.expect_near(CelestialArc.arc_progress(5 * 60), 0.0, "sun begins at the eastern horizon")
	h.expect_near(CelestialArc.arc_progress(13 * 60), 0.5, "sun reaches the arc apex halfway through its visible span")
	h.expect_near(CelestialArc.arc_progress(21 * 60), 0.0, "moon begins at the eastern horizon")
	h.expect_near(CelestialArc.arc_progress(1 * 60), 0.5, "moon reaches the arc apex halfway through the night")
	h.expect_eq(CelestialArc.phase_name(6 * 60), "Dawn", "05:00–08:00 is dawn")
	h.expect_eq(CelestialArc.phase_name(12 * 60), "Daylight", "midday is daylight")
	h.expect_eq(CelestialArc.phase_name(19 * 60), "Dusk", "18:00–21:00 is dusk")
	h.expect_eq(CelestialArc.phase_name(23 * 60), "Night", "late evening is night")
	h.expect(load("res://assets/ui/celestial_sun.png") != null, "sun UI asset imports")
	h.expect(load("res://assets/ui/celestial_moon.png") != null, "moon UI asset imports")
