extends Node
## Early-2000s skate-game trick and combo system for the player's chair.
##   SPACE            hop (the "ollie")
##   steer in the air spin: 180 / 360 / 540 ...
##   X in the air     grab trick (hold it), direction picks the grab
##   SPACE in the air flip trick, direction picks the flip
##   X on the ground  wheelie manual: links tricks together into one combo
##   X next to a curb / ledge / rail (ground or air)  GRIND
## Land straight (forwards or backwards) or you bail and lose the combo.
## Banked combos pay street cred and fill the SPECIAL meter; a full meter unlocks special tricks.

var w                                  # main.gd
var combo: Array = []                  # trick names in the current combo
var combo_pts: int = 0
var grace: float = 0.0                 # time left to link another trick after landing
var live: bool = false

var in_air: bool = false
var last_yaw: float = 0.0
var spin_acc: float = 0.0
var air_time: float = 0.0
var grab_name: String = ""
var grab_t: float = 0.0
var grab_total: float = 0.0
var flip_t: float = 0.0               # >0 while a flip animation is playing
var flip_axis: String = "roll"
var flip_dir: float = 1.0
var flip_turns: float = 1.0
var flips_this_air: int = 0
var revert_t: float = 0.0
var manual_on: bool = false

var special: float = 0.0               # 0..1
var special_on: bool = false
var best_combo: int = 0
# grinding
var grind: Dictionary = {}             # {rail, s, dir, speed, t, bal, bal_v, name}
var grind_m: float = 0.0               # metres ground in total (goals / story)
var grind_cool: float = 0.0
var grind_req: float = 0.0     # X pressed near an edge: grind if a rail/curb is in reach within this window
var was_vert: bool = false
var bank_count: int = 0
var os_down: float = -1.0

func one_switch_held() -> bool:
	return GameState.one_switch and os_down >= 0.0 and GameState.time - os_down > 0.3
var last_bail: String = ""

# HUD
var flash_text: String = ""            # last banked combo / bail, shown briefly
var flash_col: Color = Color.WHITE
var flash_t: float = 0.0

const GRACE := 0.85
const FLIP_TIME := 0.3

const GRABS := {
	"": ["PUSH-HANDLE GRAB", 250],
	"left": ["SPOKE GRAB", 300],
	"right": ["CUSHION GRAB", 300],
	"forward": ["FOOTREST GRAB", 350],
	"back": ["TIRE GRAB", 350],
}
const FLIPS := {
	"": ["CASTER FLIP", 300, "roll", 1.0],
	"left": ["HUB FLIP", 400, "roll", -1.0],
	"right": ["SPOKE FLIP", 400, "roll", 1.0],
	"forward": ["FRONT FLIP", 650, "pitch", -1.0],
	"back": ["BACKFLIP", 650, "pitch", 1.0],
}
const SPECIALS := {
	"": ["THE KERB DESTROYER", 1500, "roll", 2.0],
	"left": ["BARON'S NIGHTMARE", 1800, "roll", -2.0],
	"right": ["RAMP REVOLUTION 900", 1800, "roll", 2.0],
	"forward": ["DOUBLE FRONT OF FREEDOM", 2200, "pitch", -2.0],
	"back": ["STAIRWAY TO HEAVEN", 2200, "pitch", 2.0],
}
const BAIL_LINES := ["BAIL!", "SLAM!", "OOF!", "CURB'D!", "GRAVITY 1, YOU 0", "TOTALLY MEANT THAT"]

func setup(world) -> void:
	w = world

func _dir() -> String:
	var x := Input.get_axis("left", "right")
	var y := Input.get_axis("back", "forward")
	if abs(x) < 0.4 and abs(y) < 0.4:
		return ""
	if abs(y) >= abs(x):
		return "forward" if y > 0.0 else "back"
	return "right" if x > 0.0 else "left"

func _unhandled_input(event: InputEvent) -> void:
	if w == null or w.state != "play" or w.hop != null:
		return
	var p: Chair = GameState.player
	if p == null:
		return
	# one-switch: tap = hop (or a trick in the air), hold on the ground = wheelie
	if GameState.one_switch and p.is_on_floor() and not in_air and grind.is_empty():
		if event.is_action_pressed("hop"):
			os_down = GameState.time
			return
		if event.is_action_released("hop") and os_down >= 0.0:
			var held := GameState.time - os_down
			os_down = -1.0
			if held < 0.3:
				p.hop()
			return
	if event.is_action_pressed("hop") and not grind.is_empty():
		_end_grind(p, true)
		return
	if event.is_action_pressed("wheelie"):
		grind_req = 0.3                       # X near a curb / ledge / rail = grind (otherwise wheelie or grab)
	if event.is_action_pressed("hop"):
		if not in_air and p.is_on_floor():
			if p.wheelie:
				end_manual(p)                     # ollie out of a manual keeps the combo
				p.wheelie = false
				w.wheelie_toggled = false
			p.hop()
		elif in_air and flip_t <= 0.0 and flips_this_air < 3:
			_start_flip()
	elif event.is_action_pressed("wheelie") and in_air and grab_name == "":
		var g: Array = GRABS[_dir()]
		grab_name = g[0]
		grab_t = 0.0

func _start_flip() -> void:
	var d := _dir()
	var f: Array = (SPECIALS if special_on else FLIPS)[d]
	flip_axis = f[2]
	flip_dir = signf(f[3])
	flip_turns = abs(f[3])
	flip_t = FLIP_TIME * (1.0 + (flip_turns - 1.0) * 0.6)
	flips_this_air += 1
	var trick_name: String = f[0]
	var pts: int = f[1]
	if special_on:
		Sfx.play("steal", 1.3)
		w.shake(0.25)
	add_trick(trick_name, pts)
	Sfx.play("jump", 1.6, -4.0)

func add_trick(trick_name: String, pts: int) -> void:
	if not live:
		live = true
		combo.clear()
		combo_pts = 0
	# repeating the same trick in one combo is worth less, like the real thing
	var reps := combo.count(trick_name)
	pts = int(pts / float(1 + reps))
	combo.append(trick_name)
	combo_pts += pts
	GameState.event.emit("trick", {"name": trick_name})
	grace = GRACE

func mult() -> int:
	return maxi(1, combo.size())

func combo_text() -> String:
	var t := ""
	var shown: Array = combo.slice(maxi(0, combo.size() - 6))
	if combo.size() > 6:
		t = "... + "
	t += " + ".join(shown)
	if grab_name != "":
		t += (" + " if t != "" else "") + grab_name
	if manual_on:
		t += (" + " if t != "" else "") + "WHEELIE MANUAL"
	return t

func live_score() -> int:
	var extra := 0
	if grab_name != "":
		extra += int(GRABS.values().filter(func(g): return g[0] == grab_name)[0][1] + grab_t * 400)
	var p: Chair = GameState.player
	if manual_on and p != null:
		extra += int(60 + p.wheelie_t * 160)
	return combo_pts + extra

func _physics_process(dt: float) -> void:
	if w == null:
		return
	var p: Chair = GameState.player
	if p == null:
		return
	if flash_t > 0.0:
		flash_t -= dt
	if special_on:
		special = maxf(0.0, special - dt * 0.035)
		if special <= 0.0:
			special_on = false
	grind_cool -= dt
	if not grind.is_empty():
		_grind_step(p, dt)
		return
	var airborne := not p.is_on_floor() and p.air_t > 0.14
	grind_req -= dt
	# grinds only start when you ask for one (X near an edge). One-switch mode keeps the old auto-grind.
	var want := grind_req > 0.0 or (GameState.one_switch and airborne)
	if want and grind_cool <= 0.0 and p.velocity.y < 2.0:
		if _try_grind(p, not airborne):
			grind_req = 0.0
			return
	if airborne and not in_air:
		was_vert = p.vert
		in_air = true
		spin_acc = 0.0
		air_time = 0.0
		flips_this_air = 0
		last_yaw = p.yaw
		if p.wheelie:
			end_manual(p)
		manual_on = false
	if in_air:
		air_time += dt
		spin_acc += wrapf(p.yaw - last_yaw, -PI, PI)
		last_yaw = p.yaw
		if grab_name != "":
			grab_t += dt
			if not Input.is_action_pressed("wheelie") and grab_t > 0.15:
				_end_grab()
		if not p.is_on_floor():
			grace = GRACE
		else:
			_land(p)
	# manual (wheelie) keeps the combo alive
	if p.wheelie and not in_air:
		if not manual_on:
			manual_on = true
			if not live:
				live = true
				combo.clear()
				combo_pts = 0
		grace = GRACE
	elif manual_on and not p.wheelie:
		manual_on = false
	# trick pose
	var tp := 0.0
	var troll := 0.0
	if flip_t > 0.0:
		flip_t -= dt
		var dur := FLIP_TIME * (1.0 + (flip_turns - 1.0) * 0.6)
		var k := clampf(1.0 - flip_t / dur, 0.0, 1.0)
		var a := ease(k, -1.8) * TAU * flip_turns * flip_dir
		if flip_axis == "roll":
			troll = a
		else:
			tp = a
		if flip_t <= 0.0:
			troll = 0.0
			tp = 0.0
	if grab_name != "":
		tp += -0.45 * minf(grab_t * 6.0, 1.0)
	p.trick_roll = troll
	p.trick_pitch = tp
	if revert_t > 0.0:
		revert_t = maxf(0.0, revert_t - dt)
		p.trick_yaw = -PI * ease(revert_t / 0.28, 1.6)
	else:
		p.trick_yaw = 0.0
	# bank the combo when the link window runs out
	if live and not in_air and not manual_on:
		grace -= dt
		if grace <= 0.0:
			bank()

func _end_grab() -> void:
	var g: Array = GRABS.values().filter(func(x): return x[0] == grab_name)[0]
	add_trick(grab_name, int(g[1] + grab_t * 400))
	grab_name = ""

func end_manual(p: Chair) -> void:
	if not manual_on and not p.wheelie:
		return
	manual_on = false
	if p.wheelie_t > 0.25:
		add_trick("WHEELIE MANUAL", int(60 + p.wheelie_t * 160))

func _land(p: Chair) -> void:
	in_air = false
	# a flip that is nearly round counts; landing on your side half-way through does not
	var fdur := FLIP_TIME * (1.0 + (flip_turns - 1.0) * 0.6)
	var flipping := flip_t > fdur * 0.22
	if grab_name != "":
		_end_grab()
	var deg := absf(spin_acc) * 180.0 / PI
	var halves := int(round(deg / 180.0))
	var hv := Vector3(p.velocity.x, 0, p.velocity.z)
	var aligned := true
	var backwards := false
	if hv.length() > 1.2:
		var d := hv.normalized().dot(p.forward())
		aligned = absf(d) > cos(deg_to_rad(65))
		backwards = d < 0.0
	else:
		# slow: judge by how close the spin is to a whole half-turn
		aligned = absf(deg - halves * 180.0) < 60.0
	if flipping or not aligned:
		last_bail = "flip %.2f/%.2f aligned=%s deg=%.0f" % [flip_t, fdur, aligned, deg]
	flip_t = 0.0
	if flipping or not aligned:
		bail(p)
		return
	if was_vert:
		was_vert = false
		add_trick("VERT AIR", int(150 + air_time * 250))
		if p.forward().dot(p.qp_dir) > 0.3 and halves % 2 == 0:
			p.yaw += PI
			revert_t = 0.28
			add_trick("REVERT", 150)
	if halves >= 1:
		var side := "FS" if spin_acc > 0.0 else "BS"
		var pts: int = [0, 300, 700, 1200, 1800, 2600, 3500][mini(halves, 6)]
		add_trick("%s %d" % [side, halves * 180], pts)
	if air_time > 0.9:
		add_trick("BIG AIR %.1fs" % air_time, int(air_time * 300))
	# square the chair up with its momentum so the landing feels clean
	if hv.length() > 1.2 and (halves >= 1 or absf(spin_acc) > 0.6 or backwards):
		var vy := atan2(-hv.x, -hv.z)
		if backwards:
			# auto-revert: spin round to face forwards and keep rolling
			p.yaw = vy
			revert_t = 0.28
			add_trick("REVERT", 150)
		else:
			p.yaw = vy
	if live:
		grace = GRACE
		Sfx.play("land", 1.2, -2.0)

func bail(p: Chair, fx: bool = true) -> void:
	in_air = false
	grab_name = ""
	flip_t = 0.0
	manual_on = false
	p.trick_roll = 0.0
	p.trick_pitch = 0.0
	var lost := live_score() * mult()
	live = false
	combo.clear()
	combo_pts = 0
	special = 0.0
	special_on = false
	if not fx:
		return
	p.spin = randf_range(-0.45, 0.45)
	p.velocity *= 0.35
	w.shake(0.7)
	w.fx_dust(p.global_position, 16)
	Sfx.play("bonk")
	flash_text = BAIL_LINES.pick_random()
	if lost > 0:
		flash_text += "   (-%s)" % _fmt(lost)
	flash_col = Color("ff3d7f")
	flash_t = 1.8

func bank() -> void:
	if not live:
		return
	live = false
	var total := combo_pts * mult()
	var n := combo.size()
	combo.clear()
	combo_pts = 0
	if total <= 0:
		return
	var p: Chair = GameState.player
	var cash := maxi(1, int(total / 8.0))
	GameState.add_cred(cash, p.global_position + Vector3.UP * 2.2, "+$%d" % cash)
	best_combo = maxi(best_combo, total)
	if not special_on:
		special = minf(1.0, special + total / 6000.0)
		if special >= 1.0:
			special_on = true
			GameState.say_banner("SPECIAL!", "Flip tricks are now SPECIAL tricks", Color("ffd84a"))
			Sfx.play("steal", 0.8)
	flash_text = _fmt(total) + ("   " + ["NICE", "SWEET", "SICK!", "INSANE!!", "LEGENDARY!!!"][clampi(n - 1, 0, 4)] if n > 1 else "")
	flash_col = Color("ffd84a") if n < 4 else Color("39ff14")
	flash_t = 1.6
	if total >= 8000:
		GameState.say_banner("MEGA COMBO!", _fmt(total) + " points", Color("39ff14"))
	if n >= 3 and p.rig != null:
		p.rig.cheer()
	bank_count += 1
	Sfx.play("steal", 1.1, -3.0)
	GameState.event.emit("combo", {"total": total, "tricks": n})

static func _fmt(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ------------------------------------------------------------------ grinds
const GRIND_NAMES := {"curb": "CURB GRIND", "ledge": "LEDGE GRIND", "rail": "RAIL GRIND"}

func _try_grind(p: Chair, from_ground: bool = false) -> bool:
	var rails: Array = w.city.rails
	var pos := p.global_position
	var hv := Vector3(p.velocity.x, 0, p.velocity.z)
	var spd := hv.length()
	if spd < (1.5 if from_ground else 2.0):
		return false
	if from_ground and w.hop != null:
		return false
	var hd := hv / spd
	for r in rails:
		var a: Vector3 = r.a
		var d: Vector3 = r.d
		var dy := pos.y - a.y
		if dy < -0.3 or dy > 0.65:
			continue
		var rel := Vector3(pos.x - a.x, 0, pos.z - a.z)
		var t := rel.dot(d)
		if t < 0.3 or t > r.len - 0.3:
			continue
		var perp := rel - d * t
		if perp.length() > (1.0 if from_ground else 0.8):
			continue
		var al := hd.dot(d)
		if absf(al) < 0.55:
			continue
		_start_grind(p, r, t, signf(al), spd)
		return true
	return false

func _start_grind(p: Chair, r: Dictionary, t: float, dir: float, spd: float) -> void:
	if p.wheelie:
		end_manual(p)
		p.wheelie = false
	w.wheelie_toggled = false
	var nm: String = GRIND_NAMES.get(r.kind, "GRIND")
	if Input.is_action_pressed("wheelie"):
		nm = "CASTER " + nm
	if special_on:
		nm = "SPARK STORM " + nm
	grind = {"rail": r, "s": t, "dir": dir, "speed": maxf(spd, 3.5), "t": 0.0, "bal": 0.0, "bal_v": 0.0, "name": nm, "start": t}
	if grab_name != "":
		_end_grab()
	in_air = false
	p.grinding = true
	p.velocity = Vector3.ZERO
	if not live:
		live = true
		combo.clear()
		combo_pts = 0
	Sfx.play("land", 1.6, -2.0)
	Sfx.set_loop("grind", true)

func _grind_step(p: Chair, dt: float) -> void:
	var g := grind
	var r: Dictionary = g.rail
	g.t += dt
	g.speed = maxf(3.0, g.speed * pow(0.997, dt * 60.0) + (0.6 if Input.is_action_pressed("forward") else 0.0) * dt)
	g.s += g.dir * g.speed * dt
	# balance: drifts more the longer you grind; steer left/right to stay on (assist mode keeps you on)
	var drift := 0.0 if GameState.assist_steer or GameState.one_switch else 1.0
	g.bal_v += randf_range(-1.0, 1.0) * dt * 3.0 * drift * (1.0 + g.t * 0.25)
	g.bal_v -= Input.get_axis("left", "right") * dt * 4.0 * g.dir
	g.bal_v *= pow(0.9, dt * 60.0)
	g.bal += g.bal_v * dt
	g.bal = lerpf(g.bal, 0.0, dt * 0.4)
	var fd: Vector3 = r.d * g.dir
	p.global_position = r.a + r.d * g.s + Vector3.UP * 0.03
	p.yaw = atan2(-fd.x, -fd.z)
	p.rotation.y = p.yaw
	p.visual.transform = Transform3D(Basis(Vector3.FORWARD, g.bal * 0.45), Vector3.ZERO)
	if Engine.get_physics_frames() % 5 == 0:
		w.fx_sparks(p.global_position + Vector3.UP * 0.05)
	grace = GRACE
	if absf(g.bal) > 1.0:
		_end_grind(p, false)
		bail(p)
		return
	if g.s < 0.0 or g.s > r.len:
		_end_grind(p, false)

func grind_balance() -> float:
	return grind.bal if not grind.is_empty() else 0.0

func _end_grind(p: Chair, ollie: bool) -> void:
	var g := grind
	grind = {}
	Sfx.set_loop("grind", false)
	p.grinding = false
	p.visual.transform = Transform3D.IDENTITY
	grind_cool = 0.35
	var r: Dictionary = g.rail
	var fd: Vector3 = r.d * g.dir
	var dist: float = absf(g.s - g.start)
	grind_m += dist
	GameState.event.emit("grind", {"m": dist, "kind": r.kind})
	add_trick(g.name, int(120 + g.t * 320 + dist * 25))
	p.velocity = fd * g.speed + Vector3.UP * (Chair.HOP_V if ollie else 1.5)
	if ollie:
		# ollie off: push out to the side you steer towards (or away from the rail) so you don't re-lock
		var side := Vector3(-fd.z, 0, fd.x)
		var st := Input.get_axis("left", "right")
		p.velocity += side * (2.8 * (st if absf(st) > 0.2 else 1.0))
		grind_cool = 0.9
	p.air_t = 0.2
	in_air = true
	spin_acc = 0.0
	air_time = 0.0
	flips_this_air = 0
	last_yaw = p.yaw
	was_vert = false
	if ollie:
		Sfx.play("jump", 1.15)
