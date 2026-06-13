class_name PowerUpManager
extends Node3D
# Spawns power-ups around the world, detects player pickup (grant + sound +
# popup), and applies the magnet effect that pulls smaller bots to the player.

const SPAWN_INTERVAL := 11.0
const MAX_ACTIVE := 3
const KINDS := ["speed", "invincible", "magnet"]

var world: World
var player: Bot
var spawner: BotSpawner

var _powerups: Array[PowerUp] = []
var _spawn_timer := 4.0

func setup(p_world: World, p_player: Bot, p_spawner: BotSpawner) -> void:
	world = p_world
	player = p_player
	spawner = p_spawner

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
	player.grant_power(pu.kind)
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
