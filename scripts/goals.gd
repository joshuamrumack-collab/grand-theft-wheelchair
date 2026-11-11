extends Node3D
## THPS-style level goals: small, clear challenges with a cred reward. Progress is saved.
## Add your own: put a new entry in GOALS and tick it off in _on_event() or _physics_process().

const GOALS := [
	{"id": "ramp", "title": "Collect R-A-M-P", "hint": "Four floating letters around the skate spots", "cred": 500},
	{"id": "combo5k", "title": "Land a 5,000 point combo", "hint": "Link tricks with wheelies and grinds", "cred": 400},
	{"id": "wheelie", "title": "Wheelie for 6 seconds", "hint": "Hold X on the ground, let go before you faceplant", "cred": 300},
	{"id": "signs", "title": "Smash 5 STAIRS INC. signs", "hint": "White signs on the sidewalks", "cred": 400, "n": 5},
	{"id": "grind", "title": "Grind 40 m in total", "hint": "Hop next to a curb, ledge or rail", "cred": 400, "n": 40},
	{"id": "540", "title": "Land a 540 spin", "hint": "Steer in the air off a big ramp or the half-pipe", "cred": 400},
	{"id": "vert", "title": "Get vert air in a half-pipe", "hint": "Roll up a quarter pipe fast", "cred": 300},
	{"id": "donut", "title": "Bribe a cop with a donut", "hint": "Grab a pink donut box, press F near cops", "cred": 250},
	{"id": "trip", "title": "Make a cop trip over a cone", "hint": "Lead the chase through traffic cones", "cred": 250},
	{"id": "tape", "title": "Find the secret cassette", "hint": "Somewhere down an alley...", "cred": 750},
]

var w
var letters: Array = []     # {node, letter}
var tape: Node3D = null
var wheelie_best: float = 0.0
var flash: Array = []

func setup(world) -> void:
	w = world
	GameState.event.connect(_on_event)
	var city: City = w.city
	var spots: Array = []
	for s in city.stunt_spots:
		spots.append(s)
	# R over the park half-pipe, A over the plaza funbox, M high above a stunt ramp, P over a plaza kicker
	var want := ["R", "A", "M", "P"]
	var sk: Vector3 = city.points.get("skate", Vector3(100, 0, 100))
	var hp_park := Vector3.INF
	for s in city.stunt_spots:
		if s.label == "HALF-PIPE" and s.pos.distance_to(sk) > 30.0:
			hp_park = s.pos
			break
	var ramp_pos := Vector3.INF
	for s in city.stunt_spots:
		if s.label == "RAMP":
			ramp_pos = s.pos
			break
	var pos := {
		"R": (hp_park if hp_park != Vector3.INF else sk) + Vector3(0, 4.2, 0),
		"A": sk + Vector3(0, 2.2, -2.5),
		"M": (ramp_pos if ramp_pos != Vector3.INF else sk) + Vector3(0, 3.0, 0),
		"P": sk + Vector3(11, 2.6, 1.0),
	}
	var got: Array = GameState.goal_prog.get("ramp_letters", [])
	for L in want:
		if L in got or GameState.goals.has("ramp"):
			continue
		var lbl := Label3D.new()
		lbl.text = L
		lbl.font_size = 220
		lbl.pixel_size = 0.008
		lbl.outline_size = 36
		lbl.modulate = Color("ffd84a")
		lbl.outline_modulate = Color("2a1240")
		lbl.position = pos[L]
		lbl.no_depth_test = false
		add_child(lbl)
		letters.append({"node": lbl, "letter": L, "base": pos[L]})
	if not GameState.goals.has("tape") and not city.alley_spots.is_empty():
		var d: Vector3 = city.alley_spots[mini(7, city.alley_spots.size() - 1)]
		tape = Node3D.new()
		Models.box(tape, Vector3(0.36, 0.22, 0.06), Vector3.ZERO, Models.mat(Color("1a1a1a"), 0.4))
		Models.box(tape, Vector3(0.3, 0.1, 0.065), Vector3(0, 0.03, 0), Models.mat(Color("ff3d7f"), 0.4, 0.0, Color("ff3d7f"), 1.5))
		tape.position = d + Vector3(0, 0.6, 0)
		add_child(tape)

func done(id: String) -> bool:
	return GameState.goals.has(id)

func count() -> int:
	return GameState.goals.size()

func progress_text(g: Dictionary) -> String:
	var id: String = g.id
	if done(id):
		return "DONE"
	match id:
		"ramp": return "%d/4" % GameState.goal_prog.get("ramp_letters", []).size()
		"signs": return "%d/%d" % [int(GameState.goal_prog.get("signs", 0)), g.n]
		"grind": return "%d/%d m" % [int(GameState.goal_prog.get("grind", 0.0)), g.n]
		"wheelie": return "best %.1fs" % float(GameState.goal_prog.get("wheelie", 0.0))
	return ""

func complete(id: String) -> void:
	if done(id):
		return
	GameState.goals[id] = true
	var g: Dictionary = {}
	for x in GOALS:
		if x.id == id:
			g = x
	GameState.add_cred(g.get("cred", 100))
	GameState.say_banner("GOAL COMPLETE!", "%s   +$%d   (%d/%d)" % [g.get("title", id), g.get("cred", 100), count(), GOALS.size()], Color("39ff14"))
	Sfx.play("goal")
	w.fx_confetti(GameState.player.global_position, 90)
	GameState.save_game()
	if count() == GOALS.size():
		GameState.say_sub("SPOKE (on the phone)", "Every goal in Los Spokos?! Kid, you're a legend.", Color("ffd84a"))

func _on_event(ev: String, data: Dictionary) -> void:
	match ev:
		"combo":
			if data.total >= 5000:
				complete("combo5k")
		"stairs_sign":
			GameState.goal_prog["signs"] = int(GameState.goal_prog.get("signs", 0)) + 1
			if GameState.goal_prog["signs"] >= 5:
				complete("signs")
		"grind":
			GameState.goal_prog["grind"] = float(GameState.goal_prog.get("grind", 0.0)) + data.m
			if GameState.goal_prog["grind"] >= 40.0:
				complete("grind")
		"trick":
			var n: String = data.name
			if n == "VERT AIR":
				complete("vert")
			for deg in ["540", "720", "900", "1080"]:
				if n.ends_with(" " + deg):
					complete("540")
		"donut_bribe":
			complete("donut")
		"cop_trip":
			complete("trip")

func _physics_process(dt: float) -> void:
	if w == null or w.state == "title":
		return
	var p: Chair = GameState.player
	if p == null:
		return
	if p.wheelie:
		wheelie_best = maxf(wheelie_best, p.wheelie_t)
		if p.wheelie_t > float(GameState.goal_prog.get("wheelie", 0.0)):
			GameState.goal_prog["wheelie"] = p.wheelie_t
		if p.wheelie_t >= 6.0:
			complete("wheelie")
	for L in letters.duplicate():
		var n: Label3D = L.node
		n.rotation.y += dt * 2.0
		n.position = L.base + Vector3.UP * sin(GameState.time * 2.5) * 0.15
		if p.global_position.distance_to(n.global_position) < 1.7 or (p.global_position + Vector3.UP).distance_to(n.global_position) < 1.7:
			var got: Array = GameState.goal_prog.get("ramp_letters", [])
			got.append(L.letter)
			GameState.goal_prog["ramp_letters"] = got
			GameState.pop(n.global_position, "%s!  (%d/4)" % [L.letter, got.size()], Color("ffd84a"))
			Sfx.play("pickup", 1.2)
			n.queue_free()
			letters.erase(L)
			if got.size() >= 4:
				complete("ramp")
	if tape != null:
		tape.rotation.y += dt * 2.5
		if p.global_position.distance_to(tape.global_position) < 1.8:
			tape.queue_free()
			tape = null
			GameState.say_sub("SECRET CASSETTE", "\"Greatest Rolls, Vol. 1\" — you found it!", Color("ff3d7f"))
			complete("tape")
