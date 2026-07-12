extends RefCounted
## COMBAT / TRAUMA: data-driven weapons, always-available exhausted attacks, unique wound cards,
## continuous blood loss, pain, cleaning, bandaging, infection risk, and reset behavior.

func run(tree, h) -> void:
	for id in ["fire_axe", "lead_pipe", "kitchen_knife", "crowbar", "claw_hammer", "makeshift_spear", "wooden_mallet"]:
		var weapon: CardData = load("res://data/cards/%s.tres" % id)
		h.expect(weapon != null, "%s weapon card loads" % id)
		h.expect(weapon.is_weapon, "%s is marked as a weapon" % id)
		h.expect(weapon.weapon_damage > 0.0, "%s has positive combat damage" % id)
		h.expect(weapon.weapon_stamina <= 5.0, "%s attack stamina stays modest" % id)

	var g = tree.make_sim(17)
	var first: Dictionary = g.create_wound(6.0, "a rat bite", "bite")
	var second: Dictionary = g.create_wound(11.0, "a zombie bite", "bite")
	h.expect_eq(g.wounds.size(), 2, "separate hits create separate wound instances")
	h.expect(int(first["uid"]) != int(second["uid"]), "wounds receive unique ids")
	h.expect(not g.conditions.has("wound"), "physical wounds are not stored as a condition")
	h.expect(g.conditions.get("pain", 0.0) > 0.0, "wounds derive a pain condition")

	var bleed = tree.make_sim(18)
	var major: Dictionary = bleed.create_wound(20.0, "a zombie attack", "laceration")
	bleed.advance_time(10)
	h.expect_near(float(bleed.meters["Blood"]), 65.0, "a grievous wound rapidly drains Blood over exact minutes", 0.01)
	h.expect(bleed.bleedout_minutes() > 0 and bleed.bleedout_minutes() <= 19, "bleedout estimate reflects current Blood and rate")
	h.expect(bleed.clean_wound(int(major["uid"])), "clean water treatment can mark a wound clean")
	var after_clean := float(bleed.meters["Blood"])
	bleed.advance_time(5)
	h.expect(float(bleed.meters["Blood"]) < after_clean, "cleaning alone does not stop bleeding")
	h.expect(bleed.bandage_wound(int(major["uid"])), "a bandage can bind an open wound")
	var after_bandage := float(bleed.meters["Blood"])
	bleed.advance_time(10)
	h.expect(float(bleed.meters["Blood"]) >= after_bandage, "bandaging stops further blood loss")
	h.expect_near(bleed.wound_bleed_rate(), 0.0, "a bandaged wound contributes no bleeding", 0.001)

	var lethal = tree.make_sim(19)
	lethal.create_wound(20.0, "a zombie attack", "laceration")
	lethal.advance_time(30)
	h.expect(lethal.dead, "an ignored major wound kills through blood loss")
	h.expect(lethal.obituary.contains("blood loss"), "bleeding death names blood loss")

	var exhausted = tree.make_sim(20)
	exhausted.meters["Energy"] = 0.0
	var roll: Dictionary = exhausted.strike_roll(18.0, 1.0)
	h.expect(roll.has("dmg"), "an exhausted survivor can still make an attack roll")
	exhausted.spend_combat_stamina(5.0)
	h.expect_eq(exhausted.meters["Energy"], 0.0, "combat stamina spending clamps at zero instead of blocking")

	var infected = tree.make_sim(21)
	var dirty: Dictionary = infected.create_wound(20.0, "an unclean bite", "bite")
	infected.bandage_wound(int(dirty["uid"]))
	infected.advance_time(120)
	var infection_queued := false
	for dose in infected.cond_pending:
		if str(dose.get("id", "")) == "infection":
			infection_queued = true
	h.expect(infection_queued, "an unclean bandaged wound can seed delayed infection")
	infected.reset()
	h.expect(infected.wounds.is_empty(), "reset clears persistent wound cards")
	h.expect_eq(infected.meters["Blood"], 100.0, "reset restores Blood")

	# --- wound-card read-outs: Recovery tracks healing; Infection rises unclean, drops when washed ---
	var ui = tree.make_sim(22)
	var cut: Dictionary = ui.create_wound(11.0, "a scrape", "cut")  # severity 2 (contamination 30)
	ui.bandage_wound(int(cut["uid"]))  # stop the bleeding so the wait does not kill the survivor
	var inf0 := int(ui.wound_infection_pct(cut))
	h.expect(inf0 > 0, "a fresh unclean wound reads some Infection")
	h.expect_eq(ui.wound_recovery_pct(cut), 0, "a fresh wound reads 0% Recovery")
	ui.meters["Hydration"] = 80.0
	ui.meters["Weight"] = 80.0
	ui.advance_time(120)  # left unclean, it festers
	h.expect(ui.wound_infection_pct(cut) > inf0, "Infection rises while a wound is left unclean")
	ui.clean_wound(int(cut["uid"]))
	h.expect(ui.wound_infection_pct(cut) < inf0, "washing with clean water drops Infection below its fresh level")
	cut["healing"] = 50.0
	h.expect_eq(ui.wound_recovery_pct(cut), 50, "Recovery reads the wound's healing progress")
