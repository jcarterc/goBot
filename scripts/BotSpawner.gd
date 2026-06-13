class_name BotSpawner
extends Node3D
# Owns the bot population: initial spawn, batched AI ticking, distance-based
# audio/AI culling, respawns to hold target_population, and player eat/death.

signal player_died(killer_type: String)

const THINK_BATCH := 10        # AI state evaluations per frame
const CULL_RADIUS := 80.0      # beyond this, bots only wander (no chase/flee)
const AUDIO_RADIUS := 38.0     # beyond this, movement loops are silenced
const RESPAWN_DELAY := 3.0

# Bot type mix and size-tier distribution from the design brief.
const TYPE_WEIGHTS := [["walker", 0.5], ["roller", 0.3], ["flyer", 0.2]]
const SIZE_TIERS := [
	[0.35, 0.3, 0.6],   # weight, min, max  (Tiny)
	[0.30, 0.7, 1.2],   # Small
	[0.20, 1.3, 2.5],   # Medium
	[0.12, 2.6, 4.5],   # Large
	[0.03, 4.6, 8.0],   # Massive
]

var world: World
var player: Bot
var target_population := 70

var bots: Array[Bot] = []
var _think_cursor := 0
var _last_think := {}
var _respawns: Array[float] = []
var _alive := true

func setup(p_world: World, p_player: Bot, p_target: int) -> void:
	world = p_world
	player = p_player
	target_population = p_target

func spawn_initial() -> void:
	for i in target_population:
		_spawn_one()
	_update_count()

func _spawn_one(force_type := "") -> void:
	var btype := force_type if force_type != "" else _weighted_type()
	var size := _weighted_size()
	var bot := _make_bot(btype)
	bot.setup(btype, size, world, self)
	add_child(bot)
	# Place on the spawn ring, away from the player.
	var pos := _edge_spawn_position(btype)
	for _try in 6:
		if player == null or pos.distance_to(player.global_position) > 22.0:
			break
		pos = _edge_spawn_position(btype)
	bot.global_position = pos
	bot.eaten.connect(_on_bot_eaten)
	bots.append(bot)

func register_player(p: Bot) -> void:
	player = p
	if not bots.has(p):
		bots.append(p)

func _make_bot(btype: String) -> Bot:
	match btype:
		"walker": return WalkerBot.new()
		"flyer": return FlyerBot.new()
		_: return RollerBot.new()

func _edge_spawn_position(btype: String) -> Vector3:
	var xz := world.random_edge_xz()
	var gx := floori(xz.x)
	var gz := floori(xz.y)
	var y := world.ground_y(gx, gz)
	if btype == "flyer":
		y += randf_range(FlyerBot.MIN_ALT, FlyerBot.MAX_ALT)
	return Vector3(xz.x, y, xz.y)

func _weighted_type() -> String:
	var r := randf()
	var acc := 0.0
	for entry in TYPE_WEIGHTS:
		acc += entry[1]
		if r <= acc:
			return entry[0]
	return "roller"

func _weighted_size() -> float:
	var r := randf()
	var acc := 0.0
	for tier in SIZE_TIERS:
		acc += tier[0]
		if r <= acc:
			return randf_range(tier[1], tier[2])
	return randf_range(0.7, 1.2)

# --- Per-frame update ---

func _process(delta: float) -> void:
	if not _alive:
		return
	_tick_ai()
	_tick_audio()
	_resolve_player(delta)
	_tick_respawns(delta)

func _tick_ai() -> void:
	if bots.is_empty():
		return
	var count := mini(THINK_BATCH, bots.size())
	var now := Time.get_ticks_msec()
	for i in count:
		_think_cursor = (_think_cursor + 1) % bots.size()
		var bot := bots[_think_cursor]
		if not is_instance_valid(bot) or bot.is_player_controlled or not bot.alive:
			continue
		var id := bot.get_instance_id()
		var last: int = _last_think.get(id, now)
		var dt: float = maxf((now - last) / 1000.0, 0.016)
		_last_think[id] = now
		bot.think(dt)

func _tick_audio() -> void:
	if player == null:
		return
	for bot in bots:
		if not is_instance_valid(bot):
			continue
		var near := bot.is_player_controlled \
			or bot.global_position.distance_to(player.global_position) <= AUDIO_RADIUS
		bot.set_audio_active(near)

func is_culled(bot: Bot) -> bool:
	if player == null or bot == player:
		return false
	return bot.global_position.distance_to(player.global_position) > CULL_RADIUS

# Player eats overlapping smaller bots; dies to an overlapping larger one.
func _resolve_player(_delta: float) -> void:
	if player == null or not player.alive:
		return
	for bot in bots.duplicate():
		if bot == player or not is_instance_valid(bot) or not bot.alive:
			continue
		if not player.overlaps(bot):
			continue
		if player.can_eat(bot):
			player.attempt_eat(bot)
		elif bot.can_eat(player):
			_kill_player(bot.bot_type)
			return

func _kill_player(killer_type: String) -> void:
	_alive = false
	player.alive = false
	var death := AudioStreamPlayer3D.new()
	death.stream = SoundSynth.death_sound()
	death.max_distance = 60.0
	player.add_child(death)
	death.play()
	GameState.set_state("game_over")
	player_died.emit(killer_type)

func _on_bot_eaten(victim: Bot, _eater: Bot) -> void:
	# Player death is handled separately; only schedule AI bot respawns here.
	if victim == player:
		return

func report_eaten(bot: Bot) -> void:
	bots.erase(bot)
	_last_think.erase(bot.get_instance_id())
	if bot != player:
		_respawns.append(RESPAWN_DELAY)
	_update_count()

func _tick_respawns(delta: float) -> void:
	if _respawns.is_empty():
		return
	var still: Array[float] = []
	for t in _respawns:
		var nt := t - delta
		if nt <= 0.0:
			if _living_ai_count() < target_population:
				_spawn_one()
		else:
			still.append(nt)
	_respawns = still
	_update_count()

func _living_ai_count() -> int:
	var n := 0
	for b in bots:
		if is_instance_valid(b) and b.alive and not b.is_player_controlled:
			n += 1
	return n

func _update_count() -> void:
	GameState.bot_count = _living_ai_count()
	GameState.publish()
