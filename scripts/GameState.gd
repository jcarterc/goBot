extends Node
# Autoloaded singleton. Holds the current run's configuration and live stats,
# persists the best score, and mirrors everything to window.__gobot for tests.

signal score_changed(score: int)

enum Density { SPARSE, DENSE, INDIA, CUSTOM }

const DENSITY_RANGE := {
	Density.SPARSE: Vector2i(20, 30),
	Density.DENSE: Vector2i(60, 80),
	Density.INDIA: Vector2i(150, 200),
}
const DENSITY_NAME := {
	Density.SPARSE: "sparse",
	Density.DENSE: "dense",
	Density.INDIA: "india",
	Density.CUSTOM: "custom",
}

const BEST_FILE := "user://gobot_best.save"
const LB_FILE := "user://gobot_leaderboard.save"
const LB_MAX := 10

var leaderboard: Array = []  # [{ "name": String, "score": int }], sorted desc

var game_state := "lobby"          # "lobby" | "playing" | "game_over"
var player_bot_type := "roller"    # "walker" | "roller" | "flyer"
var density_mode := Density.DENSE
var custom_count := 60
var target_population := 70

var player_size := 1.0
var score := 0
var best := 0
var bot_count := 0
var touch_enabled := false
var dominated := false

func _ready() -> void:
	best = _load_best()
	leaderboard = _load_leaderboard()
	# Default the on-screen controls on for touch devices.
	touch_enabled = DisplayServer.is_touchscreen_available()
	publish()

# --- Leaderboard ---

func leaderboard_qualifies(s: int) -> bool:
	if s <= 0:
		return false
	if leaderboard.size() < LB_MAX:
		return true
	return s > int(leaderboard[leaderboard.size() - 1]["score"])

func add_leaderboard_entry(initials: String, s: int) -> void:
	var name := initials.strip_edges().to_upper()
	if name == "":
		name = "AAA"
	name = name.substr(0, 3)
	leaderboard.append({"name": name, "score": s})
	leaderboard.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if leaderboard.size() > LB_MAX:
		leaderboard = leaderboard.slice(0, LB_MAX)
	_save_leaderboard()

func _load_leaderboard() -> Array:
	var raw := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.localStorage.getItem('gobot_leaderboard') || ''", true)
		raw = str(v) if v != null else ""
	elif FileAccess.file_exists(LB_FILE):
		var f := FileAccess.open(LB_FILE, FileAccess.READ)
		if f:
			raw = f.get_as_text()
	if raw == "":
		return []
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Array else []

func _save_leaderboard() -> void:
	var raw := JSON.stringify(leaderboard)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem('gobot_leaderboard', %s)" % JSON.stringify(raw), true)
		return
	var f := FileAccess.open(LB_FILE, FileAccess.WRITE)
	if f:
		f.store_string(raw)

# Resolve the chosen density into a concrete bot count for this run.
func resolve_population() -> int:
	if density_mode == Density.CUSTOM:
		target_population = clampi(custom_count, 10, 250)
	else:
		var r: Vector2i = DENSITY_RANGE[density_mode]
		target_population = randi_range(r.x, r.y)
	return target_population

func start_run() -> void:
	game_state = "playing"
	score = 0
	player_size = 1.0
	dominated = false
	resolve_population()
	publish()

func set_state(s: String) -> void:
	game_state = s
	publish()

func add_score(amount: int) -> void:
	score += amount
	if score > best:
		best = score
		_save_best(best)
	score_changed.emit(score)
	publish()

func density_label() -> String:
	return DENSITY_NAME[density_mode]

func _load_best() -> int:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.localStorage.getItem('gobot_best') || '0'", true)
		return int(str(v)) if v != null else 0
	if FileAccess.file_exists(BEST_FILE):
		var f := FileAccess.open(BEST_FILE, FileAccess.READ)
		if f:
			return int(f.get_line())
	return 0

func _save_best(value: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem('gobot_best', '%d')" % value, true)
		return
	var f := FileAccess.open(BEST_FILE, FileAccess.WRITE)
	if f:
		f.store_line(str(value))

# Mirror state to the browser so Playwright can assert on real game logic.
func publish() -> void:
	if not OS.has_feature("web"):
		return
	var js := """
		window.__gobot = {
			game_state: "%s",
			player_size: %f,
			player_bot_type: "%s",
			score: %d,
			best: %d,
			bot_count: %d,
			density_mode: "%s",
			ready: true
		};
	""" % [game_state, player_size, player_bot_type, score, best,
		bot_count, density_label()]
	JavaScriptBridge.eval(js, true)
