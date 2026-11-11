# Grand Theft Wheelchair

A class-made game about rolling, grinding, wheelie-ing and out-smarting the Stairs Inc. baron,
who keeps building stairs everywhere. Made in Godot 4.7 with Blender models and our own music.

## ▶ Play it

- **In the browser:** https://joshuamrumack-collab.github.io/grand-theft-wheelchair/
  (Chrome or Edge works best. The first load is about 110 MB, so give it a minute.)
- **On Windows:** download `GrandTheftWheelchair-Windows.zip` from the
  [Releases page](https://github.com/joshuamrumack-collab/grand-theft-wheelchair/releases/latest),
  unzip it and run `GrandTheftWheelchair.exe`. If Windows shows "Windows protected your PC",
  click **More info → Run anyway** (the game isn't signed, that's all).

## Controls

| Keyboard | Gamepad | What it does |
|---|---|---|
| W A S D / arrows | triggers + left stick | roll and steer |
| Space | A | hop / flip in the air |
| steer in the air | stick in the air | spin |
| X | X | wheelie on the ground, grab in the air |
| **X next to a curb, ledge or rail** | X | **grind** (steer to keep your balance, Space to hop off) |
| Shift | RB | turbo |
| E | Y | steal a chair / hide in a dumpster |
| F | LB | throw a donut at the cops |
| H | B | bell |
| P / T | Back / D-pad down | photo mode / instant replay |
| R, C, N, F3, F11 | | radio, camera, day/night, retro look, fullscreen |
| Esc | Start | menu: game speed, toggle-instead-of-hold, assist steering, one-switch mode, colour-blind mode, HUD size |

## Modes
- **Story:** two acts of missions against the Stairs Inc. baron.
- **Score Attack:** take turns, 1–8 players, 1–3 minute runs, class high-score table.
- **Create-a-Rider:** make your own rider.
- **Goals:** 10 skate goals around the city (letters, combos, grinds, a secret cassette...).

## Add your own stuff
Make a `custom` folder next to the game (or in the project folder) with:
- `custom/prints/` – PNG pictures for T-shirt prints
- `custom/graffiti/` – PNG pictures that show up as wall art in the city
- `custom/sounds/` – WAV/OGG files that replace game sounds (see the README inside)

Music goes in `assets/audio/` (radio) and `assets/audio/menu/` (title screen) in the project.

## Open the project
Install [Godot 4.7](https://godotengine.org/download), choose **Import**, pick `project.godot`
in this folder and press F5. Blender scripts that build the models are in `tools/`.

## Project layout
- `scripts/main.gd` – game rules, stealing, police, props, day/night
- `scripts/chair.gd` – wheelchair physics, NPCs and cops
- `scripts/tricks.gd` – hops, flips, grabs, grinds, combos
- `scripts/city.gd` – builds the city, skate plaza and parks
- `scripts/story.gd`, `goals.gd`, `score_attack.gd` – missions, goals, Score Attack
- `scripts/models.gd` – loads the Blender models in `assets/models/`
- `scripts/hud.gd` – menus and on-screen info
- `tools/` – Blender and texture scripts
