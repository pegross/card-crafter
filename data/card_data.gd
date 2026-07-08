class_name CardData
extends Resource
## The ONE data-driven card definition (M0). Each .tres in data/cards/ is one of these.

@export var id: String = ""
@export var title: String = ""
@export var kind: String = "item"  ## character / station / item / resource / tool / location
@export_multiline var blurb: String = ""
@export var state_kind: String = ""  ## "" / "explore" / "water" / "fell" / "wood"
@export var state_start: float = 0.0
@export var becomes: String = ""  ## on completion (e.g. a felled tree -> a log)
@export var is_container: bool = false  ## holds one liquid/resource at a time, with a fill %
@export var capacity: float = 100.0  ## container volume (size): a plastic bottle < a gas canister
@export var sealable: bool = false  ## container subcategory: sealable (bottle/jerry) can hold fuel; open ones only water
@export var is_fire_source: bool = false  ## a hearth/campfire: its Fuel can be lit and burns down
@export_multiline var blurb_lit: String = ""  ## fire source: shown while burning
@export_multiline var blurb_fueled: String = ""  ## fire source: shown when fuelled but unlit
@export var hp: float = 0.0  ## creature: combat health; > 0 marks a card as an enemy
@export var damage: float = 0.0  ## creature: base damage it deals per round
@export var flee_hit: float = 0.0  ## creature: base hit it lands as you break away
@export var verb: String = ""  ## creature: how it strikes ("bites", "tears at")
@export var bite_infection: float = 0.0  ## creature: infection seeded per hit (0 = none)
@export var enemy_mins: int = 0  ## creature: in-game minutes an encounter costs
@export var drops: String = ""  ## creature: card id spawned when this creature dies ("" = nothing)
@export var spoil_hours: float = 0.0  ## perishable food: in-game hours until it spoils (0 = keeps)
