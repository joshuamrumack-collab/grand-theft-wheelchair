class_name Hud
extends CanvasLayer
## On-screen interface: minimap, wanted stars, cred, chair panel, mission, banners,
## subtitles, prompts, target arrow, title screen and the pause / accessibility menu.

var world: Node
var overlay: Control
var cred_label: Label
var chair_label: Label
var desc_label: Label
var mission_label: Label
var hint_label: Label
var banner_label: Label
var banner_sub: Label
var sub_label: Label
var sub_who: Label
var prompt_label: Label
var cam_label: Label
var pizza_label: Label
var race_label: Label
var busted_label: Label
var busted_sub: Label
var title_panel: Control
var pause_panel: Control
var shop_panel: Control
var shop_box: VBoxContainer
var shop_msg: Label
var shop_cred: Label
var banner_t: float = 0.0
var sub_t: float = 0.0
var cam_msg_t: float = 0.0
var trick_label: Label
var combo_label: Label
var flash_label: Label
var font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	# chunky, slanted, early-2000s skate-game lettering
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Impact", "Arial Black", "Franklin Gothic Heavy", "Liberation Sans Narrow", "DejaVu Sans"])
	sf.font_weight = 900
	sf.font_italic = true
	font = sf
	var th := Theme.new()
	th.default_font = sf
	var root := Control.new()
	root.theme = th
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	cred_label = _label(root, 36, Color("8cff6a"), 8)
	cred_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(cred_label, 1.0, 0.0, Vector2(-420, 12), Vector2(400, 50))
	chair_label = _label(root, 22, Color.WHITE, 6)
	chair_label.position = Vector2(20, 238)
	desc_label = _label(root, 14, Color(1, 1, 1, 0.85), 4)
	desc_label.position = Vector2(20, 268)
	mission_label = _label(root, 22, Color("ffd84a"), 6)
	_center_bottom(mission_label, 46)
	hint_label = _label(root, 15, Color.WHITE, 4)
	_center_bottom(hint_label, 82)
	hint_label.text = "WASD roll  •  SPACE hop / flip  •  steer in air = spin  •  X by a curb or rail = GRIND  •  X wheelie / grab  •  E steal / hide  •  F donut  •  P photo  •  T replay  •  ESC menu"
	banner_label = _label(root, 64, Color("ffd84a"), 12)
	_center(banner_label, -0.25, 90)
	banner_sub = _label(root, 22, Color.WHITE, 6)
	_center(banner_sub, -0.25, 160)
	sub_who = _label(root, 13, Color("ffd84a"), 4)
	_center_bottom(sub_who, 150)
	sub_label = _label(root, 19, Color.WHITE, 5)
	_center_bottom(sub_label, 128)
	prompt_label = _label(root, 17, Color.WHITE, 5)
	prompt_label.size = Vector2(600, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cam_label = _label(root, 26, Color("7ee0ff"), 6)
	_center(cam_label, -0.35, 40)
	pizza_label = _label(root, 24, Color.WHITE, 6)
	_center(pizza_label, -0.5, 20)
	race_label = _label(root, 24, Color("39ff14"), 6)
	_center(race_label, -0.5, 60)
	busted_label = _label(root, 120, Color("ff3d7f"), 16)
	_center(busted_label, 0.0, -80)
	busted_label.text = "BUSTED"
	busted_label.visible = false
	busted_sub = _label(root, 24, Color.WHITE, 6)
	_center(busted_sub, 0.0, 70)
	busted_sub.visible = false
	trick_label = _label(root, 24, Color("ffd84a"), 7)
	_center_bottom(trick_label, 210)
	trick_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor(trick_label, 0.5, 1.0, Vector2(-520, -236), Vector2(1040, 64))
	trick_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	combo_label = _label(root, 40, Color.WHITE, 9)
	_center_bottom(combo_label, 262)
	combo_label.size.y = 46
	flash_label = _label(root, 48, Color("ffd84a"), 10)
	_center_bottom(flash_label, 262)
	_build_title(root)
	_build_pause(root)
	_build_shop(root)
	GameState.banner.connect(show_banner)
	GameState.subtitle.connect(show_sub)

func _label(parent: Control, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0, 0, 0, 0.95)
	ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _anchor(c: Control, ax: float, ay: float, off: Vector2, sz: Vector2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y

func _center(l: Label, anchor_y: float, off: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anchor(l, 0.5, 0.5, Vector2(-700, off - 50 + anchor_y * 600), Vector2(1400, 100))

func _center_bottom(l: Label, from_bottom: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(l, 0.5, 1.0, Vector2(-700, -from_bottom), Vector2(1400, 30))

func _build_title(root: Control) -> void:
	title_panel = ColorRect.new()
	title_panel.color = Color(0.05, 0.02, 0.1, 0.72)
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchor(box, 0.5, 0.5, Vector2(-450, -300), Vector2(900, 600))
	title_panel.add_child(box)
	var t1 := _label(box, 80, Color.WHITE, 14)
	t1.text = "GRAND THEFT"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _label(box, 92, Color("ff4fb0"), 16)
	t2.text = "WHEELCHAIR"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t3 := _label(box, 26, Color("7ee0ff"), 6)
	t3.text = "WELCOME TO LOS SPOKOS"
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t4 := _label(box, 17, Color.WHITE, 4)
	t4.text = "\nW A S D  roll   •   SPACE  hop   •   steer in the air to SPIN   •   E  steal a chair / hide in a dumpster\nX  wheelie (ground) / grab (air)   •   SPACE in the air  flip   •   X next to a curb or rail to GRIND\nF  throw a donut at the cops   •   P  photo mode   •   T  instant replay   •   F11  fullscreen\nSHIFT turbo   •   H bell   •   R radio   •   C camera   •   N day/night   •   F3 retro look   •   ESC menu\nGamepad: triggers roll, stick steer, A hop/flip, X wheelie/grab, RB turbo, Y steal, B bell, LB donut\n"
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t5 := _label(box, 30, Color("ffd84a"), 8)
	t5.text = "PRESS ENTER (or A) TO ROLL OUT"
	t5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for spec in [["PLAY", func(): world._start()], ["SCORE ATTACK", func(): world.score.open_setup()], ["CREATE-A-RIDER", func():
			world._start()
			world.editor.open_editor()]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(240, 54)
		b.add_theme_font_size_override("font_size", 24)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)

func _build_pause(root: Control) -> void:
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0.05, 0.02, 0.1, 0.8)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var outer := VBoxContainer.new()
	_anchor(outer, 0.5, 0.5, Vector2(-380, -330), Vector2(760, 660))
	outer.add_theme_constant_override("separation", 8)
	pause_panel.add_child(outer)
	var t := _label(outer, 46, Color("ff6fb5"), 10)
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	outer.add_child(cols)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	cols.add_child(box)
	var box2 := VBoxContainer.new()
	box2.add_theme_constant_override("separation", 8)
	cols.add_child(box2)
	_button(box, "Resume", func(): world.toggle_pause())
	_button(box, "Create-a-Rider", func(): world.editor.open_editor())
	_button(box, "Score Attack (class contest)", func(): world.score.open_setup())
	_button(box, "Goals", func(): _show_goals(true))
	_button(box, "Game speed: 100%", func(): pass, "speed")
	_button(box, "Turbo: hold", func(): pass, "boost")
	_button(box, "Wheelie: hold", func(): pass, "wheelie")
	_button(box, "Save game", func(): pass, "save")
	_button(box, "Reset progress", func(): pass, "reset")
	_button(box, "Quit", func(): get_tree().quit())
	var l2 := _label(box2, 18, Color("7ee0ff"), 4)
	l2.text = "DISPLAY"
	_button(box2, "Look: Retro 2001", func(): pass, "retro")
	_button(box2, "Graphics: Medium", func(): pass, "quality")
	_button(box2, "Fullscreen: off", func(): pass, "fullscreen")
	_button(box2, "Sound: on", func(): pass, "sound")
	var l3 := _label(box2, 18, Color("7ee0ff"), 4)
	l3.text = "ACCESSIBILITY"
	_button(box2, "Steering assist: off", func(): pass, "assist")
	_button(box2, "One-switch mode: off", func(): pass, "one_switch")
	_button(box2, "HUD size: 100%", func(): pass, "hud_scale")
	_button(box2, "Colour-blind colours: off", func(): pass, "colorblind")
	_build_goals(root)
	_refresh_pause()

var goals_panel: ColorRect
var goals_text: RichTextLabel
func _build_goals(root: Control) -> void:
	goals_panel = ColorRect.new()
	goals_panel.color = Color(0.05, 0.02, 0.1, 0.93)
	goals_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	goals_panel.visible = false
	root.add_child(goals_panel)
	var box := VBoxContainer.new()
	_anchor(box, 0.5, 0.5, Vector2(-380, -320), Vector2(760, 640))
	goals_panel.add_child(box)
	var t := _label(box, 44, Color("39ff14"), 10)
	t.text = "GOALS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goals_text = RichTextLabel.new()
	goals_text.bbcode_enabled = true
	goals_text.custom_minimum_size = Vector2(760, 480)
	goals_text.add_theme_font_override("normal_font", font)
	goals_text.add_theme_font_size_override("normal_font_size", 20)
	goals_text.add_theme_font_override("bold_font", font)
	goals_text.add_theme_font_size_override("bold_font_size", 22)
	box.add_child(goals_text)
	var b := Button.new()
	b.text = "Back"
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func(): _show_goals(false))
	box.add_child(b)

func _show_goals(on: bool) -> void:
	goals_panel.visible = on
	if not on or world.goals == null:
		return
	var txt := ""
	for g in world.goals.GOALS:
		var done: bool = world.goals.done(g.id)
		var prog: String = world.goals.progress_text(g)
		txt += "%s  [b]%s[/b]   [color=#ffd84a]$%d[/color]  %s\n      [color=#aaaaaa]%s[/color]\n" % ["[color=#39ff14]✔[/color]" if done else "[color=#666666]○[/color]", g.title, g.cred, ("[color=#39ff14]" + prog + "[/color]") if done else prog, g.hint]
	txt += "\n[color=#7ee0ff]%d of %d goals complete[/color]" % [world.goals.count(), world.goals.GOALS.size()]
	goals_text.text = txt

var _buttons: Dictionary = {}
func _button(parent: Control, text: String, cb: Callable, key: String = "") -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(372, 44)
	b.add_theme_font_size_override("font_size", 20)
	if key != "":
		_buttons[key] = b
		b.pressed.connect(func(): _pause_action(key))
	else:
		b.pressed.connect(cb)
	parent.add_child(b)

func _pause_action(key: String) -> void:
	match key:
		"speed":
			var speeds := [1.0, 0.75, 0.5]
			var i := speeds.find(GameState.game_speed)
			GameState.game_speed = speeds[(i + 1) % speeds.size()]
		"boost": GameState.settings_toggle_boost = not GameState.settings_toggle_boost
		"wheelie": GameState.settings_toggle_wheelie = not GameState.settings_toggle_wheelie
		"quality": world.cycle_quality()
		"fullscreen": world.toggle_fullscreen()
		"assist": GameState.assist_steer = not GameState.assist_steer
		"one_switch": GameState.one_switch = not GameState.one_switch
		"hud_scale":
			var sc := [1.0, 1.25, 1.5]
			GameState.hud_scale = sc[(sc.find(GameState.hud_scale) + 1) % sc.size()]
			world.apply_access()
		"colorblind":
			GameState.colorblind = not GameState.colorblind
			world.apply_access()
		"retro": world.toggle_retro()
		"sound": Sfx.muted = not Sfx.muted
		"save":
			GameState.save_game()
			_buttons["save"].text = "Saved!"
			return
		"reset":
			GameState.reset_save()
			world.restyle()
			_buttons["reset"].text = "Progress reset"
			return
	if key in ["speed", "boost", "wheelie", "assist", "one_switch", "hud_scale", "colorblind"]:
		GameState.save_game()
	_refresh_pause()

func _refresh_pause() -> void:
	if _buttons.is_empty():
		return
	_buttons["speed"].text = "Game speed: %d%%" % int(GameState.game_speed * 100)
	_buttons["boost"].text = "Turbo: " + ("toggle (tap SHIFT)" if GameState.settings_toggle_boost else "hold SHIFT")
	_buttons["wheelie"].text = "Wheelie: " + ("toggle (tap X)" if GameState.settings_toggle_wheelie else "hold X")
	_buttons["retro"].text = "Look: " + ("Retro 2001 (F3)" if GameState.retro else "Modern (F3)")
	_buttons["quality"].text = "Graphics: " + GameState.QUALITY_NAMES[GameState.quality] + (" (Modern only)" if GameState.retro else "")
	_buttons["fullscreen"].text = "Fullscreen: " + ("on" if GameState.fullscreen else "off") + "  (F11)"
	_buttons["assist"].text = "Steering assist: " + ("ON" if GameState.assist_steer else "off")
	_buttons["one_switch"].text = "One-switch mode: " + ("ON (SPACE only)" if GameState.one_switch else "off")
	_buttons["hud_scale"].text = "HUD size: %d%%" % int(GameState.hud_scale * 100)
	_buttons["colorblind"].text = "Colour-blind colours: " + ("ON" if GameState.colorblind else "off")
	_buttons["sound"].text = "Sound: " + ("off" if Sfx.muted else "on")
	_buttons["save"].text = "Save game"
	_buttons["reset"].text = "Reset progress"

func set_paused(p: bool) -> void:
	pause_panel.visible = p
	_refresh_pause()
	if p and _buttons.size() > 0:
		_buttons["speed"].get_parent().get_child(1).grab_focus()

func _build_shop(root: Control) -> void:
	shop_panel = ColorRect.new()
	shop_panel.color = Color(0.1, 0.0, 0.12, 0.75)
	shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.visible = false
	root.add_child(shop_panel)
	shop_box = VBoxContainer.new()
	_anchor(shop_box, 0.5, 0.5, Vector2(-280, -380), Vector2(560, 760))
	shop_box.add_theme_constant_override("separation", 6)
	shop_panel.add_child(shop_box)

func open_shop() -> void:
	shop_panel.visible = true
	_refresh_shop("Your style follows you into every chair you steal. New paint makes the cops forget your face!")

func close_shop() -> void:
	shop_panel.visible = false

func _refresh_shop(msg: String) -> void:
	for c in shop_box.get_children():
		c.queue_free()
	var t := _label(shop_box, 48, Color("ff6fb5"), 10)
	t.text = "PIMP MY CHAIR"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_cred = _label(shop_box, 26, Color("8cff6a"), 6)
	shop_cred.text = "$%d" % GameState.cred
	shop_cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var first: Button = null
	for item in GameState.SHOP:
		var b := Button.new()
		b.custom_minimum_size = Vector2(560, 44)
		b.add_theme_font_size_override("font_size", 19)
		var st: Dictionary = GameState.style
		var active: bool = (st.paint == item.id) if item.kind == "paint" else ((st.neon != "") if item.kind == "neon" else st[item.id])
		var tag: String = ("ON" if active else "off") if GameState.owned.has(item.id) else "$%d" % item.price
		b.text = "%s   [%s]" % [item.label, tag]
		var it: Dictionary = item
		b.pressed.connect(func(): _refresh_shop(world.shop_buy(it)))
		shop_box.add_child(b)
		if first == null:
			first = b
	shop_msg = _label(shop_box, 16, Color("ffd84a"), 4)
	shop_msg.text = msg
	shop_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	shop_msg.custom_minimum_size = Vector2(560, 44)
	var close := Button.new()
	close.text = "ROLL OUT  (Esc)"
	close.custom_minimum_size = Vector2(560, 52)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func(): world.close_shop())
	shop_box.add_child(close)
	first.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if goals_panel.visible and event.is_action_pressed("pause"):
		_show_goals(false)
		get_viewport().set_input_as_handled()
		return
	if world != null and (world.photo.active or world.photo.replaying or world.editor.open or world.score.setup_panel.visible):
		return
	if shop_panel.visible and event.is_action_pressed("pause"):
		world.close_shop()
		get_viewport().set_input_as_handled()
		return
	if world != null and event.is_action_pressed("pause") and world.state in ["play", "busted"]:
		world.toggle_pause()
		get_viewport().set_input_as_handled()

func show_banner(title: String, sub: String, color: Color) -> void:
	banner_label.text = title
	banner_label.label_settings.font_color = color
	banner_sub.text = sub
	banner_t = 3.2

func show_sub(who: String, text: String, color: Color) -> void:
	sub_who.text = who
	sub_who.label_settings.font_color = color
	sub_label.text = text
	sub_t = 5.0

func show_cam(cam_name: String) -> void:
	cam_label.text = cam_name
	cam_msg_t = 1.5

func _process(dt: float) -> void:
	if world == null:
		return
	var playing: bool = world.state != "title"
	title_panel.visible = world.state == "title"
	for n in [cred_label, chair_label, desc_label, mission_label, overlay]:
		n.visible = playing
	hint_label.visible = playing and world.play_time < 16.0
	cred_label.text = "$%08d" % GameState.cred
	var p: Chair = GameState.player
	if p != null:
		var t: Dictionary = p.stats
		chair_label.text = t["name"]
		chair_label.label_settings.font_color = Color("ffd84a") if p.type == "gold" else Color.WHITE
		desc_label.text = t["desc"]
	mission_label.text = world.mission_text()
	banner_t -= dt
	var ba := clampf(min(banner_t * 2.0, (3.2 - banner_t) * 5.0), 0.0, 1.0)
	banner_label.modulate.a = ba
	banner_sub.modulate.a = ba
	sub_t -= dt
	var sa := clampf(min(sub_t * 2.0, 1.0), 0.0, 1.0)
	sub_label.modulate.a = sa
	sub_who.modulate.a = sa
	cam_msg_t -= dt
	cam_label.modulate.a = clampf(cam_msg_t * 2.0, 0.0, 1.0)
	busted_label.visible = world.state == "busted"
	busted_sub.visible = world.state == "busted"
	busted_sub.text = "\"" + world.bust_line + "\""
	race_label.text = world.acts.race_text() if world.acts != null else ""
	# pizza timer
	if world.pizza.is_empty():
		pizza_label.text = ""
	else:
		var tl: float = max(0.0, world.pizza.t)
		pizza_label.text = "PIZZA  %d:%02d   •   %d%% intact" % [floori(tl / 60.0), int(tl) % 60, int(world.pizza.integ)]
		pizza_label.label_settings.font_color = Color("ff5c8a") if tl < 10.0 and int(world.play_time * 4) % 2 == 0 else Color.WHITE
	# steal prompt
	var pr = world.prompt
	if pr != null and world.state == "play":
		var cam: Camera3D = world.rig.cam
		var wp: Vector3 = pr.global_position + Vector3.UP * 0.2
		if not cam.is_position_behind(wp):
			var sp := cam.unproject_position(wp)
			prompt_label.visible = true
			prompt_label.text = "[E] Steal " + pr.stats["name"] + (" (occupied!)" if pr.rider != null else "")
			prompt_label.label_settings.font_color = Color("ff8fb5") if pr.rider != null else Color.WHITE
			prompt_label.position = sp + Vector2(-300, 26)
		else:
			prompt_label.visible = false
	else:
		prompt_label.visible = false
	_tricks_hud(playing)
	overlay.queue_redraw()

func _tricks_hud(playing: bool) -> void:
	var trk = world.tricks
	if trk == null or not playing:
		trick_label.visible = false
		combo_label.visible = false
		flash_label.visible = false
		return
	var txt: String = trk.combo_text()
	var showing: bool = trk.live or txt != ""
	trick_label.visible = showing
	combo_label.visible = showing
	trick_label.text = txt
	var sc: int = trk.live_score()
	combo_label.text = (trk._fmt(sc) + "  X  " + str(trk.mult())) if sc > 0 else ""
	var wob := 1.0 + sin(GameState.time * 18.0) * 0.03
	combo_label.scale = Vector2(wob, wob)
	combo_label.pivot_offset = combo_label.size / 2
	flash_label.visible = trk.flash_t > 0.0 and not showing
	if flash_label.visible:
		flash_label.text = trk.flash_text
		flash_label.label_settings.font_color = trk.flash_col
		flash_label.modulate.a = clampf(trk.flash_t * 2.0, 0.0, 1.0)
		var k: float = 1.0 + maxf(0.0, trk.flash_t - 1.3) * 1.2
		flash_label.pivot_offset = flash_label.size / 2
		flash_label.scale = Vector2(k, k)

class Overlay extends Control:
	var hud: Hud
	func _star(c: Vector2, r1: float, r2: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + i * PI / 5
			var r := r1 if i % 2 == 0 else r2
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var w = hud.world
		if w == null or w.state == "title":
			return
		var vs := get_viewport_rect().size
		var p: Chair = GameState.player
		# wanted stars
		for i in 5:
			var c := Vector2(vs.x - 36 - i * 40, 84)
			var on := i < GameState.wanted
			var flash := on and GameState.wanted_cool > 4.0 and int(GameState.time * 5) % 2 == 0
			var pts := _star(c, 16, 7)
			draw_colored_polygon(pts, (Color.WHITE if flash else Color("ffd84a")) if on else Color(1, 1, 1, 0.15))
			pts.append(pts[0])
			draw_polyline(pts, Color.BLACK, 2.5)
		# SPECIAL meter (bottom centre, above the trick string)
		var trk = w.tricks
		if trk != null:
			var mw := 320.0
			var mx := vs.x / 2 - mw / 2
			var my := vs.y - 168.0
			draw_rect(Rect2(mx - 3, my - 3, mw + 6, 16), Color(0, 0, 0, 0.7))
			var sp: float = trk.special
			var col := Color("ffd84a")
			if trk.special_on:
				col = Color.from_hsv(fmod(GameState.time * 1.5, 1.0), 0.8, 1.0)
			elif sp > 0.75:
				col = Color("ff8a1f")
			draw_rect(Rect2(mx, my, mw * sp, 10), col)
			draw_rect(Rect2(mx, my, mw * sp, 3), Color(1, 1, 1, 0.45))
			if trk.special_on:
				draw_string(hud.font, Vector2(mx + mw + 10, my + 11), "SPECIAL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		# Ramp Revolution meter
		draw_string(hud.font, Vector2(vs.x - 236, 124), "RAMP REVOLUTION %d%%" % GameState.revolution, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b388ff"))
		draw_rect(Rect2(vs.x - 236, 130, 220, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(vs.x - 236, 130, 220 * GameState.revolution / 100.0, 8), Color("b388ff"))
		# minimap
		var mr := Rect2(16, 16, 200, 200)
		draw_rect(mr.grow(4), Color.BLACK)
		draw_rect(mr, Color("1f2126"))
		if p == null:
			return
		var ctr := mr.get_center()
		var sc := 0.85
		var yaw: float = w.rig.cam_yaw
		var pp := Vector2(p.global_position.x, p.global_position.z)
		draw_set_transform(ctr, yaw, Vector2(sc, sc))
		var city: City = w.city
		for bl in city.blocks:
			var r := Rect2(Vector2(bl.x0, bl.z0) - pp, Vector2(City.BLOCK, City.BLOCK))
			if abs(r.get_center().x) > 220 or abs(r.get_center().y) > 220:
				continue
			draw_rect(r, Color("8c877d"))
			var col := Color("6f6a62")
			match bl.type:
				"park": col = Color("4f9a43")
				"hospital": col = Color("dfe6ea")
				"police": col = Color("4a6aa8")
				"chop": col = Color("a8683f")
			draw_rect(r.grow(-City.WALK), col)
		for b in city.buildings:
			var r: Rect2 = b.rect
			r.position -= pp
			if abs(r.get_center().x) > 220 or abs(r.get_center().y) > 220:
				continue
			draw_rect(r, b.color.darkened(0.15))
		for c in w.chairs:
			if c != p and c.mode == "cop" and c.chase:
				var cp := Vector2(c.global_position.x, c.global_position.z) - pp
				draw_circle(cp, 4.5, Color("ff3b3b") if int(GameState.time * 6) % 2 == 0 else Color("4f8bff"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# icons clamped to the map edge
		for icon in w.map_icons():
			var rel: Vector2 = (Vector2(icon.pos.x, icon.pos.z) - pp).rotated(yaw) * sc
			var lim := 92.0
			if abs(rel.x) > lim or abs(rel.y) > lim:
				rel *= lim / max(abs(rel.x), abs(rel.y))
			var ip := ctr + rel
			draw_circle(ip, 8, Color.BLACK)
			draw_circle(ip, 6.5, GameState.cb(icon.color))
			draw_string(hud.font, ip + Vector2(-4, 4), icon.letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
		var arrow := PackedVector2Array([ctr + Vector2(0, -9), ctr + Vector2(6, 7), ctr + Vector2(0, 3), ctr + Vector2(-6, 7)])
		var pr := (p.yaw - yaw)
		var rot := PackedVector2Array()
		for a in arrow:
			rot.append(ctr + (a - ctr).rotated(-pr))
		draw_colored_polygon(rot, Color.WHITE)
		# chair panel bars
		var y0 := 296.0
		draw_rect(Rect2(10, 228, 260, 162), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(20, y0, 160, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(20, y0, 160 * clampf(p.speed() / 14.0, 0, 1), 8), Color("8cff6a"))
		draw_rect(Rect2(20, y0 + 14, 160, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(20, y0 + 14, 160 * p.boost_meter, 8), Color("ff9b2b"))
		draw_string(hud.font, Vector2(188, y0 + 8), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(hud.font, Vector2(188, y0 + 22), "TURBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(hud.font, Vector2(20, y0 + 42), "CHAIRDEX %d/%d" % [GameState.dex.size(), GameState.DEX_ORDER.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		if w.goals != null:
			draw_string(hud.font, Vector2(20, y0 + 84), "GOALS %d/%d   •   DONUTS x%d" % [w.goals.count(), w.goals.GOALS.size(), GameState.donuts], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8cff6a"))
		# grind balance meter
		var trk2 = w.tricks
		if trk2 != null and not trk2.grind.is_empty():
			var bw := 260.0
			var bx := vs.x / 2 - bw / 2
			var by := vs.y / 2 + 70
			draw_rect(Rect2(bx - 2, by - 2, bw + 4, 16), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bx + bw * 0.3, by, bw * 0.4, 12), Color(0.2, 0.8, 0.3, 0.5))
			var bal: float = clampf(trk2.grind_balance(), -1.0, 1.0)
			var mx2 := bx + bw / 2 + bal * bw / 2
			draw_rect(Rect2(mx2 - 4, by - 6, 8, 24), Color("ffd84a") if absf(bal) < 0.6 else Color("ff3d7f"))
			draw_string(hud.font, Vector2(bx, by - 8), "BALANCE  (left / right)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		for i in GameState.DEX_ORDER.size():
			var k: String = GameState.DEX_ORDER[i]
			var cc := Vector2(28 + i * 22, y0 + 58)
			draw_circle(cc, 8.5, Color.BLACK)
			draw_circle(cc, 7, GameState.TYPES[k].color if GameState.dex.has(k) else Color(1, 1, 1, 0.12))
		# target arrow at screen edge
		var tg = w.mission_target()
		if tg != null:
			var cam: Camera3D = w.rig.cam
			var tp: Vector3 = tg + Vector3.UP
			var on_screen := not cam.is_position_behind(tp) and Rect2(Vector2.ZERO, vs).has_point(cam.unproject_position(tp))
			if not on_screen:
				var d := Vector2(tg.x - p.global_position.x, tg.z - p.global_position.z)
				var a := d.rotated(yaw).angle()
				var ep := vs / 2 + Vector2(cos(a), sin(a)) * Vector2(vs.x / 2 - 70, vs.y / 2 - 70)
				var tri := PackedVector2Array([ep + Vector2(22, 0).rotated(a), ep + Vector2(-11, -14).rotated(a), ep + Vector2(-5, 0).rotated(a), ep + Vector2(-11, 14).rotated(a)])
				draw_colored_polygon(tri, Color("ffd84a"))
				tri.append(tri[0])
				draw_polyline(tri, Color.BLACK, 3)
				draw_string(hud.font, ep - Vector2(cos(a), sin(a)) * 36 - Vector2(18, -5), "%dm" % int(d.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		# bust ring
		if GameState.bust_t > 0.05 and w.state == "play":
			var cam: Camera3D = w.rig.cam
			var sp := cam.unproject_position(p.global_position)
			draw_arc(sp, 40, -PI / 2, -PI / 2 + TAU * clampf(GameState.bust_t / 1.2, 0, 1), 32, Color("ff3355"), 6)
