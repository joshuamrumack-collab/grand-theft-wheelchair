extends RefCounted
## Student-made art. Drop PNG files into these folders and the game picks them up on the next start:
##   custom/prints/     shirt prints for Create-a-Rider (square PNG, transparent background works best)
##   custom/graffiti/   graffiti tags sprayed on the city walls (any size PNG, transparent background)
## The folder can live next to the project (when running from Godot), next to the exported .exe,
## or in the user data folder (Godot menu: Project > Open User Data Folder).

static var _cache: Dictionary = {}

static func folders(kind: String) -> PackedStringArray:
	var out := PackedStringArray()
	if OS.has_feature("editor"):
		out.append(ProjectSettings.globalize_path("res://custom/" + kind))
	out.append(OS.get_executable_path().get_base_dir().path_join("custom/" + kind))
	out.append(OS.get_user_data_dir().path_join("custom/" + kind))
	return out

static func ensure_folders() -> void:
	for kind in ["prints", "graffiti", "sounds"]:
		var d: String = folders(kind)[-1]
		DirAccess.make_dir_recursive_absolute(d)
		var readme := d.path_join("README.txt")
		if not FileAccess.file_exists(readme):
			var f := FileAccess.open(readme, FileAccess.WRITE)
			if f != null:
				if kind == "sounds":
					f.store_string("Put recorded sounds here as .wav or .ogg to replace the game's synth sounds.\nName them after the sound: land, jump, bonk, crash, bell, honk, squeak, steal, grind, roll, pickup, goal, nom, throw, shutter.\n")
				else:
					f.store_string("Put your own %s here as .png files. They show up in Grand Theft Wheelchair next time you start it.\n" % kind)

## Returns [{name, tex}] for every PNG found (cached).
static func load_art(kind: String) -> Array:
	if _cache.has(kind):
		return _cache[kind]
	var out: Array = []
	var seen := {}
	for dir_path in folders(kind):
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if not f.to_lower().ends_with(".png") or seen.has(f):
				continue
			var img := Image.load_from_file(dir_path.path_join(f))
			if img == null or img.is_empty():
				continue
			if img.get_width() > 1024 or img.get_height() > 1024:
				img.resize(mini(img.get_width(), 1024), mini(img.get_height(), 1024))
			img.generate_mipmaps()
			seen[f] = true
			out.append({"name": f.get_basename().replace("_", " ").to_upper(), "tex": ImageTexture.create_from_image(img), "aspect": float(img.get_width()) / maxf(1.0, img.get_height())})
	_cache[kind] = out
	return out
