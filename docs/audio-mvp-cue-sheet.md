# Dead Air — internal demo MVP audio cue sheet

Status: planning only. No sounds in this document are integrated.

This inventory reflects the 39 card resources and actions currently implemented in
`main.gd`, `autoload/game.gd`, and `data/cards/`.

## Audio direction

The world should sound physical, old, cold, and close. Favor real Foley with
short, dark tails: worn wood, stiff cloth, weak flame, dirty water, corroded
metal, and rooms that absorb sound. Avoid bright mobile-game clicks, exaggerated
cinematic booms, clean sci-fi radio sweeps, and cheerful success jingles.

Silence is part of the palette. Most actions need one clear sound, not a wall of
sound. The oak, hearth, radio, and dangerous encounters are the hero moments.

## Priority

- **P0** — required for the internal demo to read and feel responsive.
- **P1** — important variation or atmosphere; add after all P0 cues work.
- **P2** — later polish, event detail, or highly specific variants.

File suffixes such as `_01–04` mean separate recordings, not pitch-shifted
copies of one recording.

## 1. Interface and card handling

These cues are deliberately quiet and material rather than electronic.

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `ui_card_lift_01–03` | Begin dragging any movable card | Dry paper/cardboard lift with a faint table scrape. |
| P0 | `ui_card_place_01–03` | Drop, reorder, pick up, or set down a card | Soft card-on-old-wood contact; no casino snap. |
| P0 | `ui_card_detail_open` | Open card, character, craft, research, or build detail | Single subdued paper movement. |
| P0 | `ui_panel_close` | Close detail or dismiss overlay | Softer reverse paper movement. |
| P0 | `ui_action_commit` | Valid action begins | Low wooden tick; confirmation without sounding rewarding. |
| P0 | `ui_action_blocked` | Invalid recipe, empty source, missing fire/material, full inventory | Muted wood knock; never an arcade buzzer. |
| P0 | `ui_item_revealed_01–02` | Search or trap produces an item/card | Small object set onto wood, kept understated. |
| P0 | `ui_time_pass` | Clock sweep after an action | Very faint clockwork/house-settling cue, short enough for repeated use. |
| P1 | `ui_research_complete` | Research completes | Pencil stop, paper fold, one restrained tonal breath. |
| P1 | `ui_build_complete` | Final construction phase completes | Solid final wooden/stone placement, no fanfare. |
| P1 | `ui_condition_worsens` | Wound, infection, gut bug, hypothermia escalation | Low body/cloth tension; felt more than heard. |

## 2. Location beds and movement

Loops must be seamless and sparse. They should sit very low under the interface.

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `amb_grounds_loop` | The Grounds | Cold open air, weak wind, dead weeds; almost no wildlife. |
| P0 | `amb_woods_loop` | The Woods | Bare branches, distant timber creaks, occasional leaf movement. |
| P0 | `amb_manor_loop` | Lordly Manor | Damp room tone, light structural settling, distant wind leakage. |
| P0 | `amb_cellar_loop` | Cellar | Close damp room, rare drip, faint rat movement; no horror drone. |
| P0 | `travel_outdoor_01–02` | Grounds ↔ Woods travel | Boots through wet leaves/soil plus cloth and breath; 1–2 second summary cue. |
| P0 | `threshold_interior_01–02` | Grounds ↔ Manor and Manor ↔ Cellar | Old door/floor movement; cellar version includes two stair creaks. |
| P1 | `weather_rain_loop` | Rain outdoors | Cold, thin rain; no thunder unless an event calls for it. |
| P1 | `weather_gale_loop` | Gale event | House timbers and shutters under pressure, not generic wind roar. |

## 3. Searching and gathering

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `search_outdoors_01–03` | Search Grounds; forage Woods | Brush, leaves, boots, an object disturbed. Randomize the variants. |
| P0 | `search_interior_01–03` | Search Manor; search Cellar | Drawer/cupboard movement, fabric, small debris. Cellar can pitch darker. |
| P1 | `search_nothing_found_01–02` | Search produces nothing | Movement stops; small empty scrape or exhale, not a failure jingle. |

## 4. Oak, logs, firewood, crafting, and construction

The oak must sound massive and reluctant. Ordinary woodwork can share a smaller
Foley family.

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `wood_axe_oak_01–05` | **Oak Tree — Fell the tree** | Real axe into a large standing trunk: dense impact, bark fracture, little ring. Five variants are important. |
| P0 | `wood_oak_fall` | Oak reaches 100% and becomes Log | Long groan, branch stress, heavy earth impact. Keep the fall larger than each chop. |
| P0 | `wood_split_01–04` | **Log — Split for firewood**; split kindling craft | Axe/wedge through dry rounds, shorter and sharper than oak strikes. |
| P0 | `wood_handling_01–03` | Firewood/card handling; materials consumed | Rough billets contacting each other or a floor. |
| P0 | `construction_wood_01–03` | Door, shutters, workbench, mallet, snare work | Saw/plane/mallet montage condensed to about 1–2 seconds. |
| P0 | `construction_stone_01–02` | Rebuild Hearth phases | Stone scrape, grit, one heavy placement. |
| P1 | `door_repaired_close` | Final front-door phase | Heavy old door closes with a newly solid wooden thud. |
| P1 | `shutters_close` | Final window phase | Two wooden shutters seat and bar. |
| P1 | `workbench_final_hit` | Workbench completion | One mallet hit with a dense, stable wooden body. |
| P1 | `cloth_hide_stitch_01–02` | Tailor Hide Coat | Thick hide pull, needle/thread, stiff leather handling. |

## 5. Hearth, lighter, and cooking

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `lighter_flick_01–03` | **Lighter → Tinder** | Cheap wheel, weak gas, small ignition. Include one near-failure texture for variation. |
| P0 | `tinder_catch_01–02` | Tinder becomes Burning Tinder | Paper-dry fibers catching close to the microphone. |
| P0 | `hearth_ignite_01–02` | Burning Tinder → Hearth | Flame takes reluctantly, then a low wood crackle. |
| P0 | `hearth_add_wood_01–03` | Firewood → Hearth | Billet placement plus a restrained flare when already lit. |
| P0 | `hearth_fire_loop` | Hearth while lit | Seamless low fire, sparse pops, not a roaring fireplace. |
| P0 | `cook_meat_01–02` | Rat Meat → Cooked Rat Meat | Weak spit and fat sizzle over an open fire. |
| P0 | `water_boiling` | Boil dirty water; steep herbs | Small vessel beginning to simmer; reusable base layer. |
| P0 | `herbs_steep` | Herbs → Herbal Remedy | Dry herbs crushed/dropped, liquid stirred once. |
| P1 | `meat_smoking` | Cooked → Preserved Meat | Fire crackle, rack/cord creak, dry handling; short summary cue. |
| P1 | `fireside_rest` | Sit by the lit Hearth | Low fire, fabric settle, slow exhale. |

## 6. Water, containers, eating, clothing, and medicine

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `water_fill_01–02` | Bottle/canister filled at Stream or Rain Barrel | Cold water into a partly hollow container. |
| P0 | `liquid_pour_01–02` | Bottle ↔ canister; refuel Lighter | Short controlled pour. Fuel version can reuse it with a darker EQ. |
| P0 | `drink_01–02` | Stream, barrel, bottle, remedy | Quiet swallow and container movement; keep mouth sounds restrained. |
| P0 | `eat_tinned` | Canned Food — Eat cold | Spoon/tin scrape and one subdued bite. |
| P0 | `eat_dry_01–02` | Forage Food; Preserved Meat | Tough, dry bite and wrapper/hand movement. |
| P0 | `eat_meat_01–02` | Raw, cooked, or spoiled meat | Wet/tough bite; raw/spoiled action uses the harsher variant. |
| P0 | `medicine_pills` | Take Antibiotics | Small bottle/tin, two pills, dry swallow. |
| P0 | `bandage_apply_01–02` | Bind wounds | Cloth tear, wrap tension, knot. |
| P0 | `cloth_wrap_01–02` | Wool Blanket — Wrap up; rest/sleep | Heavy wool pulled close and body settling. |
| P0 | `coat_on_off_01–02` | Wear/remove Hide Coat | Stiff hide and clothing friction. |
| P1 | `food_spoils` | Perishable card becomes Spoiled Meat | Damp soft movement with a faint fly/room texture; very subtle. |

## 7. Radio

The radio is a signature object and narrative channel. It needs separate states,
not one generic “radio sound.” Broadcast speech/music is a separate narrative
production task and must be original or explicitly licensed.

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `radio_switch_on_01–02` | **Radio — Listen** begins while powered | Real old rotary switch, electrical crack, low speaker wake-up. |
| P0 | `radio_tuning_01–03` | Listening/searching for a signal | Real AM/VHF tuning fragments: unstable whistles, hum, and narrow-band static. |
| P0 | `radio_static_loop` | No broadcast or repeat listen | Seamless, subdued dead air with irregular interference. |
| P0 | `radio_signal_found` | Director supplies a forecast/warning | Static briefly resolves into a narrow signal; no triumphant sting. |
| P0 | `radio_switch_off_01–02` | Listen ends | Mechanical click with speaker/static collapse. |
| P0 | `radio_dead_switch` | After grid failure | Switch and dry electrical tick, but no powered static. |
| P1 | `radio_broadcast_weather` | Weather forecast category | Original filtered voice fragments or encoded tones. |
| P1 | `radio_broadcast_threat` | Horde warning category | Original urgent broadcast, partially lost in interference. |

Existing CC0 audition material is documented in
`demos/sourced_audio/SOURCE_LICENSES.md`. `radio_power_on_cc0_preview.mp3` and
`radio_static_cc0.mp3` are useful references/ingredients; production should use
original-quality source files.

## 8. Trapping and creatures

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `snare_set_01–02` | Snare — Set | Bent wood tension, cord/noose, brush placed back. |
| P0 | `snare_empty` | Set Snare — Check, no catch | Trigger/cord movement and an empty brush rustle. |
| P0 | `snare_catch` | Set Snare — successful check | Tight cord, bent stave, small dead weight in brush; no animal cry. |
| P0 | `encounter_rat` | Rat revealed / combat begins | Close skitter, scratch, one defensive squeak. |
| P0 | `encounter_zombie` | Zombie revealed / combat begins | Distant cloth/foot drag and restrained ruined breath. Avoid stock monster roars. |

## 9. Combat, harm, rest, and death

| Priority | Needed files | Covers | Direction |
|---|---|---|---|
| P0 | `combat_swing_01–03` | Player strike, including miss | Short improvised-weapon/arm movement; weapon is currently abstract. |
| P0 | `combat_hit_01–03` | Player lands a strike | Cloth/body impact with little cinematic bass. |
| P0 | `combat_rat_attack_01–02` | Rat damages player | Scramble, snap, clothing contact. |
| P0 | `combat_zombie_attack_01–02` | Zombie damages player | Heavy grab/body impact and ruined breath. |
| P0 | `combat_player_hurt_01–02` | Wound flash | Breath knocked out plus cloth/body movement; avoid voiced hero grunts for now. |
| P0 | `combat_enemy_down_01–02` | Enemy defeated | Body/creature drops onto the local surface. |
| P0 | `combat_flee` | Flee action | Rapid retreating steps and clothing pull. |
| P0 | `sleep_settle` | Sleep until rested | Clothing/body settles; room tone remains. |
| P0 | `collapse` | Forced sleep at zero Energy | Knee/body drop and cloth; serious but not a combat hit. |
| P0 | `death` | Death modal | Environment recedes into low room tone/breath loss; no musical sting. |
| P1 | `wake_01–02` | Normal or interrupted waking | Fabric movement and breath; interrupted variant is sharper. |
| P1 | `siege_distant` | Horde event begins | Distant bodies, wood pressure, sparse ruined voices. |
| P1 | `siege_breach` | Shelter defense fails | Door/timber strain and one violent break. |

## Card coverage map

This table ensures every current card either has an action cue or is explicitly
identified as passive/material-only.

| Cards | Current interaction | Cue family |
|---|---|---|
| The Grounds | Search; travel/threshold | `search_outdoors`, `travel_outdoor`, `threshold_interior` |
| The Woods | Forage; travel | `search_outdoors`, `travel_outdoor`, `amb_woods_loop` |
| Lordly Manor | Search; enter/leave | `search_interior`, `threshold_interior`, `amb_manor_loop` |
| Cellar | Search; stairs | `search_interior`, `threshold_interior`, `amb_cellar_loop` |
| Oak Tree | Fell; final fall | `wood_axe_oak`, `wood_oak_fall` |
| Log | Split for firewood | `wood_split` |
| Firewood | Hearth fuel; craft/build material | `wood_handling`, `hearth_add_wood`, woodwork families |
| Broken Hearth | Open rebuild project | UI open; `construction_stone` during work |
| Hearth | Add wood, ignite, boil, cook, steep, smoke, sit | Hearth/cooking families |
| Lighter | Light tinder; refuel | `lighter_flick`, `liquid_pour` |
| Tinder / Burning Tinder | Ignite; carry flame to hearth | `tinder_catch`, `hearth_ignite` |
| Stream / Rain Barrel | Drink; fill container | `drink`, `water_fill` |
| Plastic Bottle / Gas Canister | Fill, pour, drink; lighter refuel; boil | Water/container families |
| Herbs / Herbal Remedy | Steep; drink/cure | `herbs_steep`, `water_boiling`, `drink` |
| Canned Food | Eat cold | `eat_tinned` |
| Forage Food / Preserved Meat | Eat | `eat_dry` |
| Rat Meat / Cooked Rat Meat / Spoiled Meat | Eat, cook, smoke | `eat_meat`, cooking families |
| Antibiotics | Treat infection/gut bug | `medicine_pills` |
| Bandage | Treat wound | `bandage_apply` |
| Wool Blanket | Wrap up | `cloth_wrap` |
| Hide Coat | Wear/remove | `coat_on_off` |
| Snare / Set Snare | Set/check | Snare family |
| Rat / Zombie | Fight | Encounter and combat families |
| Radio | Listen; powered/static/signal/dead states | Radio family |
| Stone | Hearth/build material only | `construction_stone` when consumed in work |
| Hide | Coat material only | `cloth_hide_stitch` when consumed in tailoring |
| Wooden Mallet | Currently passive result; no direct action | Card handling only for MVP |
| Matches | Currently has no action or recipe | Card handling only until implemented |
| Dirty Water card | Currently represented mainly as container content | Water/container families |
| Survivor | Character/rest/sleep/equipment access | Cloth, sleep, collapse, condition cues |

## Recommended production order

1. Card/UI feedback and the four location ambience loops.
2. Oak/log/firewood and the complete hearth ignition chain.
3. Radio powered, static, signal, and dead states.
4. Water, eating, medicine, clothing, search, travel, and sleep.
5. Rat/zombie combat and snares.
6. Construction/crafting variations, weather, siege, research, and condition polish.

The first three steps form the strongest early audio proof: they cover the most
repeated interactions and the three objects that define the game's identity.
