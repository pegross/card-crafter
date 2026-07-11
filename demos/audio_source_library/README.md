# Dead Air MVP audition sound library

This folder is a **source and audition library**, not an integrated or mastered
game-audio folder.

- `raw_packs/` contains downloaded archives and individual source recordings.
- `extracted/` contains the complete extracted CC0 packs (597 audio files).
- `selected_mvp/` contains 107 renamed candidates mapped to the MVP cue sheet.
- `tools/curate_audio_mvp.ps1` rebuilds `selected_mvp/` from the sources.

The selected filenames describe their intended audition use. They do not imply
that the source is already cut, looped, layered, level-matched, or approved for
the final mix. Several long recordings deliberately appear as `*_source` files
and should be cut into variations later.

## License policy for this collection

Every provider page below displayed Creative Commons Zero (CC0) when collected
on 2026-07-11. CC0 permits modification and commercial use without required
attribution. Even so, preserve this manifest and re-check source pages before a
public release. Freesound files marked `preview` are compressed public audition
copies; download the original-quality file from Freesound before production.

## Source manifest

| Source | Creator/provider | Used for | License |
|---|---|---|---|
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | UI clicks and state feedback | CC0 |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | footsteps, wood, body, tin, and combat impacts | CC0 |
| [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | cards/paper, cloth, doors, tools, pots, and movement | CC0 |
| [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2) | rubberduck | wood, stone, switches, water, items, and ambience | CC0 |
| [202 More Sound Effects](https://opengameart.org/content/202-more-sound-effects) | OwlishMedia | cloth, drinking, plastic, doors, kitchen, and stationery Foley | CC0 |
| [7 Eating Crunches](https://opengameart.org/content/7-eating-crunches) | StarNinjas/Tito | eating candidates | CC0 |
| [Undead Moans](https://opengameart.org/content/undead-moans) | AntumDeluge | zombie encounters and attacks | CC0 |
| [The Shop](https://opengameart.org/content/the-shop) | LEGIT Audio | interior room-tone candidate | CC0 for the OGA free files |
| [Fireplace Sound Loop](https://opengameart.org/content/fireplace-sound-loop) | PagDev | hearth loop and ignition source | CC0 |
| [Forest Ambience](https://opengameart.org/content/forest-ambience) | TinyWorlds | Woods ambience candidate | CC0 |
| [Winter Wind](https://opengameart.org/content/winter-wind) | wipics | Grounds ambience candidate | CC0 |
| [Dripping Water Loop](https://opengameart.org/content/dripping-water-loop) | Independent.nu / qubodup | Cellar ambience candidate | CC0 |
| [Enemy Sounds](https://opengameart.org/content/enemy-sounds) | AbNormalHumanBeing | creature source reel | CC0 |
| [Boiling Water Loops](https://opengameart.org/content/boiling-water-loops) | TinyWorlds | boiling and herbal-remedy source | CC0 |
| [Fabric Rustling](https://opengameart.org/content/fabric-rustling) | Iochi Glaucus | additional long cloth source | CC0 |
| [Zippo Click Sound](https://opengameart.org/content/zippo-click-sound) | dawith / qubodup | lighter mechanism | CC0 |
| [Chopping Wood with Axe](https://freesound.org/people/21100495/sounds/655325/) | 21100495 | oak-chop source take | CC0; preview copy present |
| [Tree Chop Fall Thud](https://opengameart.org/content/tree-chop-fall-thud) | kheetor | oak fall | CC0 |
| [Turning a Radio On](https://freesound.org/people/pfranzen/sounds/528272/) | pfranzen | radio power-on | CC0; preview copy present |
| [Radio Tuning](https://freesound.org/people/Dnab55/sounds/146841/) | Dnab55 | tuning and signal-found source | CC0; preview copy present |
| [Old Radio Switch](https://freesound.org/people/eneibol/sounds/369964/) | eneibol | radio switch on/off | CC0; preview copy present |
| [Static](https://opengameart.org/content/static) | xhunterko | radio static source | CC0 |
| [Rat.ogg](https://freesound.org/people/egomassive/sounds/536753/) | egomassive | rat encounter and attack | CC0; preview copy present |

Kenney's extracted packs also include their own `License.txt` files. The undead
pack includes its own `LICENSE.txt`.

## MVP coverage and remaining sound-design work

The collection now has source coverage for every P0 family in
`docs/audio-mvp-cue-sheet.md`: interface, four locations, travel/search, oak and
woodwork, hearth/cooking, survival interactions, radio states, traps, creatures,
combat, rest, collapse, and death.

Before integration, the following still needs human audition and editing:

1. Cut five usable oak strikes from the long axe recording.
2. Cut three tuning movements plus signal acquisition and switch-off from the
   radio source recordings.
3. Trim and darken ambience beds, then verify seamless loops.
4. Layer hearth ignition, cooking, trap, and creature attacks from the supplied
   ingredients.
5. Choose the best UI/cloth/food variants and remove candidates that feel too
   clean, bright, or game-like for *Dead Air*.
6. Normalize the approved cues as one coherent set and replace every Freesound
   preview with its original-quality download.

Nothing here has been connected to Godot.

