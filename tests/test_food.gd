extends RefCounted
## FOOD: rats drop meat, which is eaten raw or cooked over a fire.
## Verifies the meat cards load, the rat's drop is wired, and the generic cook recipe exists.

func run(tree, h) -> void:
	var g = tree.make_sim(41)
	var burning_tinder: CardData = load("res://data/cards/burning_tinder.tres")
	h.expect_eq(burning_tinder.lifetime_mins, 30, "burning tinder expires after thirty in-game minutes")
	g.card_state["hearth"] = 50.0
	g.lit_sources["hearth"] = true
	g.extinguish("hearth")
	h.expect(not g.is_lit("hearth"), "a lit fire source can be extinguished")
	h.expect_eq(g.card_state["hearth"], 50.0, "extinguishing preserves remaining fuel")

	# the two meat cards load as items
	var raw: CardData = load("res://data/cards/rat_meat.tres")
	h.expect(raw != null, "rat_meat.tres loads")
	h.expect_eq(raw.id, "rat_meat", "rat_meat id")
	h.expect_eq(raw.kind, "item", "rat_meat is an item")
	var cooked: CardData = load("res://data/cards/cooked_rat_meat.tres")
	h.expect(cooked != null, "cooked_rat_meat.tres loads")
	h.expect_eq(cooked.id, "cooked_rat_meat", "cooked_rat_meat id")
	h.expect_eq(cooked.kind, "item", "cooked_rat_meat is an item")

	# the rat drops raw meat; the zombie drops nothing
	var rat: CardData = load("res://data/cards/rat.tres")
	h.expect_eq(rat.drops, "rat_meat", "rat drops rat_meat")
	var zombie: CardData = load("res://data/cards/zombie.tres")
	h.expect_eq(zombie.drops, "", "zombie drops nothing")

	# the generic cook recipe is wired in main.gd. main.gd cannot be instanced here (it depends
	# on the Game autoload, absent in the -s harness), so assert the entry from its source.
	var f := FileAccess.open("res://main.gd", FileAccess.READ)
	h.expect(f != null, "main.gd source opens")
	var src := f.get_as_text() if f != null else ""
	h.expect(src.contains("\"rat_meat\": {\"fire_source\":"), "RECIPES cooks rat meat at any local fire source")
	h.expect(src.contains("\"effect\": \"cook\", \"spawn\": \"cooked_rat_meat\""), "the hearth recipe cooks into cooked_rat_meat")

	# Containers show their contents and keep newly boiled water unsafe until it cools.
	var bottle: CardData = load("res://data/cards/plastic_bottle.tres")
	h.expect(bottle.cover_image_empty != null, "bottle has empty-state art")
	h.expect(bottle.cover_image_water != null, "bottle has clean-water art")
	h.expect(bottle.cover_image_dirty_water != null, "bottle has dirty-water art")
	h.expect(bottle.cover_image_boiling_water != null, "bottle has boiling-water art")
	h.expect(bottle.cover_image_fuel != null, "bottle has fuel art")
	h.expect(src.contains("src.boil(rmins + 30)"), "boiled water cools thirty minutes after the boiling action")
	var card_file := FileAccess.open("res://card.gd", FileAccess.READ)
	var card_src := card_file.get_as_text() if card_file != null else ""
	h.expect(card_src.contains("content = \"boiling_water\""), "boiling water is a distinct container content")
	h.expect(card_src.contains("func cool_if_ready()"), "hot container contents can cool into normal water")

	var hearth: CardData = load("res://data/cards/hearth.tres")
	h.expect(hearth.cover_image_empty != null, "hearth has empty-fuel art")
	h.expect(hearth.cover_image_low != null, "hearth has low-fuel art")
	h.expect(hearth.cover_image_lit_low != null, "hearth has lit low-fuel art")

	var lighter: CardData = load("res://data/cards/lighter.tres")
	h.expect(lighter.cover_image_empty != null, "lighter has distinct empty-fuel art")
	h.expect(card_src.contains("not data.is_container and state_value <= 0.0"), "generic stateful tools use their zero-state art")

	for weapon_art in ["fire_axe", "lead_pipe", "kitchen_knife", "crowbar", "claw_hammer", "makeshift_spear"]:
		h.expect(load("res://assets/card_art/%s.png" % weapon_art) != null, "%s card art loads" % weapon_art)

	var antibiotics: CardData = load("res://data/cards/antibiotics.tres")
	h.expect_eq(antibiotics.state_kind, "charges", "antibiotics use discrete remaining-pill state")
	h.expect_eq(antibiotics.state_start, 6.0, "antibiotics start with six pills")
	h.expect_eq(antibiotics.state_max, 6.0, "antibiotics are capped at six pills")
	h.expect_eq(antibiotics.cover_images_by_state.size(), 7, "antibiotics have art for counts zero through six")
	for image in antibiotics.cover_images_by_state:
		h.expect(image != null, "every antibiotics count image loads")
	h.expect(src.contains("\"state_delta\": -1.0"), "taking an antibiotic removes one pill rather than the whole card")

	# PRESERVATION: cooked meat can be smoked into a keeps-well ration for winter.
	var preserved: CardData = load("res://data/cards/preserved_meat.tres")
	h.expect(preserved != null, "preserved_meat.tres loads")
	h.expect_eq(preserved.id, "preserved_meat", "preserved_meat id")
	h.expect_eq(preserved.kind, "item", "preserved_meat is an item")
	h.expect(src.contains("\"cooked_rat_meat\": {\"fire_source\":"), "RECIPES smokes cooked meat at any local fire source")
	h.expect(src.contains("\"effect\": \"smoke\", \"spawn\": \"preserved_meat\""), "the smoke recipe preserves into preserved_meat")
