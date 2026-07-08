extends RefCounted
## DETERMINISM: two sims with the same rng.seed produce identical weather across advance_time;
## two sims with different seeds diverge.

func _weather_seq(tree, seed_val: int) -> String:
	var g = tree.make_sim(seed_val)
	var s := ""
	for i in range(80):
		g.advance_time(180)
		s += g.weather + ","
	g.free()
	return s

func run(tree, h) -> void:
	var a := _weather_seq(tree, 111)
	var b := _weather_seq(tree, 111)
	var c := _weather_seq(tree, 222)
	h.expect_eq(a, b, "same seed produces an identical weather sequence")
	h.expect(a != c, "a different seed produces a different weather sequence")
