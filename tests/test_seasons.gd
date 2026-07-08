extends RefCounted
## SEASONS: season()/season_name() boundaries, winter arriving on day 7, days_left_in_season().
## Cyclical Autumn/Winter/Spring/Summer, SEASON_LENGTH = 6 in-game days each.

func run(tree, h) -> void:
	var g = tree.make_sim(1)

	# day 1 = the very start of Autumn
	h.expect_eq(g.season(), 0, "day 1 is season 0")
	h.expect_eq(g.season_name(), "Autumn", "day 1 is Autumn")
	h.expect_eq(g.days_left_in_season(), 6, "6 days left in season on day 1")

	# last day of Autumn
	g.day = 6
	h.expect_eq(g.season_name(), "Autumn", "day 6 is still Autumn")
	h.expect_eq(g.days_left_in_season(), 1, "1 day left in season on day 6")

	# Winter arrives on day 7
	g.day = 7
	h.expect_eq(g.season(), 1, "day 7 is season 1")
	h.expect_eq(g.season_name(), "Winter", "Winter arrives on day 7")
	h.expect_eq(g.days_left_in_season(), 6, "6 days left in season on day 7")

	# remaining boundaries around the year
	g.day = 12
	h.expect_eq(g.season_name(), "Winter", "day 12 is still Winter")
	g.day = 13
	h.expect_eq(g.season_name(), "Spring", "Spring arrives on day 13")
	g.day = 19
	h.expect_eq(g.season_name(), "Summer", "Summer arrives on day 19")
	g.day = 25
	h.expect_eq(g.season_name(), "Autumn", "the cycle wraps back to Autumn on day 25")
