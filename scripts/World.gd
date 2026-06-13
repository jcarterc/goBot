class_name World
extends Node3D

# How many chunks per side of the (square) world.
const RADIUS := 5  # 11x11 chunks centered on origin — a roomier arena
const SEA_LEVEL := 22

var chunks := {}  # Vector2i(cx, cz) -> Chunk
var _noise := FastNoiseLite.new()
var _tree_noise := FastNoiseLite.new()
var _mtn_noise := FastNoiseLite.new()
var _river_noise := FastNoiseLite.new()
var _material: StandardMaterial3D

# Day/night cycle state (only animated in arena mode).
const DAY_LENGTH := 120.0
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _time_of_day := 0.35

# Playable world bounds in voxel coordinates (square, centred near origin).
const MIN_COORD := -RADIUS * Chunk.W            # -48
const MAX_COORD := (RADIUS + 1) * Chunk.W - 1   # 63

# goBot Arena drives terrain generation itself and supplies its own bots,
# camera and HUD, so it sets this true to skip the sandbox player/hotbar.
var arena_mode := false

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.025
	_noise.fractal_octaves = 4
	_noise.seed = 1337
	_tree_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_tree_noise.frequency = 0.9
	_tree_noise.seed = 99
	# Low-frequency ridges for mountains, and winding channels for streams.
	_mtn_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_mtn_noise.frequency = 0.012
	_mtn_noise.seed = 4242
	_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_noise.frequency = 0.016
	_river_noise.seed = 7777
	# Daily challenge: deterministic terrain seeded by the date.
	if GameState.daily_mode:
		var s := GameState.daily_seed()
		_noise.seed = s
		_tree_noise.seed = s + 7
		_mtn_noise.seed = s + 13
		_river_noise.seed = s + 29

	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	# Render both faces so terrain never looks see-through from grazing/inside angles.
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_setup_environment()
	_generate_world()
	if not arena_mode:
		_spawn_player_and_hud()

func _setup_environment() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(40), 0)
	_sun.light_energy = 1.1
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 120.0
	add_child(_sun)

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	# Generated panorama backdrop (clouds, sun, distant mountains).
	_env.sky = SkyGen.make_sky()
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.fog_enabled = true
	_env.fog_density = 0.004
	_env.fog_light_color = Color(0.75, 0.85, 0.95)
	# Bloom so emissive bot accents, trails and power-ups glow.
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.15
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

func _process(delta: float) -> void:
	if not arena_mode or _sun == null:
		return
	_time_of_day = fmod(_time_of_day + delta / DAY_LENGTH, 1.0)
	var ang := _time_of_day * TAU
	# Gentle day<->dusk swing (the panorama backdrop stays painted as daytime).
	var daylight := clampf(sin(ang) * 0.3 + 0.7, 0.4, 1.0)
	_sun.rotation.x = -0.2 - ang
	_sun.light_energy = lerpf(0.2, 1.2, daylight)
	_sun.light_color = Color(0.5, 0.6, 0.85).lerp(Color(1.0, 0.96, 0.9), daylight)
	# Panorama sky is static; day/night reads through lighting, fog and ambient.
	var horizon := Color(0.10, 0.12, 0.22).lerp(Color(0.75, 0.85, 0.95), daylight)
	_env.fog_light_color = horizon
	_env.ambient_light_energy = lerpf(0.35, 0.6, daylight)

func _spawn_player_and_hud() -> void:
	var hud := HUD.new()
	add_child(hud)

	var player := Player.new()
	# Build the player's children before adding to the tree so @onready resolves.
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 1.6, 0)
	cam.far = 400.0
	player.add_child(cam)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	player.add_child(shape)
	add_child(player)
	player.hud = hud

func _generate_world() -> void:
	for cx in range(-RADIUS, RADIUS + 1):
		for cz in range(-RADIUS, RADIUS + 1):
			_create_chunk(cx, cz)
	# Mesh after all voxel data exists so cross-chunk faces cull correctly.
	for chunk in chunks.values():
		chunk.rebuild_mesh()

func _create_chunk(cx: int, cz: int) -> void:
	var chunk := Chunk.new()
	chunk.material = _material
	add_child(chunk)
	chunk.setup(cx, cz, self)
	chunks[Vector2i(cx, cz)] = chunk
	_fill_terrain(chunk)

func _fill_terrain(chunk: Chunk) -> void:
	for lx in Chunk.W:
		for lz in Chunk.D:
			var gx := chunk.cx * Chunk.W + lx
			var gz := chunk.cz * Chunk.D + lz
			var h := _height_at(gx, gz)
			for y in range(0, h + 1):
				var id := Blocks.STONE
				if y == h:
					# Rocky peaks up high, grass on land, sand at the shoreline.
					if h >= SEA_LEVEL + 20:
						id = Blocks.STONE
					elif h >= SEA_LEVEL:
						id = Blocks.GRASS
					else:
						id = Blocks.SAND
				elif y >= h - 3:
					id = Blocks.DIRT
				chunk.set_local(lx, y, lz, id)
			# fill water up to sea level over low ground (oceans + carved streams)
			for y in range(h + 1, SEA_LEVEL + 1):
				chunk.set_local(lx, y, lz, Blocks.WATER)
			# trees on gentle grassland (not shoreline, not steep peaks)
			if h >= SEA_LEVEL + 1 and h <= SEA_LEVEL + 16 and _tree_noise.get_noise_2d(gx, gz) > 0.78:
				_plant_tree(chunk, lx, h + 1, lz)

func _plant_tree(chunk: Chunk, x: int, y: int, z: int) -> void:
	var trunk := 4
	for i in trunk:
		chunk.set_local(x, y + i, z, Blocks.WOOD)
	var top := y + trunk
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(0, 3):
				if abs(dx) == 2 and abs(dz) == 2:
					continue
				var lx := x + dx
				var lz := z + dz
				if lx >= 0 and lx < Chunk.W and lz >= 0 and lz < Chunk.D:
					if chunk.get_local(lx, top - 1 + dy, lz) == Blocks.AIR:
						chunk.set_local(lx, top - 1 + dy, lz, Blocks.LEAVES)

func _height_at(gx: int, gz: int) -> int:
	var n := _noise.get_noise_2d(gx, gz)  # -1..1, rolling hills
	var h := float(SEA_LEVEL) + n * 10.0
	# Mountains: ridged peaks from a low-frequency layer.
	var peak := maxf(_mtn_noise.get_noise_2d(gx, gz), 0.0)
	h += pow(peak, 2.2) * 32.0
	# Streams: carve channels where the river noise crosses zero.
	var r := absf(_river_noise.get_noise_2d(gx, gz))
	if r < 0.05:
		h -= (1.0 - r / 0.05) * 9.0
	return clampi(int(h), 3, Chunk.H - 2)

# --- Global voxel access used by chunks and the player ---

func get_block(gx: int, gy: int, gz: int) -> int:
	if gy < 0 or gy >= Chunk.H:
		return Blocks.AIR
	var key := _chunk_key(gx, gz)
	if not chunks.has(key):
		return Blocks.AIR
	var chunk: Chunk = chunks[key]
	var lx := gx - chunk.cx * Chunk.W
	var lz := gz - chunk.cz * Chunk.D
	return chunk.blocks[Chunk.index(lx, gy, lz)]

func set_block(gx: int, gy: int, gz: int, id: int) -> void:
	if gy < 0 or gy >= Chunk.H:
		return
	var key := _chunk_key(gx, gz)
	if not chunks.has(key):
		return
	var chunk: Chunk = chunks[key]
	var lx := gx - chunk.cx * Chunk.W
	var lz := gz - chunk.cz * Chunk.D
	chunk.set_local(lx, gy, lz, id)
	chunk.rebuild_mesh()
	# Rebuild neighbor chunk too if we touched a border (its culling changed).
	_rebuild_border_neighbors(chunk, lx, lz)

func _rebuild_border_neighbors(chunk: Chunk, lx: int, lz: int) -> void:
	var neighbors: Array[Vector2i] = []
	if lx == 0:
		neighbors.append(Vector2i(chunk.cx - 1, chunk.cz))
	if lx == Chunk.W - 1:
		neighbors.append(Vector2i(chunk.cx + 1, chunk.cz))
	if lz == 0:
		neighbors.append(Vector2i(chunk.cx, chunk.cz - 1))
	if lz == Chunk.D - 1:
		neighbors.append(Vector2i(chunk.cx, chunk.cz + 1))
	for key in neighbors:
		if chunks.has(key):
			chunks[key].rebuild_mesh()

func _chunk_key(gx: int, gz: int) -> Vector2i:
	return Vector2i(floori(float(gx) / Chunk.W), floori(float(gz) / Chunk.D))

func spawn_height(gx: int, gz: int) -> int:
	return maxi(_height_at(gx, gz), SEA_LEVEL) + 3

# --- Arena helpers (used by bots for ground following and steering) ---

# Top solid-terrain block index at this column (ignores water fill).
func terrain_height(gx: int, gz: int) -> int:
	return _height_at(gx, gz)

# True where the solid terrain sits below sea level (a water cell).
func is_water(gx: int, gz: int) -> bool:
	return _height_at(gx, gz) < SEA_LEVEL

# World-space Y a ground bot's feet should rest on. Bots ride the water
# surface rather than sinking through it, but AI steers them away from water.
func ground_y(gx: int, gz: int) -> float:
	return float(maxi(_height_at(gx, gz), SEA_LEVEL) + 1)

# A random voxel column on the spawn ring near the world edge.
func random_edge_xz() -> Vector2:
	var margin := 4
	var lo := MIN_COORD + margin
	var hi := MAX_COORD - margin
	var edge := randi() % 4
	match edge:
		0: return Vector2(lo, randf_range(lo, hi))
		1: return Vector2(hi, randf_range(lo, hi))
		2: return Vector2(randf_range(lo, hi), lo)
		_: return Vector2(randf_range(lo, hi), hi)

func clamp_to_world(p: Vector3) -> Vector3:
	var margin := 2.0
	p.x = clampf(p.x, MIN_COORD + margin, MAX_COORD - margin)
	p.z = clampf(p.z, MIN_COORD + margin, MAX_COORD - margin)
	return p
