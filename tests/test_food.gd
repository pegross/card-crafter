extends RefCounted
## FOOD: rats drop meat, which is eaten raw or cooked over a fire.
## Verifies the meat cards load, the rat's drop is wired, and the generic cook recipe exists.

func run(_tree, h) -> void:
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
	h.expect(src.contains("\"rat_meat\": {\"hearth\":"), "RECIPES has a rat_meat -> hearth entry")
	h.expect(src.contains("\"effect\": \"cook\", \"spawn\": \"cooked_rat_meat\""), "the hearth recipe cooks into cooked_rat_meat")

	# PRESERVATION: cooked meat can be smoked into a keeps-well ration for winter.
	var preserved: CardData = load("res://data/cards/preserved_meat.tres")
	h.expect(preserved != null, "preserved_meat.tres loads")
	h.expect_eq(preserved.id, "preserved_meat", "preserved_meat id")
	h.expect_eq(preserved.kind, "item", "preserved_meat is an item")
	h.expect(src.contains("\"cooked_rat_meat\": {\"hearth\":"), "RECIPES has a cooked_rat_meat -> hearth entry")
	h.expect(src.contains("\"effect\": \"smoke\", \"spawn\": \"preserved_meat\""), "the smoke recipe preserves into preserved_meat")
