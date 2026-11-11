extends Node
## SCORE ATTACK: pass-the-controller trick contest for the classroom.
## Up to 8 players take turns. Each turn starts at the skate plaza with a countdown, then you have
## 1-3 minutes to bank as many trick points as you can (no police). The class high-score table is
## saved per class name in user://scores.json.

const SAVE := "user://scores.json"
const COLORS := [Color("ffd84a"), Color("ff4fb0"), Color("7ee0ff"), Color("8cff6a"), Color("ff8a1f"), Color("b388ff"), Color("ffffff"), Color("ff5c5c")]

var w
var active: bool = false
var class_name_str: String = ""
var players: Array = []          # names
var scores: Array = []           # ints
var turn: int = 0
var run_len: float = 120.0
var t: float = 0.0
var phase: String = ""           # countdown, run, done
var layer: CanvasLayer
var setup_panel: Control
var result_panel: Control
var hud_label: Label
var big_label: Label
var class_edit: LineEdit
var count_spin: SpinBox
var len_opt: OptionButton
var name_edits: Array = []
var names_box: VBoxContainer
var result_text: RichTextLabel
var font: Font

func setup(world) -> void:
	w = world
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.event.connect(_on_event)
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	font = w.hud.font
	var th := Theme.new()
	th.default_font = font
	var root := Control.new()
	root.theme = th
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	hud_label = _lbl(root, 30, Color.WHITE)
	hud_label.anchor_left = 0.5
	hud_label.anchor_right = 0.5
	hud_label.offset_left = -400
	hud_label.offset_right = 400
	hud_label.offset_top = 14
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label = _lbl(root, 96, Color("ffd84a"))
	big_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_setup(root)
	_build_results(root)

func _lbl(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = maxi(4, floori(size / 6.0))
	ls.outline_color = Color.BLACK
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _panel(root: Control) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.1, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.visible = false
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -330
	box.offset_bottom = 330
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	return box

func _build_setup(root: Control) -> void:
	var box := _panel(root)
	setup_panel = box.get_parent()
	var t1 := _lbl(box, 52, Color("ff4fb0"))
	t1.text = "SCORE ATTACK"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _lbl(box, 16, Color.WHITE)
	t2.text = "Pass the controller! Each player gets one run at the skate plaza.\nBank combos for points. Highest score wins."
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	box.add_child(row)
	var l1 := _lbl(row, 20, Color.WHITE)
	l1.text = "Class: "
	class_edit = LineEdit.new()
	class_edit.placeholder_text = "e.g. 7B"
	class_edit.custom_minimum_size = Vector2(200, 40)
	row.add_child(class_edit)
	var l2 := _lbl(row, 20, Color.WHITE)
	l2.text = "   Players: "
	count_spin = SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 8
	count_spin.value = 2
	count_spin.value_changed.connect(func(_v): _refresh_names())
	row.add_child(count_spin)
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	var l3 := _lbl(row2, 20, Color.WHITE)
	l3.text = "Run length: "
	len_opt = OptionButton.new()
	for x in ["1 minute", "2 minutes", "3 minutes"]:
		len_opt.add_item(x)
	len_opt.selected = 1
	row2.add_child(len_opt)
	names_box = VBoxContainer.new()
	box.add_child(names_box)
	_refresh_names()
	var go := Button.new()
	go.text = "START!"
	go.custom_minimum_size = Vector2(0, 54)
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(_begin)
	box.add_child(go)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close_setup)
	box.add_child(back)

func _refresh_names() -> void:
	var n := int(count_spin.value)
	while name_edits.size() < n:
		var e := LineEdit.new()
		e.placeholder_text = "Player %d" % (name_edits.size() + 1)
		e.custom_minimum_size = Vector2(0, 36)
		names_box.add_child(e)
		name_edits.append(e)
	for i in name_edits.size():
		name_edits[i].visible = i < n

func _build_results(root: Control) -> void:
	var box := _panel(root)
	result_panel = box.get_parent()
	result_text = RichTextLabel.new()
	result_text.bbcode_enabled = true
	result_text.fit_content = true
	result_text.custom_minimum_size = Vector2(600, 520)
	result_text.add_theme_font_override("normal_font", font)
	result_text.add_theme_font_override("bold_font", font)
	result_text.add_theme_font_size_override("normal_font_size", 22)
	result_text.add_theme_font_size_override("bold_font_size", 30)
	box.add_child(result_text)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(0, 48)
	again.pressed.connect(func():
		result_panel.visible = false
		open_setup())
	box.add_child(again)
	var done_b := Button.new()
	done_b.text = "Back to free roam"
	done_b.custom_minimum_size = Vector2(0, 48)
	done_b.pressed.connect(func():
		result_panel.visible = false
		get_tree().paused = false)
	box.add_child(done_b)

func open_setup() -> void:
	get_tree().paused = true
	w.hud.set_paused(false)
	setup_panel.visible = true
	class_edit.grab_focus()

func close_setup() -> void:
	setup_panel.visible = false
	get_tree().paused = false

func _begin() -> void:
	setup_panel.visible = false
	class_name_str = class_edit.text.strip_edges()
	if class_name_str == "":
		class_name_str = "Class"
	players.clear()
	scores.clear()
	for i in int(count_spin.value):
		var nm: String = name_edits[i].text.strip_edges()
		players.append(nm if nm != "" else "Player %d" % (i + 1))
		scores.append(0)
	run_len = [60.0, 120.0, 180.0][len_opt.selected]
	turn = 0
	active = true
	if w.state == "title":
		w._start()
	get_tree().paused = false
	_start_turn()

func _start_turn() -> void:
	var p: Chair = GameState.player
	var spot: Vector3 = w.city.points.get("skate", p.global_position)
	if w.fun.hidden:
		w.fun.toggle_hide()
	p.global_position = spot + Vector3(0, 0.3, 4)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.rotation.y = 0.0
	w.rig.snap()
	GameState.wanted = 0
	w.tricks.bank()
	phase = "countdown"
	t = 3.5
	p.frozen = true

func _on_event(ev: String, data: Dictionary) -> void:
	if active and phase == "run" and ev == "combo":
		scores[turn] += int(data.total)

func _process(dt: float) -> void:
	if not active:
		hud_label.visible = false
		big_label.visible = false
		return
	if get_tree().paused:
		return
	hud_label.visible = true
	var p: Chair = GameState.player
	match phase:
		"countdown":
			t -= dt
			big_label.visible = true
			big_label.text = "%s\n%s" % [players[turn].to_upper(), "GET READY!" if t > 3.0 else str(int(ceil(t)))]
			big_label.label_settings.font_color = COLORS[turn % COLORS.size()]
			hud_label.text = "SCORE ATTACK  •  %s  •  turn %d of %d" % [class_name_str, turn + 1, players.size()]
			if t <= 0.0:
				phase = "run"
				t = run_len
				p.frozen = false
				big_label.text = "GO!"
				Sfx.play("big")
		"run":
			t -= dt
			if t < run_len - 0.8:
				big_label.visible = false
			var live: int = w.tricks.live_score() * w.tricks.mult() if w.tricks.live else 0
			hud_label.text = "%s   %s   %d:%02d" % [players[turn].to_upper(), w.tricks._fmt(scores[turn]) + ("  (+%s)" % w.tricks._fmt(live) if live > 0 else ""), floori(t / 60.0), int(t) % 60]
			hud_label.label_settings.font_color = Color("ff5c8a") if t < 10.0 else Color.WHITE
			if t <= 0.0:
				w.tricks.bank()
				phase = "done"
				t = 3.0
				p.frozen = true
				big_label.visible = true
				big_label.text = "TIME!\n%s" % w.tricks._fmt(scores[turn])
				Sfx.play("goal")
		"done":
			t -= dt
			if t <= 0.0:
				turn += 1
				if turn >= players.size():
					_finish()
				else:
					_start_turn()

func _finish() -> void:
	active = false
	phase = ""
	GameState.player.frozen = false
	big_label.visible = false
	hud_label.visible = false
	var order: Array = []
	for i in players.size():
		order.append([scores[i], players[i]])
	order.sort_custom(func(a, b): return a[0] > b[0])
	var table := _save(order)
	var txt := "[center][b][color=#ff4fb0]RESULTS[/color][/b]\n"
	for i in order.size():
		var medal: String = ["[color=#ffd84a]1st[/color]", "[color=#d0d6dc]2nd[/color]", "[color=#cd7f32]3rd[/color]"][i] if i < 3 else "%dth" % (i + 1)
		txt += "%s  %s  —  %s\n" % [medal, order[i][1], w.tricks._fmt(order[i][0])]
	txt += "\n[b][color=#7ee0ff]%s ALL-TIME TOP 10[/color][/b]\n" % class_name_str.to_upper()
	for i in table.size():
		txt += "%d. %s  —  %s   [color=#888888]%s[/color]\n" % [i + 1, table[i].name, w.tricks._fmt(int(table[i].score)), table[i].date]
	txt += "[/center]"
	result_text.text = txt
	result_panel.visible = true
	get_tree().paused = true
	w.fx_confetti(GameState.player.global_position, 150)

func _save(order: Array) -> Array:
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE):
		var f := FileAccess.open(SAVE, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			data = d
	var key := class_name_str.to_lower()
	var table: Array = data.get(key, [])
	var date := Time.get_date_string_from_system()
	for o in order:
		table.append({"name": o[1], "score": o[0], "date": date})
	table.sort_custom(func(a, b): return int(a.score) > int(b.score))
	table = table.slice(0, 10)
	data[key] = table
	var fw := FileAccess.open(SAVE, FileAccess.WRITE)
	if fw != null:
		fw.store_string(JSON.stringify(data, "  "))
	return table
