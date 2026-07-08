extends RefCounted
## SIEGE: the shelter_defense() gradient (0.20 / 0.44 / 0.66) and its 0.90 ceiling, plus
## siege_breaches() falling as preparation rises.

func run(tree, h) -> void:
	var g = tree.make_sim(3)
	var loc := "lordly_manor"

	# defense gradient as sealing builds land
	h.expect_near(g.shelter_defense(loc), 0.20, "bare shelter defense is 0.20")
	g.builds["manor_door"] = true
	h.expect_near(g.shelter_defense(loc), 0.44, "a braced door raises defense to 0.44")
	g.builds["manor_windows"] = true
	h.expect_near(g.shelter_defense(loc), 0.66, "shuttered windows raise defense to 0.66")
	h.expect(g.shelter_defense(loc) <= 0.90, "defense never exceeds the 0.90 cap")
	h.expect_eq(g.shelter_defense("open_field"), 0.0, "open ground has no defense")

	# breaches fall as preparation rises (5 incoming waves)
	var g2 = tree.make_sim(3)
	h.expect_eq(g2.siege_breaches(5, loc), 4, "5 waves against a bare shelter -> 4 break in")
	g2.builds["manor_door"] = true
	h.expect_eq(g2.siege_breaches(5, loc), 3, "5 waves against a braced door -> 3 break in")
	g2.builds["manor_windows"] = true
	h.expect_eq(g2.siege_breaches(5, loc), 2, "5 waves against a fully prepared shelter -> 2 break in")
	h.expect_eq(g2.siege_breaches(5, "open_field"), 5, "5 waves on open ground -> all break in")
