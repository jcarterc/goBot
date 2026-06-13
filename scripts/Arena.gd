class_name Arena
extends Node3D
# Assembles a single play session: voxel terrain (arena mode), the player bot,
# the bot population, the follow camera and the HUD. Emits game_over on death.

signal game_over(killer_type: String)
signal dominated
signal evolve(perks: Array)

var bot_type := "roller"
var target_population := 70

var world: World
var player: Bot
var spawner: BotSpawner
var camera: CameraController
var hud: ArenaHUD
var touch: TouchControls
var powerups: PowerUpManager
var _music: AudioStreamPlayer
var _tension: AudioStreamPlayer

func configure(p_bot_type: String, p_target: int) -> void:
	bot_type = p_bot_type
	target_population = p_target

func _ready() -> void:
	_build_world()
	_build_spawner()
	_build_player()
	_build_powerups()
	_build_camera_and_hud()
	_build_music()
	spawner.spawn_initial()
	spawner.player_died.connect(_on_player_died)
	spawner.player_dominated.connect(func(): dominated.emit())
	spawner.player_evolve.connect(func(perks): evolve.emit(perks))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_powerups() -> void:
	powerups = PowerUpManager.new()
	powerups.setup(world, player, spawner)
	add_child(powerups)

func _build_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = SoundSynth.music_loop()
	_music.volume_db = -14.0
	_music.bus = "Master"
	add_child(_music)
	_music.play()
	# Tension layer, silent until a big threat closes in.
	_tension = AudioStreamPlayer.new()
	_tension.stream = SoundSynth.tension_loop()
	_tension.volume_db = -60.0
	_tension.bus = "Master"
	add_child(_tension)
	_tension.play()

func _process(_delta: float) -> void:
	if _tension == null or spawner == null:
		return
	var t := spawner.threat_level()
	var target_db := lerpf(-60.0, -8.0, t)
	_tension.volume_db = lerpf(_tension.volume_db, target_db, 0.05)

func _build_world() -> void:
	world = World.new()
	world.arena_mode = true
	add_child(world)

func _build_spawner() -> void:
	spawner = BotSpawner.new()
	add_child(spawner)

func _build_player() -> void:
	player = _make_bot(bot_type)
	player.is_player_controlled = true
	player.setup(bot_type, 1.0, world, spawner)
	add_child(player)
	var gy := world.ground_y(0, 0)
	var start := Vector3(0.5, gy, 0.5)
	if bot_type == "flyer":
		start.y += 12.0
	player.global_position = start
	player.apply_skin_tint(GameState.skin_tint())
	spawner.setup(world, player, target_population)
	spawner.register_player(player)
	GameState.player_size = 1.0

func _build_camera_and_hud() -> void:
	camera = CameraController.new()
	camera.setup(player)
	add_child(camera)
	spawner.camera = camera

	touch = TouchControls.new()
	touch.setup(player)
	touch.visible = GameState.touch_enabled
	add_child(touch)
	camera.touch = touch
	touch.view_toggled.connect(camera.toggle_view)
	touch.dash_pressed.connect(player.try_dash)
	touch.ability_pressed.connect(player.use_ability)

	hud = ArenaHUD.new()
	hud.setup(player, spawner, camera, powerups)
	hud.respawn_requested.connect(spawner.respawn_player)
	add_child(hud)

func _make_bot(btype: String) -> Bot:
	match btype:
		"walker": return WalkerBot.new()
		"flyer": return FlyerBot.new()
		_: return RollerBot.new()

func _on_player_died(killer_type: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_over.emit(killer_type)
