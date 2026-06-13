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

# Player power-up state (seconds remaining). Ignored for AI bots.
var speed_boost_t := 0.0
var invincible_t := 0.0
var magnet_t := 0.0
var _shield: CSGSphere3D

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
	if is_player_controlled:
		_build_shield()
	apply_size(true)
	_wander_dir = _random_horizontal()

func _build_shield() -> void:
	_shield = CSGSphere3D.new()
	_shield.radius = BODY_UNIT * 1.6
	_shield.radial_segments = 16
	_shield.rings = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.9, 1.0, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.3, 0.8, 1.0)
	m.emission_energy_multiplier = 1.5
	_shield.material = m
	_shield.visible = false
	add_child(_shield)

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

func attempt_eat(other: Bot, force := false) -> bool:
	if not alive or not other.alive:
		return false
	if not overlaps(other):
		return false
	if not force and not can_eat(other):
		return false
	var gained := other.size_tier
	var at := other.global_position
	other.on_eaten(self)
	grow(gained)
	_play_eat()
	_spawn_burst(at, Color(1.0, 0.85, 0.35), int(clampf(gained * 6.0, 6.0, 40.0)))
	return true

func is_invincible() -> bool:
	return invincible_t > 0.0

func grant_power(kind: String) -> void:
	match kind:
		"speed": speed_boost_t = 6.0
		"invincible": invincible_t = 6.0
		"magnet": magnet_t = 8.0

func grow(victim_size: float) -> void:
	size_tier += victim_size * ABSORB
	apply_size()
	if is_player_controlled:
		GameState.player_size = size_tier
		GameState.add_score(int(round(victim_size * 10.0)))
		_flash()
		_spawn_burst(global_position + Vector3(0, radius(), 0), Color(0.5, 1.0, 0.7), 18)

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
	if is_player_controlled:
		_tick_powers(delta)
	move(delta)
	_update_sound()

func _tick_powers(delta: float) -> void:
	speed_boost_t = maxf(speed_boost_t - delta, 0.0)
	invincible_t = maxf(invincible_t - delta, 0.0)
	magnet_t = maxf(magnet_t - delta, 0.0)
	if _shield:
		_shield.visible = invincible_t > 0.0
		if _shield.visible:
			_shield.rotate_y(delta * 2.0)

func move(delta: float) -> void:
	var boost := 1.7 if speed_boost_t > 0.0 else 1.0
	var spd := base_speed * speed_mult * boost
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
	# Pitch eat sounds up for small victims, down for large ones.
	one.pitch_scale = clampf(1.4 - size_tier * 0.08, 0.7, 1.5)
	add_child(one)
	one.play()
	one.finished.connect(one.queue_free)

# One-shot particle burst in world space (survives the eaten bot being freed).
func _spawn_burst(pos: Vector3, color: Color, count: int) -> void:
	var host := get_parent()
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 80.0
	p.gravity = Vector3(0, -6, 0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	p.mesh = mesh
	host.add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# A continuous world-space motion trail, attached at a local offset.
func _add_trail(color: Color, offset: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.5
	p.position = offset
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.32
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	p.mesh = mesh
	add_child(p)

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
