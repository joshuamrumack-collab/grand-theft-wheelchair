extends Node
## Global game state: money, wanted level, Chairdex, chair stats, input setup.

signal banner(title: String, sub: String, color: Color)
signal float_text(pos: Vector3, text: String, color: Color)
signal subtitle(who: String, text: String, color: Color)
@warning_ignore("unused_signal")
signal event(ev: String, data: Dictionary)

var cred: int = 0
var wanted: int = 0
var wanted_cool: float = 0.0
var dex: Dictionary = {}
var world: Node = null
var player: Node = null # the chair the player sits in
var time: float = 0.0
var bust_t: float = 0.0
var slowmo: float = 1.0
var stunts_done: Array = []
var races_won: int = 0
var story: int = 0                 # next story mission
var revolution: int = 0            # Ramp Revolution %
var crates_smashed: Array = []
const SAVE_PATH := "user://gtw_save.json"
# settings (pause menu)
var is_web: bool = OS.has_feature("web") or "--web" in OS.get_cmdline_user_args()   # --web: test the browser settings on a PC
var quality: int = 3 if is_web else 1   # 0 low, 1 medium, 2 high, 3 potato (old school PCs / browser)
const QUALITY_NAMES := ["Low", "Medium", "High", "Potato (school PC)"]
var fullscreen: bool = false
# accessibility
var assist_steer: bool = false        # steering help: avoids walls, keeps you straight on roads, no grind wobble
var one_switch: bool = false          # rolls by itself; one button (SPACE) = hop / tricks, hold = wheelie
var hud_scale: float = 1.0
var colorblind: bool = false
# Create-a-Rider
var look: Dictionary = {"hair": "HairSpiky", "hat": "", "face": 0, "print": 0, "shades": true,
	"skin": "e8b48a", "shirt": "3c8d2f", "pants": "2b3a55", "hair_color": "2b1d0e"}
# goals and pickups
var goals: Dictionary = {}            # id -> true when done
var goal_prog: Dictionary = {}        # id -> progress number
var donuts: int = 0
var game_speed: float = 1.0
var retro: bool = false               # optional "RETRO 2001" CRT-style filter (F3)
var settings_toggle_boost: bool = false
var settings_toggle_wheelie: bool = false
# Pimp My Chair: your style follows you into every chair you steal
var style: Dictionary = {"paint": "", "neon": "", "rims": false, "dice": false, "horn": false, "flames": false}
var owned: Dictionary = {}
const SHOP := [
	{"id": "pink", "label": "Paint: Hot Pink", "price": 250, "kind": "paint"},
	{"id": "chrome", "label": "Paint: Chrome", "price": 300, "kind": "paint"},
	{"id": "black", "label": "Paint: Midnight Black", "price": 250, "kind": "paint"},
	{"id": "rainbow", "label": "Paint: RAINBOW", "price": 600, "kind": "paint"},
	{"id": "neon", "label": "Neon underglow (click again to change colour)", "price": 400, "kind": "neon"},
	{"id": "rims", "label": "Golden rims", "price": 300, "kind": "toggle"},
	{"id": "dice", "label": "Fuzzy dice", "price": 100, "kind": "toggle"},
	{"id": "horn", "label": "Air horn (replaces the bell)", "price": 150, "kind": "toggle"},
	{"id": "flames", "label": "Turbo flames on every chair", "price": 200, "kind": "toggle"},
]
const NEONS := ["00e5ff", "ff2bd6", "39ff14", "ffd000"]

# Speeds in metres/second, turn in radians/second, grip = fraction of sideways slide removed per 1/60 s.
const TYPES := {
	"rusty":    {"name": "Rusty Rollie",        "desc": "Squeaks. Constantly.",                "color": Color("8a8f98"), "max": 6.0,  "acc": 7.0,  "turn": 3.0, "grip": 0.13},
	"hospital": {"name": "Hospital Loaner",     "desc": "Free IV pole included",               "color": Color("cfd8e0"), "max": 5.6,  "acc": 6.0,  "turn": 3.1, "grip": 0.07},
	"power":    {"name": "PowerChair 3000",     "desc": "Joystick-guided precision",           "color": Color("2f7de1"), "max": 8.0,  "acc": 8.0,  "turn": 2.7, "grip": 0.25},
	"turbo":    {"name": "Turbo Sprint X",      "desc": "Carbon fibre. Zero chill.",           "color": Color("e8343f"), "max": 11.0, "acc": 11.0, "turn": 3.4, "grip": 0.07},
	"monster":  {"name": "Monster Chair",       "desc": "Bounces cars. Probably.",             "color": Color("3fb950"), "max": 8.0,  "acc": 7.5,  "turn": 2.4, "grip": 0.16, "big": true},
	"cart":     {"name": "Shopping Cart",       "desc": "Legally a wheelchair (citation needed)", "color": Color("b8c2cc"), "max": 9.0, "acc": 9.0, "turn": 2.2, "grip": 0.035},
	"cop":      {"name": "Kerb Patrol Cruiser", "desc": "Lights! Sirens! Cupholders!",         "color": Color("1b2a4a"), "max": 10.0, "acc": 10.0, "turn": 3.2, "grip": 0.13},
	"gold":     {"name": "THE GOLDEN THRONE",   "desc": "Deliver it to Spoke's Chop Shop!",    "color": Color("f5c542"), "max": 9.5,  "acc": 9.5,  "turn": 3.2, "grip": 0.11},
}
const DEX_ORDER := ["rusty", "hospital", "power", "turbo", "monster", "cart", "cop", "gold"]
const CIVILIAN_TYPES := ["rusty", "hospital", "power", "turbo", "monster", "cart"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

func _process(delta: float) -> void:
	time += delta

func _setup_input() -> void:
	_keys("forward", [KEY_W, KEY_UP])
	_keys("back", [KEY_S, KEY_DOWN])
	_keys("left", [KEY_A, KEY_LEFT])
	_keys("right", [KEY_D, KEY_RIGHT])
	_keys("boost", [KEY_SHIFT])
	_keys("steal", [KEY_E])
	_keys("hop", [KEY_SPACE])
	_keys("bell", [KEY_H])
	_keys("retro", [KEY_F3])
	_keys("wheelie", [KEY_X])
	_keys("camera", [KEY_C])
	_keys("daynight", [KEY_N])
	_keys("pause", [KEY_ESCAPE])
	_keys("quality", [KEY_F2])
	_keys("radio", [KEY_R])
	_keys("donut", [KEY_F])
	_keys("photo", [KEY_P])
	_keys("replay", [KEY_T])
	_keys("fullscreen", [KEY_F11])
	# Gamepad
	_joy_axis("forward", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_axis("back", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_joy_button("steal", JOY_BUTTON_Y)
	_joy_button("boost", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_button("hop", JOY_BUTTON_A)
	_joy_button("wheelie", JOY_BUTTON_X)
	_joy_button("bell", JOY_BUTTON_B)
	_joy_button("camera", JOY_BUTTON_RIGHT_STICK)
	_joy_button("pause", JOY_BUTTON_START)
	_joy_button("radio", JOY_BUTTON_DPAD_UP)
	_joy_button("donut", JOY_BUTTON_LEFT_SHOULDER)
	_joy_button("replay", JOY_BUTTON_DPAD_DOWN)
	_joy_button("photo", JOY_BUTTON_BACK)

func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func _joy_axis(action: String, axis: int, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis as JoyAxis
	e.axis_value = value
	InputMap.action_add_event(action, e)

func _joy_button(action: String, button: int) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	InputMap.action_add_event(action, e)

func save_game() -> void:
	var data := {"cred": cred, "dex": dex.keys(), "owned": owned.keys(), "style": style, "stunts": stunts_done, "races_won": races_won, "story": story, "revolution": revolution, "crates": crates_smashed, "retro": retro,
		"settings": {("quality_web" if is_web else "quality"): quality, "fullscreen": fullscreen, "assist": assist_steer, "one_switch": one_switch, "hud_scale": hud_scale,
			"colorblind": colorblind, "speed": game_speed, "toggle_boost": settings_toggle_boost, "toggle_wheelie": settings_toggle_wheelie},
		"look": look, "goals": goals, "goal_prog": goal_prog}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	cred = int(data.get("cred", 0))
	for k in data.get("dex", []):
		dex[k] = true
	for k in data.get("owned", []):
		owned[k] = true
	var st: Dictionary = data.get("style", {})
	for k in st.keys():
		if style.has(k):
			style[k] = st[k]
	for s in data.get("stunts", []):
		stunts_done.append(int(s))
	races_won = int(data.get("races_won", 0))
	story = int(data.get("story", 0))
	revolution = int(data.get("revolution", 0))
	retro = bool(data.get("retro", false))
	var sets: Dictionary = data.get("settings", {})
	quality = int(sets.get("quality_web" if is_web else "quality", quality))
	fullscreen = bool(sets.get("fullscreen", fullscreen))
	assist_steer = bool(sets.get("assist", assist_steer))
	one_switch = bool(sets.get("one_switch", one_switch))
	hud_scale = float(sets.get("hud_scale", hud_scale))
	colorblind = bool(sets.get("colorblind", colorblind))
	game_speed = float(sets.get("speed", game_speed))
	settings_toggle_boost = bool(sets.get("toggle_boost", settings_toggle_boost))
	settings_toggle_wheelie = bool(sets.get("toggle_wheelie", settings_toggle_wheelie))
	var lk: Dictionary = data.get("look", {})
	for k in lk.keys():
		look[k] = lk[k]
	goals = data.get("goals", {})
	goal_prog = data.get("goal_prog", {})
	for c in data.get("crates", []):
		crates_smashed.append(int(c))
	return true

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	cred = 0
	dex = {"rusty": true}
	owned = {}
	style = {"paint": "", "neon": "", "rims": false, "dice": false, "horn": false, "flames": false}
	stunts_done = []
	races_won = 0
	story = 0
	revolution = 0
	crates_smashed = []
	goals = {}
	goal_prog = {}
	donuts = 0

func add_cred(amount: int, pos: Vector3 = Vector3.INF, label: String = "") -> void:
	cred = max(0, cred + amount)
	if pos != Vector3.INF:
		var t := label if label != "" else ("+$%d" % amount)
		float_text.emit(pos, t, Color("8cff6a") if amount >= 0 else Color("ff5c8a"))

func add_wanted(n: int) -> void:
	wanted = clampi(wanted + n, 0, 5)
	wanted_cool = 0.0

func say_banner(title: String, sub: String = "", color: Color = Color("ffd84a")) -> void:
	banner.emit(title, sub, color)

func say_sub(who: String, text: String, color: Color = Color.WHITE) -> void:
	subtitle.emit(who, text, color)

func pop(pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	float_text.emit(pos, text, color)


## Colour-blind friendly palette (Okabe-Ito): maps the game's signal colours to hues that stay distinct
## for red-green colour blindness. Shapes/letters on the minimap carry the meaning as well.
func cb(c: Color) -> Color:
	if not colorblind:
		return c
	var h := c.h * 360.0
	if c.s < 0.25:
		return c
	var out: Color
	if h < 20.0 or h >= 330.0: out = Color("d55e00")      # red -> vermillion
	elif h < 45.0: out = Color("e69f00")                   # orange
	elif h < 70.0: out = Color("f0e442")                   # yellow
	elif h < 170.0: out = Color("0072b2")                  # green -> blue
	elif h < 210.0: out = Color("56b4e9")                  # cyan -> sky blue
	elif h < 260.0: out = Color("0072b2")                  # blue
	else: out = Color("cc79a7")                            # purple / pink -> reddish purple
	out.a = c.a
	return out
