extends RefCounted
## SPOILAGE: Game.spoil_stage() reads fresh/turning/spoiled off an absolute spoil-minute,
## and abs_minute() tracks the action clock. (The rot-to-spoiled_meat transform lives in main.gd's
## view layer and is covered by the boot check, not here.)

func run(tree, h) -> void:
	var g = tree.make_sim(1)
	var now: int = g.abs_minute()
	h.expect_eq(g.spoil_stage(-1), 0, "never-spoil (-1) reads fresh")
	h.expect_eq(g.spoil_stage(now + 600), 0, "spoil far in the future reads fresh")
	h.expect_eq(g.spoil_stage(now + 100), 1, "within 4h of spoiling reads turning")
	h.expect_eq(g.spoil_stage(now), 2, "at the spoil minute reads spoiled")
	h.expect_eq(g.spoil_stage(now - 1), 2, "past the spoil minute reads spoiled")

	# abs_minute advances with the clock
	var before: int = g.abs_minute()
	g.advance_time(120)
	h.expect_eq(g.abs_minute(), before + 120, "abs_minute tracks day*1440 + minute")
