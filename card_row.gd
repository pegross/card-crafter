class_name CardRow
extends HBoxContainer
## An ordered row of cards. Accepts dropped item-cards (in empty space) and keeps
## them cleanly left-to-right. Optionally capped (the inventory). The top row sets
## accepts_items = false so fixtures/locations there can't be shuffled by item drops.

var main
var accepts_items: bool = true
var capacity: int = -1  ## -1 = unlimited

func can_accept(card: CardIcon) -> bool:
	if not accepts_items or not card.mobile:
		return false
	if capacity >= 0 and card.get_parent() != self and get_child_count() >= capacity:
		return false
	return true

func _can_drop_data(_at: Vector2, incoming) -> bool:
	return typeof(incoming) == TYPE_DICTIONARY and incoming.has("card") and can_accept(incoming["card"])

func _drop_data(at: Vector2, incoming) -> void:
	var dropped: CardIcon = incoming["card"]
	if not can_accept(dropped):
		return
	var idx := get_child_count()
	for i in get_child_count():
		var child: Control = get_child(i)
		if child == dropped:
			continue
		if at.x < child.position.x + child.size.x * 0.5:
			idx = i
			break
	if dropped.get_parent() == self and dropped.get_index() < idx:
		idx -= 1
	if dropped.get_parent() != self:
		dropped.get_parent().remove_child(dropped)
		add_child(dropped)
	move_child(dropped, clampi(idx, 0, get_child_count() - 1))
	if main:
		main.on_card_reordered()
