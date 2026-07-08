extends RefCounted
## CRAFTING: crafts_for() gated by hub tab + research, and every CRAFTS entry resolving its
## material/produces ids to real cards and its research/skill keys to known content.
## (CARD_FILES lives in main.gd, out of make_sim's reach, so we scan data/cards here ourselves.)

func _known_card_ids() -> Dictionary:
	var ids := {}
	var dir = DirAccess.open("res://data/cards")
	if dir:
		for name in dir.get_files():
			if name.ends_with(".tres"):
				var cd = load("res://data/cards/" + name)
				if cd != null and cd.id != "":
					ids[cd.id] = true
	return ids

func run(tree, h) -> void:
	var g = tree.make_sim(4)

	# tab filter: the tools crafts show under "tools", not under "tailoring"
	var tools = g.crafts_for("tools")
	h.expect("craft_tinder" in tools, "craft_tinder shows under tools (needs no research)")
	h.expect(not ("craft_tinder" in g.crafts_for("tailoring")), "craft_tinder does not show under tailoring")
	h.expect_eq(g.crafts_for("nowhere").size(), 0, "an unknown tab offers no crafts")

	# research gating: craft_mallet is hidden until r_workbench is worked out
	h.expect(not ("craft_mallet" in g.crafts_for("tools")), "craft_mallet is gated by research")
	g.researched["r_workbench"] = true
	h.expect("craft_mallet" in g.crafts_for("tools"), "craft_mallet appears once r_workbench is researched")

	# every craft resolves its ids: materials + produces are real cards, research + skill keys are known
	var cards = _known_card_ids()
	for cid in g.CRAFTS:
		var craft = g.CRAFTS[cid]
		for mid in craft.get("materials", {}):
			h.expect(cards.has(str(mid)), "CRAFTS[%s] material %s is a real card" % [cid, str(mid)])
		h.expect(cards.has(str(craft.get("produces", ""))), "CRAFTS[%s] produces a real card (%s)" % [cid, str(craft.get("produces", ""))])
		var creq = str(craft.get("requires_research", ""))
		h.expect(creq == "" or g.RESEARCH.has(creq), "CRAFTS[%s] requires_research is a known project" % cid)
		var sk = craft.get("skill", [])
		h.expect(sk.size() == 2 and g.skills.has(str(sk[0])), "CRAFTS[%s] names a known skill" % cid)
