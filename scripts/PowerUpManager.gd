class_name PowerUpManager
extends Node3D
# Spawns power-ups around the world, detects player pickup (grant + sound +
# popup), and applies the magnet effect that pulls smaller bots to the player.

const SPAWN_INTERVAL := 11.0
const MAX_ACTIVE := 3
const KINDS := ["speed", "invincible", "magnet", "shrink", "decoy"]

var world: World
var player: Bot
var spawner: BotSpawner

var _powerups: Array[PowerUp] = []
var _spawn_timer := 4.0

# Decoy state.
var _decoy_t := 0.0
var _decoy_node: Node3D

func setup(p_world: World, p_player: Bot, p_spawner: BotSpawner) -> void:
	world = p_world
	player = p_player
	spawner = p_spawner

func active_powerups() -> Array[PowerUp]:
	return _powerups

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		if _powerups.size() < MAX_ACTIVE:
			_spawn_one()
	_check_pickups()
	_apply_magnet(delta)
	_apply_decoy(delta)

func _spawn_one() -> void:
	var kind: String = KINDS[randi() % KINDS.size()]
	var pu := PowerUp.new()
	pu.setup(kind)
	add_child(pu)
	# Somewhere on the terrain, biased a moderate distance from the player.
	var pos := _random_ground_position()
	for _try in 5:
		if pos.distance_to(player.global_position) > 14.0:
			break
		pos = _random_ground_position()
	pu.global_position = pos + Vector3(0, 1.2, 0)
	_powerups.append(pu)

func _random_ground_position() -> Vector3:
	var lo := World.MIN_COORD + 6
	var hi := World.MAX_COORD - 6
	for _try in 8:
		var x := randf_range(lo, hi)
		var z := randf_range(lo, hi)
		if not world.is_water(floori(x), floori(z)):
			return Vector3(x, world.ground_y(floori(x), floori(z)), z)
	return Vector3(0, world.ground_y(0, 0), 0)

func _check_pickups() -> void:
	for pu in _powerups.duplicate():
		if not is_instance_valid(pu):
			_powerups.erase(pu)
			continue
		var d := Vector2(player.global_position.x - pu.global_position.x,
			player.global_position.z - pu.global_position.z).length()
		if d <= player.radius() + pu.radius() \
				and absf(player.global_position.y - pu.global_position.y) < 4.0 + player.radius():
			_collect(pu)

func _collect(pu: PowerUp) -> void:
	match pu.kind:
		"shrink": _do_shrink()
		"decoy": _start_decoy()
		_: player.grant_power(pu.kind)
	FloatingText.spawn(self, pu.global_position + Vector3(0, 1.5, 0), pu.label(), pu.color())
	var snd := AudioStreamPlayer.new()
	snd.stream = SoundSynth.powerup_pickup()
	get_tree().root.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	_powerups.erase(pu)
	pu.queue_free()

func _apply_magnet(delta: float) -> void:
	if player.magnet_t <= 0.0 or spawner == null:
		return
	var reach := 14.0 + player.size_tier * 2.0
	var pull := 9.0
	for b in spawner.bots:
		if b == player or not is_instance_valid(b) or not b.alive:
			continue
		if not player.can_eat(b):
			continue
		var to_player := player.global_position - b.global_position
		if to_player.length() < reach:
			b.global_position += to_player.normalized() * pull * delta

# Shrink every threat near the player by 40%, defusing the immediate danger.
func _do_shrink() -> void:
	if spawner == null:
		return
	var reach := 26.0
	for b in spawner.bots:
		if b == player or not is_instance_valid(b) or not b.alive or b.is_boss:
			continue
		if b.can_eat(player) and player.global_position.distance_to(b.global_position) < reach:
			b.size_tier = maxf(b.size_tier * 0.6, 0.3)
			b.apply_size()
			FloatingText.spawn(self, b.global_position + Vector3(0, b.radius(), 0), "SHRINK", Color(0.6, 1.0, 0.5))

# A glowing decoy that pulls threats away from the player for a few seconds.
func _start_decoy() -> void:
	_decoy_t = 6.0
	if _decoy_node != null and is_instance_valid(_decoy_node):
		_decoy_node.queue_free()
	_decoy_node = Node3D.new()
	add_child(_decoy_node)
	_decoy_node.global_position = player.global_position
	var core := CSGSphere3D.new()
	core.radius = maxf(player.radius(), 0.6)
	core.radial_segments = 12
	core.rings = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.6, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.8, 0.4, 1.0)
	m.emission_energy_multiplier = 2.5
	core.material = m
	_decoy_node.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.4, 1.0)
	light.light_energy = 2.5
	light.omni_range = 10.0
	_decoy_node.add_child(light)

func _apply_decoy(delta: float) -> void:
	if _decoy_t <= 0.0:
		return
	_decoy_t -= delta
	if _decoy_t <= 0.0:
		if _decoy_node != null and is_instance_valid(_decoy_node):
			_decoy_node.queue_free()
		_decoy_node = null
		return
	if spawner == null or _decoy_node == null:
		return
	var dpos := _decoy_node.global_position
	for b in spawner.bots:
		if b == player or not is_instance_valid(b) or not b.alive:
			continue
		if not b.can_eat(player):
			continue
		var to_decoy := dpos - b.global_position
		if to_decoy.length() < 32.0:
			b.global_position += to_decoy.normalized() * 7.0 * delta
