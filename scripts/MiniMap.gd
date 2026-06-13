class_name MiniMap
extends Control
# Top-down radar: plots nearby bots (red = threat, green = edible, grey = neutral),
# power-ups (yellow) and bosses (magenta), relative to the player. North-up.

const R := 70.0         # collapsed radar radius in pixels
const R_EXP := 150.0    # expanded radar radius in pixels
const RANGE := 70.0     # collapsed world range
const RANGE_EXP := 130.0  # expanded world range

var player: Bot
var spawner: BotSpawner
var powerups: PowerUpManager
var expanded := false

func setup(p_player: Bot, p_spawner: BotSpawner, p_powerups: PowerUpManager) -> void:
	player = p_player
	spawner = p_spawner
	powerups = p_powerups
	_refresh_size()

func toggle_expand() -> void:
	expanded = not expanded
	_refresh_size()

func cur_r() -> float:
	return R_EXP if expanded else R

func cur_range() -> float:
	return RANGE_EXP if expanded else RANGE

func _refresh_size() -> void:
	custom_minimum_size = Vector2(cur_r() * 2.0, cur_r() * 2.0)
	size = custom_minimum_size

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r := cur_r()
	var rng := cur_range()
	var c := Vector2(r, r)
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.35))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.4, 0.6, 0.9, 0.6), 2.0)
	if player == null or not is_instance_valid(player):
		return
	var pp := player.global_position
	if spawner != null:
		for b in spawner.bots:
			if b == player or not is_instance_valid(b) or not b.alive:
				continue
			var rel := Vector2(b.global_position.x - pp.x, b.global_position.z - pp.z)
			if rel.length() > rng:
				continue
			var dot := c + rel / rng * r
			var col := Color(0.6, 0.6, 0.65)
			if b.is_boss:
				col = Color(1.0, 0.2, 0.8)
			elif b.can_eat(player):
				col = Color(1.0, 0.3, 0.3)
			elif player.can_eat(b):
				col = Color(0.4, 1.0, 0.5)
			var sz := 5.0 if b.is_boss else (4.0 if b.size_tier >= 2.6 else 2.5)
			draw_circle(dot, sz, col)
	if powerups != null:
		for pu in powerups.active_powerups():
			if not is_instance_valid(pu):
				continue
			var rel := Vector2(pu.global_position.x - pp.x, pu.global_position.z - pp.z)
			if rel.length() > rng:
				continue
			draw_circle(c + rel / rng * r, 3.0, Color(1.0, 0.9, 0.3))
	# Player at centre.
	draw_circle(c, 4.0, Color.WHITE)
