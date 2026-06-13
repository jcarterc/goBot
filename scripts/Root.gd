extends Node
# Top-level flow controller: Title -> Lobby -> Arena -> Game Over.

var _title: TitleScreen
var _lobby: Lobby
var _arena: Arena
var _gameover: GameOverScreen
var _victory: VictoryScreen

func _ready() -> void:
	_show_title()

func _show_title() -> void:
	_clear_all()
	GameState.set_state("lobby")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title = TitleScreen.new()
	_title.start_pressed.connect(_show_lobby)
	add_child(_title)

func _show_lobby() -> void:
	_clear_all()
	GameState.set_state("lobby")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lobby = Lobby.new()
	_lobby.start_game.connect(_start_game)
	add_child(_lobby)

func _start_game() -> void:
	_clear_all()
	GameState.start_run()
	_arena = Arena.new()
	_arena.configure(GameState.player_bot_type, GameState.target_population)
	_arena.game_over.connect(_on_game_over)
	_arena.dominated.connect(_on_dominated)
	add_child(_arena)

func _on_game_over(killer_type: String) -> void:
	# Freeze the arena under the overlay.
	if _arena:
		_arena.process_mode = Node.PROCESS_MODE_DISABLED
	_gameover = GameOverScreen.new()
	_gameover.configure(killer_type)
	_gameover.play_again.connect(_play_again)
	_gameover.change_bot.connect(_show_lobby)
	add_child(_gameover)

func _play_again() -> void:
	_start_game()

func _on_dominated() -> void:
	# Pause under a triumphant overlay; the run can resume (still mortal).
	if _arena:
		_arena.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_victory = VictoryScreen.new()
	_victory.keep_playing.connect(_resume_from_victory)
	_victory.new_game.connect(_show_lobby)
	add_child(_victory)

func _resume_from_victory() -> void:
	if _victory != null and is_instance_valid(_victory):
		_victory.queue_free()
	_victory = null
	if _arena:
		_arena.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.set_state("playing")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clear_all() -> void:
	for n in [_title, _lobby, _arena, _gameover, _victory]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_title = null
	_lobby = null
	_arena = null
	_gameover = null
	_victory = null
