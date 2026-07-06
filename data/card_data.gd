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
