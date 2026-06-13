class_name Bot
extends Node3D
# Base class for every bot in the arena. Subclasses build their own body mesh
# and override _constrain() to move on the terrain surface (Walker/Roller) or
# within a vertical band (Flyer). Eating, growth and AI state are shared here.

signal eaten(victim: Bot, eater: Bot)

const BODY_UNIT := 0.7          # world radius at size_tier 1.0
const BASE_SPEED := 7.0
const BASE_DETECT := 9.0
const DETECT_PER_TIER := 3.5
const EAT_RATIO := 1.15         # must be 15% larger to eat
const ABSORB := 0.25            # fraction of victim size gained
const FLYER_VERT_REACH := 8.0   # vertical proximity for flyer<->ground eats

var bot_type := "roller"
var size_tier := 1.0
var base_speed := BASE_SPEED
var detection_radius := BASE_DETECT
var is_player_controlled := false
var sound_id := ""

var world: World
var spawner: BotSpawner
var velocity := Vector3.ZERO
var desired_dir := Vector3.ZERO  # steering input; horizontal for ground bots
var speed_mult := 1.0
var alive := true

# AI state machine
var state := "wander"
var target: Bot = null
var _wander_dir := Vector3.ZERO
var _wander_timer := 0.0
var _flee_safe_timer := 0.0

var _audio: AudioStreamPlayer3D
var _audio_active := false

func setup(p_type: String, p_size: float, p_world: World, p_spawner: BotSpawner) -> void:
	bot_type = p_type
	size_tier = p_size
	world = p_world
	spawner = p_spawner
	sound_id = "%s_%d" % [bot_type, get_instance_id()]

func _ready() -> void:
	_build_body()
	_setup_audio()
	apply_size(true)
	_wander_dir = _random_horizontal()

# Subclasses construct their CSG body here.
func _build_body() -> void:
	pass

func _setup_audio() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = SoundSynth.movement_loop(bot_type)
	_audio.unit_size = 6.0
	_audio.max_db = -6.0
	_audio.volume_db = -8.0
	add_child(_audio)

# --- Size / scale ---

func radius() -> float:
	return BODY_UNIT * size_tier

func apply_size(instant := false) -> void:
	base_speed = BASE_SPEED / sqrt(size_tier)
	detection_radius = BASE_DETECT + DETECT_PER_TIER * size_tier
	if _audio:
		_audio.max_distance = 14.0 * size_tier
	var target_scale := Vector3.ONE * size_tier
	if instant:
		scale = target_scale
	else:
		var tw := create_tween()
		tw.tween_property(self, "scale", target_scale, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Eating ---

func can_eat(other: Bot) -> bool:
	return size_tier >= other.size_tier * EAT_RATIO

func overlaps(other: Bot) -> bool:
	var a := global_position
	var b := other.global_position
	var horiz := Vector2(a.x - b.x, a.z - b.z).length()
	if horiz > radius() + other.radius():
		return false
	# Flyer<->ground pairs only interact within a vertical reach.
	if bot_type == "flyer" or other.bot_type == "flyer":
		if absf(a.y - b.y) > FLYER_VERT_REACH:
			return false
	return true

func attempt_eat(other: Bot) -> bool:
	if not alive or not other.alive:
		return false
	if not can_eat(other) or not overlaps(other):
		return false
	var gained := other.size_tier
	other.on_eaten(self)
	grow(gained)
	_play_eat()
	return true

func grow(victim_size: float) -> void:
	size_tier += victim_size * ABSORB
	apply_size()
	if is_player_controlled:
		GameState.player_size = size_tier
		GameState.add_score(int(round(victim_size * 10.0)))
		_flash()

func on_eaten(eater: Bot) -> void:
	if not alive:
		return
	alive = false
	eaten.emit(self, eater)
	if spawner != null:
		spawner.report_eaten(self)
	queue_free()

# --- AI (called in batches by the spawner; dt = time since last think) ---

func think(dt: float) -> void:
	if is_player_controlled or not alive:
		return
	var culled: bool = spawner != null and spawner.is_culled(self)
	_evaluate_state(dt, culled)
	_steer(dt)
	_ai_try_eat()

func _evaluate_state(dt: float, culled: bool) -> void:
	var prey: Bot = null
	var threat: Bot = null
	if not culled:
		var found := scan_nearby()
		prey = found[0]
		threat = found[1]
	# FLEE always wins.
	if threat != null:
		state = "flee"
		target = threat
		_flee_safe_timer = 0.0
		return
	match state:
		"flee":
			_flee_safe_timer += dt
			if _flee_safe_timer >= 2.0:
				state = "wander"
				target = null
		"chase":
			if target == null or not target.alive:
				state = "wander"
				target = null
			elif prey != null:
				target = prey
		_:
			if prey != null:
				state = "chase"
				target = prey

# Returns [nearest_prey, nearest_threat] within detection range.
func scan_nearby() -> Array:
	var prey: Bot = null
	var threat: Bot = null
	var prey_d := INF
	var threat_d := INF
	var threat_range := detection_radius * 1.5
	if spawner == null:
		return [null, null]
	for b in spawner.bots:
		if b == self or not is_instance_valid(b) or not b.alive:
			continue
		var d: float = global_position.distance_to(b.global_position)
		if b.size_tier >= size_tier * EAT_RATIO:
			if d < threat_range and d < threat_d:
				threat_d = d
				threat = b
		elif can_eat(b):
			if d < detection_radius and d < prey_d:
				prey_d = d
				prey = b
	return [prey, threat]

func _steer(_dt: float) -> void:
	speed_mult = 1.0
	match state:
		"chase":
			if target != null and target.alive:
				desired_dir = _to(target)
		"flee":
			if target != null and is_instance_valid(target):
				desired_dir = -_to(target)
				speed_mult = 1.3
				_flee_extra()
		_:
			_wander_timer -= _dt
			if _wander_timer <= 0.0:
				_wander_dir = _random_horizontal()
				_wander_timer = randf_range(2.0, 4.0)
			desired_dir = _wander_dir
	desired_dir = _avoid_obstacles(desired_dir)

func _ai_try_eat() -> void:
	if state != "chase" or target == null or not is_instance_valid(target):
		return
	attempt_eat(target)

# Override in Flyer to climb while fleeing.
func _flee_extra() -> void:
	pass

func _to(other: Bot) -> Vector3:
	var d := other.global_position - global_position
	d.y = 0.0
	return d.normalized()

func _random_horizontal() -> Vector3:
	var a := randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))

# Ground bots steer away from water and the world edge. Flyers ignore terrain.
func _avoid_obstacles(dir: Vector3) -> Vector3:
	if bot_type == "flyer" or dir == Vector3.ZERO:
		return dir
	var look := global_position + dir * (radius() + 2.5)
	var gx := floori(look.x)
	var gz := floori(look.z)
	var blocked := world.is_water(gx, gz) \
		or look.x <= World.MIN_COORD + 2 or look.x >= World.MAX_COORD - 2 \
		or look.z <= World.MIN_COORD + 2 or look.z >= World.MAX_COORD - 2
	if blocked:
		# Turn toward world centre with a slight random bias.
		var inward := (Vector3.ZERO - global_position)
		inward.y = 0.0
		return (inward.normalized() + _random_horizontal() * 0.4).normalized()
	return dir

# --- Per-frame movement ---

func _process(delta: float) -> void:
	if not alive:
		return
	move(delta)
	_update_sound()

func move(delta: float) -> void:
	var spd := base_speed * speed_mult
	var target_vel := desired_dir * spd
	velocity = velocity.lerp(target_vel, 0.15)
	global_position += velocity * delta
	global_position = world.clamp_to_world(global_position)
	_constrain(delta)

# Override per bot type to follow the ground or hold an altitude band.
func _constrain(_delta: float) -> void:
	pass

# --- Audio ---

func set_audio_active(active: bool) -> void:
	if _audio == null or _audio_active == active:
		return
	_audio_active = active
	if active:
		_audio.play()
	else:
		_audio.stop()

func _update_sound() -> void:
	if _audio == null or not _audio_active:
		return
	var speed := velocity.length()
	match bot_type:
		"roller":
			_audio.pitch_scale = clampf(0.6 + speed / 12.0, 0.5, 2.0)
		"flyer":
			_audio.pitch_scale = clampf(0.8 + absf(velocity.y) / 6.0, 0.7, 2.2)
		_:
			_audio.pitch_scale = clampf(0.85 + speed / 18.0, 0.7, 1.6)

func _play_eat() -> void:
	var one := AudioStreamPlayer3D.new()
	one.stream = SoundSynth.eat_sound(bot_type)
	one.unit_size = 8.0
	one.max_distance = 40.0
	add_child(one)
	one.play()
	one.finished.connect(one.queue_free)

func _flash() -> void:
	# Brief glow on the player body when it grows.
	for child in get_children():
		var prim := child as CSGPrimitive3D
		if prim == null:
			continue
		var m := prim.material as StandardMaterial3D
		if m == null:
			continue
		var base := m.emission
		m.emission_enabled = true
		m.emission = Color(1, 1, 0.6)
		var tw := create_tween()
		tw.tween_property(m, "emission", base, 0.4)
