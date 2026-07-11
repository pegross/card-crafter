param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$library = Join-Path $ProjectRoot "demos/audio_source_library"
$selected = Join-Path $library "selected_mvp"
$kenneyRpg = Join-Path $library "extracted/kenney_rpg-audio_cc0/Audio"
$kenneyImpact = Join-Path $library "extracted/kenney_impact-sounds_cc0/Audio"
$kenneyUi = Join-Path $library "extracted/kenney_interface-sounds_cc0/Audio"
$oga100 = Join-Path $library "extracted/oga_sfx_100_v2_cc0"
$house = Join-Path $library "extracted/oga_more_household_sounds_cc0"
$food = Join-Path $library "extracted/oga_eating_crunches_cc0"
$undead = Join-Path $library "extracted/oga_undead_moans_cc0"
$room = Join-Path $library "extracted/oga_shop_room_tones_cc0"
$raw = Join-Path $library "raw_packs"
$firstDemos = Join-Path $ProjectRoot "demos/sourced_audio"

function Add-Candidate([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Missing source: $Source"
    }
    $target = Join-Path $selected $Destination
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $target -Force
}

$candidates = @(
    # Quiet, physical interface candidates.
    @((Join-Path $kenneyRpg "bookFlip1.ogg"), "00_ui/ui_card_lift_01.ogg"),
    @((Join-Path $kenneyRpg "bookFlip2.ogg"), "00_ui/ui_card_lift_02.ogg"),
    @((Join-Path $kenneyRpg "bookFlip3.ogg"), "00_ui/ui_card_lift_03.ogg"),
    @((Join-Path $kenneyRpg "bookPlace1.ogg"), "00_ui/ui_card_place_01.ogg"),
    @((Join-Path $kenneyRpg "bookPlace2.ogg"), "00_ui/ui_card_place_02.ogg"),
    @((Join-Path $kenneyRpg "bookPlace3.ogg"), "00_ui/ui_card_place_03.ogg"),
    @((Join-Path $kenneyRpg "bookOpen.ogg"), "00_ui/ui_card_detail_open.ogg"),
    @((Join-Path $kenneyRpg "bookClose.ogg"), "00_ui/ui_panel_close.ogg"),
    @((Join-Path $kenneyUi "tick_001.ogg"), "00_ui/ui_action_commit.ogg"),
    @((Join-Path $kenneyImpact "impactWood_light_000.ogg"), "00_ui/ui_action_blocked.ogg"),
    @((Join-Path $kenneyRpg "handleSmallLeather.ogg"), "00_ui/ui_item_revealed_01.ogg"),
    @((Join-Path $kenneyRpg "handleSmallLeather2.ogg"), "00_ui/ui_item_revealed_02.ogg"),
    @((Join-Path $kenneyUi "tick_004.ogg"), "00_ui/ui_time_pass.ogg"),

    # Location beds and transitions. These are long source candidates, not final mixes.
    @((Join-Path $raw "oga_winter_wind_cc0.mp3"), "01_ambience/amb_grounds_loop.mp3"),
    @((Join-Path $raw "oga_forest_ambience_cc0.mp3"), "01_ambience/amb_woods_loop.mp3"),
    @((Join-Path $room "01 - LEGIT Audio - TheShopCollection_convenience_store_drinks_fridge_drone.mp3"), "01_ambience/amb_manor_loop.mp3"),
    @((Join-Path $raw "oga_cellar_drips_cc0.flac"), "01_ambience/amb_cellar_loop.flac"),
    @((Join-Path $kenneyImpact "footstep_grass_000.ogg"), "01_ambience/travel_outdoor_01.ogg"),
    @((Join-Path $kenneyImpact "footstep_grass_003.ogg"), "01_ambience/travel_outdoor_02.ogg"),
    @((Join-Path $kenneyRpg "doorOpen_1.ogg"), "01_ambience/threshold_interior_01.ogg"),
    @((Join-Path $kenneyRpg "creak2.ogg"), "01_ambience/threshold_interior_02.ogg"),

    # Search and forage ingredients.
    @((Join-Path $kenneyRpg "footstep03.ogg"), "02_search/search_outdoors_01.ogg"),
    @((Join-Path $kenneyRpg "cloth1.ogg"), "02_search/search_outdoors_02.ogg"),
    @((Join-Path $oga100 "sfx100v2_items_01.ogg"), "02_search/search_outdoors_03.ogg"),
    @((Join-Path $kenneyRpg "doorOpen_2.ogg"), "02_search/search_interior_01.ogg"),
    @((Join-Path $house "Paper & Stationery/Stationery_14.wav"), "02_search/search_interior_02.wav"),
    @((Join-Path $house "Cloth/Cloth_03.wav"), "02_search/search_interior_03.wav"),

    # Oak, woodwork, stonework, and construction.
    @((Join-Path $firstDemos "tree_chopping_axe_cc0_preview.mp3"), "03_wood/wood_axe_oak_source_take.mp3"),
    @((Join-Path $firstDemos "tree_chop_fall_cc0.ogg"), "03_wood/wood_oak_fall.ogg"),
    @((Join-Path $kenneyRpg "chop.ogg"), "03_wood/wood_split_01.ogg"),
    @((Join-Path $kenneyImpact "impactWood_heavy_000.ogg"), "03_wood/wood_split_02.ogg"),
    @((Join-Path $kenneyImpact "impactWood_heavy_002.ogg"), "03_wood/wood_split_03.ogg"),
    @((Join-Path $kenneyImpact "impactWood_heavy_004.ogg"), "03_wood/wood_split_04.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_01.ogg"), "03_wood/wood_handling_01.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_02.ogg"), "03_wood/wood_handling_02.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_03.ogg"), "03_wood/wood_handling_03.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_hit_01.ogg"), "03_wood/construction_wood_01.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_hit_02.ogg"), "03_wood/construction_wood_02.ogg"),
    @((Join-Path $oga100 "sfx100v2_wood_hit_03.ogg"), "03_wood/construction_wood_03.ogg"),
    @((Join-Path $oga100 "sfx100v2_stones_01.ogg"), "03_wood/construction_stone_01.ogg"),
    @((Join-Path $oga100 "sfx100v2_stones_03.ogg"), "03_wood/construction_stone_02.ogg"),

    # Fire and cooking.
    @((Join-Path $raw "oga_lighter_click_cc0.flac"), "04_fire_cooking/lighter_flick_01.flac"),
    @((Join-Path $kenneyRpg "metalClick.ogg"), "04_fire_cooking/lighter_flick_02.ogg"),
    @((Join-Path $oga100 "sfx100v2_switch_01.ogg"), "04_fire_cooking/lighter_flick_03.ogg"),
    @((Join-Path $raw "oga_fireplace_loop_cc0.wav"), "04_fire_cooking/hearth_fire_loop.wav"),
    @((Join-Path $raw "oga_fireplace_loop_cc0.wav"), "04_fire_cooking/hearth_ignite_01_source.wav"),
    @((Join-Path $kenneyRpg "chop.ogg"), "04_fire_cooking/hearth_ignite_02_layer.ogg"),
    @((Join-Path $kenneyRpg "creak1.ogg"), "04_fire_cooking/tinder_catch_01.ogg"),
    @((Join-Path $kenneyRpg "creak3.ogg"), "04_fire_cooking/tinder_catch_02.ogg"),
    @((Join-Path $kenneyImpact "impactWood_light_001.ogg"), "04_fire_cooking/hearth_add_wood_01.ogg"),
    @((Join-Path $kenneyImpact "impactWood_light_002.ogg"), "04_fire_cooking/hearth_add_wood_02.ogg"),
    @((Join-Path $kenneyImpact "impactWood_light_003.ogg"), "04_fire_cooking/hearth_add_wood_03.ogg"),
    @((Join-Path $raw "oga_boiling_water_cc0.ogg"), "04_fire_cooking/water_boiling.ogg"),
    @((Join-Path $kenneyRpg "metalPot1.ogg"), "04_fire_cooking/cook_meat_01.ogg"),
    @((Join-Path $kenneyRpg "metalPot2.ogg"), "04_fire_cooking/cook_meat_02.ogg"),
    @((Join-Path $kenneyRpg "metalPot3.ogg"), "04_fire_cooking/herbs_steep.ogg"),

    # Water, food, medicine, and clothing.
    @((Join-Path $oga100 "sfx100v2_loop_water_01.ogg"), "05_survival/water_fill_01.ogg"),
    @((Join-Path $oga100 "sfx100v2_loop_water_02.ogg"), "05_survival/water_fill_02.ogg"),
    @((Join-Path $oga100 "sfx100v2_loop_water_03.ogg"), "05_survival/liquid_pour_01.ogg"),
    @((Join-Path $oga100 "sfx100v2_loop_water_02.ogg"), "05_survival/liquid_pour_02.ogg"),
    @((Join-Path $house "Drink/Drink_01.wav"), "05_survival/drink_01.wav"),
    @((Join-Path $house "Drink/Drink_04.wav"), "05_survival/drink_02.wav"),
    @((Join-Path $food "crunch.1.ogg"), "05_survival/eat_dry_01.ogg"),
    @((Join-Path $food "crunch.4.ogg"), "05_survival/eat_dry_02.ogg"),
    @((Join-Path $food "crunch.2.ogg"), "05_survival/eat_meat_01.ogg"),
    @((Join-Path $food "crunch.6.ogg"), "05_survival/eat_meat_02.ogg"),
    @((Join-Path $kenneyImpact "impactTin_medium_001.ogg"), "05_survival/eat_tinned.ogg"),
    @((Join-Path $house "Plastic/Plastic_03.wav"), "05_survival/medicine_pills.wav"),
    @((Join-Path $house "Cloth/Cloth_01.wav"), "05_survival/bandage_apply_01.wav"),
    @((Join-Path $house "Cloth/Cloth_05.wav"), "05_survival/bandage_apply_02.wav"),
    @((Join-Path $house "Cloth/Cloth_02.wav"), "05_survival/cloth_wrap_01.wav"),
    @((Join-Path $house "Cloth/Cloth_06.wav"), "05_survival/cloth_wrap_02.wav"),
    @((Join-Path $kenneyRpg "dropLeather.ogg"), "05_survival/coat_on_off_01.ogg"),
    @((Join-Path $kenneyRpg "clothBelt2.ogg"), "05_survival/coat_on_off_02.ogg"),

    # Radio signature states.
    @((Join-Path $firstDemos "radio_power_on_cc0_preview.mp3"), "06_radio/radio_switch_on_01.mp3"),
    @((Join-Path $raw "freesound_old_radio_switch_cc0_preview.mp3"), "06_radio/radio_switch_on_off_source.mp3"),
    @((Join-Path $raw "freesound_radio_tuning_cc0_preview.mp3"), "06_radio/radio_tuning_source.mp3"),
    @((Join-Path $firstDemos "radio_static_cc0.mp3"), "06_radio/radio_static_loop_source.mp3"),
    @((Join-Path $raw "freesound_radio_tuning_cc0_preview.mp3"), "06_radio/radio_signal_found_source.mp3"),
    @((Join-Path $raw "freesound_old_radio_switch_cc0_preview.mp3"), "06_radio/radio_switch_off_source.mp3"),
    @((Join-Path $oga100 "sfx100v2_switch_02.ogg"), "06_radio/radio_dead_switch.ogg"),

    # Trap and creature source candidates.
    @((Join-Path $kenneyRpg "creak1.ogg"), "07_creatures/snare_set_01.ogg"),
    @((Join-Path $kenneyRpg "clothBelt.ogg"), "07_creatures/snare_set_02.ogg"),
    @((Join-Path $kenneyRpg "creak3.ogg"), "07_creatures/snare_empty.ogg"),
    @((Join-Path $kenneyRpg "dropLeather.ogg"), "07_creatures/snare_catch.ogg"),
    @((Join-Path $raw "oga_enemy_sounds_cc0.ogg"), "07_creatures/encounter_creatures_source.ogg"),
    @((Join-Path $raw "freesound_rat_squeak_cc0_preview.mp3"), "07_creatures/encounter_rat.mp3"),
    @((Join-Path $undead "undead-1.ogg"), "07_creatures/encounter_zombie_01.ogg"),
    @((Join-Path $undead "undead-3.ogg"), "07_creatures/encounter_zombie_02.ogg"),

    # Combat, rest, collapse, and death ingredients.
    @((Join-Path $kenneyRpg "knifeSlice.ogg"), "08_combat/combat_swing_01.ogg"),
    @((Join-Path $kenneyRpg "knifeSlice2.ogg"), "08_combat/combat_swing_02.ogg"),
    @((Join-Path $kenneyRpg "drawKnife2.ogg"), "08_combat/combat_swing_03.ogg"),
    @((Join-Path $kenneyImpact "impactPunch_heavy_000.ogg"), "08_combat/combat_hit_01.ogg"),
    @((Join-Path $kenneyImpact "impactPunch_heavy_002.ogg"), "08_combat/combat_hit_02.ogg"),
    @((Join-Path $kenneyImpact "impactPunch_heavy_004.ogg"), "08_combat/combat_hit_03.ogg"),
    @((Join-Path $raw "freesound_rat_squeak_cc0_preview.mp3"), "08_combat/combat_rat_attack_01.mp3"),
    @((Join-Path $kenneyImpact "impactSoft_medium_001.ogg"), "08_combat/combat_rat_attack_02.ogg"),
    @((Join-Path $undead "undead-2.ogg"), "08_combat/combat_zombie_attack_01.ogg"),
    @((Join-Path $undead "undead-4.ogg"), "08_combat/combat_zombie_attack_02.ogg"),
    @((Join-Path $kenneyImpact "impactSoft_heavy_000.ogg"), "08_combat/combat_player_hurt_01.ogg"),
    @((Join-Path $kenneyImpact "impactSoft_heavy_003.ogg"), "08_combat/combat_player_hurt_02.ogg"),
    @((Join-Path $kenneyImpact "impactSoft_heavy_001.ogg"), "08_combat/combat_enemy_down_01.ogg"),
    @((Join-Path $kenneyImpact "impactSoft_heavy_004.ogg"), "08_combat/combat_enemy_down_02.ogg"),
    @((Join-Path $kenneyImpact "footstep_wood_003.ogg"), "08_combat/combat_flee.ogg"),
    @((Join-Path $kenneyRpg "cloth4.ogg"), "08_combat/sleep_settle.ogg"),
    @((Join-Path $kenneyImpact "impactSoft_heavy_002.ogg"), "08_combat/collapse.ogg"),
    @((Join-Path $oga100 "sfx100v2_loop_ambient_03.ogg"), "08_combat/death.ogg")
)

foreach ($pair in $candidates) {
    Add-Candidate $pair[0] $pair[1]
}

$count = (Get-ChildItem -LiteralPath $selected -Recurse -File).Count
Write-Output "Curated $count audition candidates into $selected"
