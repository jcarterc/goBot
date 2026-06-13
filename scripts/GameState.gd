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

var leaderboard: Array = []        # global top-10, sorted desc
var daily_leaderboard: Array = []  # today's daily-challenge top-10

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

# Combo (runtime).
var combo := 0
var combo_mult := 1.0

# Daily challenge.
var daily_mode := false

# Unlockable cosmetic skins, gated by best score. tint multiplies bot color.
const SKINS := [
	{"name": "Default", "tint": Color(1, 1, 1), "unlock": 0},
	{"name": "Crimson", "tint": Color(1.0, 0.45, 0.45), "unlock": 500},
	{"name": "Emerald", "tint": Color(0.45, 1.0, 0.6), "unlock": 2000},
	{"name": "Gold", "tint": Color(1.0, 0.85, 0.3), "unlock": 5000},
	{"name": "Void", "tint": Color(0.6, 0.4, 1.0), "unlock": 12000},
]
var selected_skin := 0

# Lifetime stats (persisted).
const STATS_FILE := "user://gobot_stats.save"
var stats := {"games": 0, "bots_eaten": 0, "biggest": 0.0, "longest": 0.0, "top_combo": 0}
var _run_start_ms := 0
var bots_eaten_run := 0

func skin_unlocked(i: int) -> bool:
	return best >= int(SKINS[i]["unlock"])

func skin_tint() -> Color:
	if selected_skin >= 0 and selected_skin < SKINS.size() and skin_unlocked(selected_skin):
		return SKINS[selected_skin]["tint"]
	return Color.WHITE

func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])

func _date_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d%02d%02d" % [d["year"], d["month"], d["day"]]

func _ready() -> void:
	best = _load_best()
	leaderboard = _load_leaderboard()
	daily_leaderboard = _load_daily()
	stats = _load_stats()
	# Default the on-screen controls on for touch devices.
	touch_enabled = DisplayServer.is_touchscreen_available()
	publish()

func _load_stats() -> Dictionary:
	var raw := _read_store("gobot_stats", STATS_FILE)
	if raw == "":
		return stats
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else stats

func _save_stats() -> void:
	_write_store("gobot_stats", STATS_FILE, JSON.stringify(stats))

# Record end-of-run stats.
func finish_run() -> void:
	stats["games"] = int(stats.get("games", 0)) + 1
	stats["bots_eaten"] = int(stats.get("bots_eaten", 0)) + bots_eaten_run
	stats["biggest"] = maxf(float(stats.get("biggest", 0.0)), player_size)
	var elapsed := (Time.get_ticks_msec() - _run_start_ms) / 1000.0
	stats["longest"] = maxf(float(stats.get("longest", 0.0)), elapsed)
	stats["top_combo"] = maxi(int(stats.get("top_combo", 0)), combo)
	_save_stats()

# --- Leaderboard ---

# The board the current run competes on (daily during a daily challenge).
func active_leaderboard() -> Array:
	return daily_leaderboard if daily_mode else leaderboard

func leaderboard_qualifies(s: int) -> bool:
	if s <= 0:
		return false
	var board := active_leaderboard()
	if board.size() < LB_MAX:
		return true
	return s > int(board[board.size() - 1]["score"])

func add_leaderboard_entry(initials: String, s: int) -> void:
	var name := initials.strip_edges().to_upper()
	if name == "":
		name = "AAA"
	name = name.substr(0, 3)
	leaderboard = _insert_entry(leaderboard, name, s)
	_write_store("gobot_leaderboard", LB_FILE, JSON.stringify(leaderboard))
	if daily_mode:
		daily_leaderboard = _insert_entry(daily_leaderboard, name, s)
		_write_store("gobot_lb_" + _date_key(), LB_FILE + "." + _date_key(), JSON.stringify(daily_leaderboard))

func _insert_entry(board: Array, name: String, s: int) -> Array:
	board.append({"name": name, "score": s})
	board.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if board.size() > LB_MAX:
		board = board.slice(0, LB_MAX)
	return board

func _load_leaderboard() -> Array:
	var raw := _read_store("gobot_leaderboard", LB_FILE)
	if raw == "":
		return []
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Array else []

func _load_daily() -> Array:
	var raw := _read_store("gobot_lb_" + _date_key(), LB_FILE + "." + _date_key())
	if raw == "":
		return []
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Array else []

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
	combo = 0
	combo_mult = 1.0
	bots_eaten_run = 0
	_run_start_ms = Time.get_ticks_msec()
	resolve_population()
	publish()

# Generic key/value persistence: localStorage on web, user:// file otherwise.
func _read_store(web_key: String, file_path: String) -> String:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.localStorage.getItem('%s') || ''" % web_key, true)
		return str(v) if v != null else ""
	if FileAccess.file_exists(file_path):
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""

func _write_store(web_key: String, file_path: String, value: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.localStorage.setItem('%s', %s)" % [web_key, JSON.stringify(value)], true)
		return
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string(value)

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
