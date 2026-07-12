extends RefCounted
## ALARM CLOCK: recurring daily scheduling is deterministic and crosses midnight cleanly.

func run(tree, h) -> void:
	h.expect(load("res://assets/card_art/alarm_clock.png") != null, "alarm clock artwork imports")
	var clock_data = load("res://data/cards/alarm_clock.tres")
	h.expect(clock_data != null and clock_data.id == "alarm_clock", "alarm clock card resource loads")
	var g = tree.make_sim(31)
	h.expect_eq(g.alarm_at, -1, "a fresh game has no alarm set")

	var same_day: int = g.set_alarm(9, 15)
	h.expect_eq(same_day, g.day * 1440 + 9 * 60 + 15, "a later time schedules today")
	h.expect_eq(g.minutes_until_alarm(), 75, "alarm reports exact minutes remaining")
	h.expect_eq(g.alarm_hhmm(), "09:15", "alarm displays its configured clock time")
	h.expect(g.alarm_is_pending(), "a future alarm is pending")

	var next_day: int = g.set_alarm(7, 30)
	h.expect_eq(next_day, (g.day + 1) * 1440 + 7 * 60 + 30, "an earlier time schedules tomorrow")
	h.expect_eq(g.minutes_until_alarm(), 23 * 60 + 30, "overnight alarm duration crosses midnight")

	g.advance_time(23 * 60 + 30)
	h.expect_eq(g.alarm_ring_count, 1, "alarm rings when ordinary waking time crosses its minute")
	h.expect_eq(g.minutes_until_alarm(), 24 * 60, "alarm rearms for the same time tomorrow")
	h.expect(g.alarm_is_pending(), "recurring alarm remains pending after it rings")
	g.advance_time(24 * 60)
	h.expect_eq(g.alarm_ring_count, 2, "alarm rings again the next day without being reset")
	h.expect_eq(g.alarm_hhmm(), "07:30", "recurring alarm keeps the configured time of day")
	g.clear_alarm()
	h.expect_eq(g.alarm_at, -1, "clearing disables the alarm")
	g.advance_time(24 * 60)
	h.expect_eq(g.alarm_ring_count, 2, "disabled alarm no longer rings")
