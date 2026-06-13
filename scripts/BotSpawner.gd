class_name BotSpawner
extends Node3D
# Owns the bot population: initial spawn, batched AI ticking, distance-based
# audio/AI culling, respawns to hold target_population, and player eat/death.

signal player_died(killer_type: String)
signal player_dominated
signal player_evolve(perks: Array)

const THINK_BATCH := 10        # AI state evaluations per frame
const CULL_RADIUS := 80.0      # beyond this, bots only wander (no chase/flee)
const AUDIO_RADIUS := 38.0     # beyond this, movement loops are silenced
const RESPAWN_DELAY := 3.0
const APEX_SIZE := 18.0        # reaching this triggers the Domination screen
const COMBO_WINDOW := 3.0      # seconds between eats to keep a combo alive
const PERSONALITIES := ["normal", "aggressive", "cowardly", "ambusher"]
const BOSS_INTERVAL := 55.0   # seconds between boss appearances

var _combo_timer := 0.0
var _boss: Bot = null
var _boss_timer := BOSS_INTERVAL
var _evolve_idx := 0

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
var camera: CameraController
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
	bot.personality = PERSONALITIES[randi() % PERSONALITIES.size()]
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
	var ps: float = player.size_tier if player != null else 1.0
	# A fraction spawn as apex predators sized to threaten the current player,
	# so the world keeps pace as you grow — there is no "too big to die" stall.
	if ps > 1.2 and randf() < 0.12:
		return randf_range(ps * 1.2, ps * 1.9)
	# Otherwise draw an absolute tier, lifted gently as the player grows so the
	# whole world scales up over a run.
	var base := _absolute_size()
	var world_scale := clampf(1.0 + (ps - 1.0) * 0.2, 1.0, 5.0)
	return base * world_scale

func _absolute_size() -> float:
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
	_tick_combo(delta)
	_tick_boss(delta)
	_check_evolution()

# Offer a perk choice when the player crosses the next size milestone.
func _check_evolution() -> void:
	if player == null or _evolve_idx >= Perks.MILESTONES.size():
		return
	if player.size_tier >= Perks.MILESTONES[_evolve_idx]:
		_evolve_idx += 1
		player_evolve.emit(Perks.pick(3))

func current_boss() -> Bot:
	if _boss != null and is_instance_valid(_boss) and _boss.alive:
		return _boss
	return null

func _tick_boss(delta: float) -> void:
	if current_boss() != null:
		return
	_boss = null
	if player == null or player.size_tier < 2.5:
		return
	_boss_timer -= delta
	if _boss_timer <= 0.0:
		_boss_timer = BOSS_INTERVAL
		_spawn_boss()

func _spawn_boss() -> void:
	var boss := WalkerBot.new()
	boss.personality = "aggressive"
	var size := maxf(6.0, player.size_tier * 2.2)
	boss.setup("walker", size, world, self)
	add_child(boss)
	boss.make_boss(4 + int(player.size_tier / 3.0))
	boss.global_position = _edge_spawn_position("walker")
	boss.eaten.connect(_on_bot_eaten)
	bots.append(boss)
	_boss = boss
	FloatingText.spawn(self, player.global_position + Vector3(0, 6, 0), "A BOSS APPROACHES", Color(1.0, 0.3, 0.4))

func _defeat_boss(boss: Bot) -> void:
	var at := boss.global_position
	GameState.add_score(500 + int(boss.size_tier * 20.0))
	FloatingText.spawn(self, at + Vector3(0, 3, 0), "BOSS DOWN!", Color(1.0, 0.85, 0.3))
	if camera != null:
		camera.add_trauma(0.7)
	player.grow(boss.size_tier * 1.2)
	_boss = null
	boss.on_eaten(player)

# Move a stuck/frozen player bot back to a safe spot without ending the run.
func respawn_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	Engine.time_scale = 1.0
	var gy := world.ground_y(0, 0)
	var p := Vector3(0.5, gy, 0.5)
	if player.bot_type == "flyer":
		p.y += 12.0
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.desired_dir = Vector3.ZERO
	player.alive = true
	_alive = true

func _tick_combo(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		GameState.combo = 0
		GameState.combo_mult = 1.0

# 0..1 how close the nearest bot that can eat the player is.
func threat_level() -> float:
	if player == null or not player.alive:
		return 0.0
	var nearest := INF
	for b in bots:
		if b == player or not is_instance_valid(b) or not b.alive:
			continue
		if b.can_eat(player):
			nearest = minf(nearest, player.global_position.distance_to(b.global_position))
	if nearest == INF:
		return 0.0
	return clampf(1.0 - nearest / 45.0, 0.0, 1.0)

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
# Invincibility makes the player immune and able to eat anything it touches.
func _resolve_player(_delta: float) -> void:
	if player == null or not player.alive:
		return
	for bot in bots.duplicate():
		if bot == player or not is_instance_valid(bot) or not bot.alive:
			continue
		if not player.overlaps(bot):
			continue
		if bot.is_boss:
			_resolve_boss(bot)
			if not player.alive:
				return
			continue
		var vsize: float = bot.size_tier
		var at: Vector3 = bot.global_position
		var ate := false
		if player.is_invincible():
			ate = player.attempt_eat(bot, true)
		elif player.can_eat(bot):
			ate = player.attempt_eat(bot)
		elif bot.can_eat(player):
			_kill_player(bot)
			return
		if ate:
			_award_eat(vsize, at)
			if camera != null and vsize >= 2.0:
				camera.add_trauma(clampf(vsize * 0.08, 0.1, 0.5))
	_check_domination()

func _award_eat(vsize: float, at: Vector3) -> void:
	GameState.bots_eaten_run += 1
	_combo_timer = COMBO_WINDOW
	GameState.combo += 1
	GameState.combo_mult = clampf(1.0 + (GameState.combo - 1) * 0.2, 1.0, 5.0)
	var pts := int(round(vsize * 10.0 * GameState.combo_mult))
	GameState.add_score(pts)
	var txt := "+%d" % pts
	var color := Color(1.0, 0.9, 0.4)
	if GameState.combo > 1:
		txt += "   x%d" % GameState.combo
		color = Color(1.0, 0.6, 0.2)
	FloatingText.spawn(self, at + Vector3(0, 1.0, 0), txt, color)

# Ramming a boss while attacking (dash / speed / invincible) damages it;
# otherwise it eats the player unless they're invincible.
func _resolve_boss(boss: Bot) -> void:
	if player.is_attacking() and boss._hit_cd <= 0.0:
		boss.hp -= 1
		boss._hit_cd = 0.6
		var away := (boss.global_position - player.global_position).normalized()
		boss.global_position += away * 2.0
		FloatingText.spawn(self, boss.global_position + Vector3(0, boss.radius(), 0), "HIT!", Color(1.0, 0.6, 0.3))
		if camera != null:
			camera.add_trauma(0.3)
		if boss.hp <= 0:
			_defeat_boss(boss)
	elif not player.is_invincible():
		_kill_player(boss)

func _check_domination() -> void:
	if GameState.dominated or player == null:
		return
	if player.size_tier >= APEX_SIZE:
		GameState.dominated = true
		player_dominated.emit()

func _kill_player(killer: Bot) -> void:
	if not _alive:
		return
	# Iron Hide perk: survive one fatal hit.
	if player.revives > 0:
		player.revives -= 1
		player.invincible_t = maxf(player.invincible_t, 3.0)
		player.size_tier = maxf(0.8, player.size_tier * 0.7)
		player.apply_size()
		GameState.player_size = player.size_tier
		FloatingText.spawn(self, player.global_position + Vector3(0, 2, 0), "REVIVED!", Color(0.5, 1.0, 0.7))
		if camera != null:
			camera.add_trauma(0.5)
		return
	_alive = false
	player.alive = false
	var killer_type := killer.bot_type
	if camera != null:
		camera.add_trauma(0.8)
		camera.death_focus(killer)
	var death := AudioStreamPlayer3D.new()
	death.stream = SoundSynth.death_sound()
	death.max_distance = 60.0
	player.add_child(death)
	death.play()
	GameState.set_state("game_over")
	GameState.finish_run()
	# Brief slow-motion death cam before the overlay.
	Engine.time_scale = 0.35
	var t := get_tree().create_timer(1.1, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		player_died.emit(killer_type))

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
