extends Node
## CREATE-A-RIDER: pick hair, hat, face, shirt print, shades and colours for your character.
## The camera swings round to the front of your chair and every change shows up straight away.
## Your own shirt prints: drop PNG files into custom/prints/ (see custom.gd) and they appear in the list.

var w
var layer: CanvasLayer
var panel: Control
var rows: Dictionary = {}
var cam: Camera3D
var orbit: float = 0.0
var open: bool = false
var font: Font

const HAIRS := [["HairSpiky", "Spiky"], ["HairShort", "Short"], ["HairLong", "Ponytail"], ["HairAfro", "Afro"], ["HairMohawk", "Mohawk"]]
const HATS := [["", "None"], ["Cap", "Cap"], ["CapBack", "Cap (backwards)"], ["Beanie", "Beanie"], ["Headphones", "Headphones"], ["Crown", "Crown"]]
const FACES := [[0, "Big grin"], [1, "Smirk"], [2, "Determined"], [3, "Huge smile"]]
const SKINS := ["ffdbac", "f6d0b1", "e8b48a", "c68642", "8d5524", "5c3a21"]
const SHIRTS := ["3c8d2f", "e63946", "f4a261", "2a9d8f", "e9c46a", "8338ec", "ff006e", "3a86ff", "06d6a0", "ffbe0b", "fb5607", "111111", "f1f1f1"]
const PANTS := ["2b3a55", "3d3d3d", "5a4632", "24476b", "6b705c", "8a1c2b", "c9b38f", "111111"]
const HAIR_COLS := ["2b1d0e", "6b4423", "d4a373", "111111", "b5651d", "e5e5e5", "ff6fb5", "33aadd", "7a1fa2", "39ff14"]

func setup(world) -> void:
	w = world
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = w.hud.font
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	cam = Camera3D.new()
	cam.fov = 40.0
	w.add_child.call_deferred(cam)
	var th := Theme.new()
	th.default_font = font
	panel = PanelContainer.new()
	panel.theme = th
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 30
	panel.offset_right = 470
	panel.offset_top = -300
	panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.1, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CREATE-A-RIDER"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("ff4fb0"))
	box.add_child(title)
	for key in ["hair", "hat", "face", "print", "shades", "skin", "shirt", "pants", "hair_color"]:
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = {"hair": "Hair", "hat": "Hat", "face": "Face", "print": "Shirt print", "shades": "Shades", "skin": "Skin",
			"shirt": "Shirt colour", "pants": "Trousers", "hair_color": "Hair colour"}[key]
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.add_theme_font_size_override("font_size", 20)
		row.add_child(name_l)
		var prev := Button.new()
		prev.text = " < "
		prev.add_theme_font_size_override("font_size", 22)
		prev.pressed.connect(func(): _step(key, -1))
		row.add_child(prev)
		var val := Label.new()
		val.custom_minimum_size = Vector2(170, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 20)
		row.add_child(val)
		var nxt := Button.new()
		nxt.text = " > "
		nxt.add_theme_font_size_override("font_size", 22)
		nxt.pressed.connect(func(): _step(key, 1))
		row.add_child(nxt)
		box.add_child(row)
		rows[key] = val
	var tip := Label.new()
	tip.text = "Your own prints: put PNGs in the custom/prints folder"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(tip)
	var rnd := Button.new()
	rnd.text = "Randomise!"
	rnd.add_theme_font_size_override("font_size", 22)
	rnd.pressed.connect(_randomise)
	box.add_child(rnd)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(0, 50)
	done.add_theme_font_size_override("font_size", 26)
	done.pressed.connect(close)
	box.add_child(done)

func _options(key: String) -> Array:
	match key:
		"hair": return HAIRS
		"hat": return HATS
		"face": return FACES
		"print":
			var out := [[-1, "None"], [0, "GTW logo"], [1, "Flaming wheel"], [2, "RAMP OR DIE"], [3, "Lightning star"]]
			var custom: Array = preload("res://scripts/custom.gd").load_art("prints")
			for i in custom.size():
				out.append([100 + i, custom[i].name])
			return out
		"shades": return [[true, "On"], [false, "Off"]]
		"skin": return SKINS.map(func(c): return [c, "■"])
		"shirt": return SHIRTS.map(func(c): return [c, "■"])
		"pants": return PANTS.map(func(c): return [c, "■"])
		"hair_color": return HAIR_COLS.map(func(c): return [c, "■"])
	return []

func _step(key: String, d: int) -> void:
	var opts := _options(key)
	var cur = GameState.look.get(key)
	var idx := 0
	for i in opts.size():
		if opts[i][0] == cur:
			idx = i
	idx = (idx + d + opts.size()) % opts.size()
	GameState.look[key] = opts[idx][0]
	Sfx.play("squeak", 1.0 + idx * 0.05, -6.0)
	_apply()

func _randomise() -> void:
	for key in rows.keys():
		var opts := _options(key)
		GameState.look[key] = opts[randi() % opts.size()][0]
	_apply()

func _apply() -> void:
	w.rebuild_player_rider()
	_refresh()

func _refresh() -> void:
	for key in rows.keys():
		var opts := _options(key)
		var cur = GameState.look.get(key)
		var lbl: Label = rows[key]
		lbl.text = "?"
		lbl.remove_theme_color_override("font_color")
		for o in opts:
			if o[0] == cur:
				lbl.text = o[1]
				if o[1] == "■":
					lbl.text = "■■■■"
					lbl.add_theme_color_override("font_color", Color(cur))

func open_editor() -> void:
	if w.hop != null:
		return
	open = true
	get_tree().paused = true
	w.hud.set_paused(false)
	panel.visible = true
	w.hud.visible = false
	cam.current = true
	orbit = 0.0
	_refresh()

func close() -> void:
	open = false
	panel.visible = false
	w.hud.visible = true
	w.rig.cam.current = true
	get_tree().paused = false
	GameState.save_game()

func _unhandled_input(event: InputEvent) -> void:
	if open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not open:
		return
	var p: Chair = GameState.player
	orbit += dt * 0.35
	var a := sin(orbit) * 0.6
	var f := p.forward()
	var r := Vector3(cos(p.yaw), 0, -sin(p.yaw))
	var target := p.global_position + Vector3.UP * 0.95
	cam.global_position = target + (f * cos(a) + r * sin(a)) * 2.6 + Vector3.UP * 0.3 - r * 0.6
	cam.look_at(target - r * 0.45, Vector3.UP)
