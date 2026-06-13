class_name Perks
extends RefCounted
# Evolution perk pool. Each perk is { id, name, desc }. Bot.apply_perk(id)
# implements the actual effect. Picked at size milestones during a run.

const POOL := [
	{"id": "voracious", "name": "Voracious", "desc": "Eat bots closer to your own size"},
	{"id": "sprinter", "name": "Sprinter", "desc": "+15% movement speed"},
	{"id": "quick_dash", "name": "Quick Dash", "desc": "Dash recharges faster & lasts longer"},
	{"id": "collector", "name": "Collector", "desc": "Power-ups last 50% longer"},
	{"id": "iron_hide", "name": "Iron Hide", "desc": "Survive one otherwise-fatal hit"},
	{"id": "efficient", "name": "Efficient", "desc": "Shrink half as fast"},
	{"id": "big_appetite", "name": "Big Appetite", "desc": "Absorb more size from each bot you eat"},
	{"id": "adrenaline", "name": "Adrenaline", "desc": "Special ability recharges faster"},
]

# The size thresholds that trigger an evolution choice.
const MILESTONES := [3.0, 6.0, 10.0, 15.0, 22.0, 30.0, 40.0]

static func pick(count: int) -> Array:
	var ids := POOL.duplicate()
	ids.shuffle()
	return ids.slice(0, mini(count, ids.size()))
