# goBot Arena

One AI bot's journey from birth to domination and death.

A 3D endless-survival game built on the goBot voxel engine in **Godot 4.6.3**,
exported to HTML5/WebAssembly and playable in the browser. Pilot a robotic bot
across procedurally generated voxel terrain, eat smaller bots to physically grow
larger, and avoid anything bigger than you. Score is size. There is no winning —
only how long you last and how big you get.

## Play

After the GitHub Actions deploy completes, the game is live at:
**https://jcarterc.github.io/goBot/**

## How it plays

- An animated voxel title screen → a lobby where you pick your **bot type** and
  **world density** → the arena.
- Eat a bot you're at least 15% larger than and you absorb part of its size.
  Get touched by something 15% larger than you and it's game over.
- The world always holds bots ranging from marble-sized to building-sized.

### Bot types

| Type | Body | Movement |
|---|---|---|
| **Walker** | Blocky biped | Follows the terrain surface; slowest but nimble |
| **Roller** | Sphere | Rolls on the ground; fastest on the flat, loses grip on slopes |
| **Flyer** | Saucer | Flies in a band 5–30 units above terrain; eats/eaten by ground bots when vertically close |

### World density

| Option | Bots |
|---|---|
| Sparse | 20–30 |
| Dense | 60–80 |
| India | 150–200 (stress test) |
| Custom | 10–250 slider |

## Controls

### Desktop
| Input | Action |
|---|---|
| Mouse | Look (bot steers where the camera faces) |
| WASD | Move |
| Space / Shift | Flyer up / down |
| F1 or V | Toggle first / third person |
| T | Toggle on-screen touch controls |
| Esc | Release mouse |

### Mobile / touch
On-screen controls are **auto-enabled on touch devices** (and can be toggled in
the lobby or with the `T` key on desktop):

- **Left half** — drag to use a virtual joystick for movement.
- **Right half** — drag to look around.
- **VIEW button** (bottom-right) — toggle first/third person.
- **▲ / ▼ buttons** — climb / descend (Flyer only).

## Project layout

```
scenes/Main.tscn        entry scene (Root controller)
scripts/Root.gd         Title -> Lobby -> Arena -> Game Over flow
scripts/GameState.gd    autoload singleton: run config, score, window.__gobot bridge
scripts/TitleScreen.gd  animated voxel "goBot" title
scripts/Lobby.gd        bot type + density selection
scripts/Arena.gd        assembles terrain, player, bots, camera, HUD
scripts/World.gd        voxel terrain (Minecraft-like), arena_mode hooks
scripts/Bot.gd          base bot: size, eating, growth, AI state machine
scripts/WalkerBot.gd / RollerBot.gd / FlyerBot.gd
scripts/BotSpawner.gd   population, batched AI, culling/LOD, respawns
scripts/BotAI.gd        (state logic lives in Bot.gd)
scripts/SoundSynth.gd   procedurally baked audio (no external files)
scripts/CameraController.gd  first/third person + input
scripts/TouchControls.gd     on-screen mobile controls
scripts/ArenaHUD.gd     size / score / danger HUD
scripts/GameOverScreen.gd
```

## State bridge (tests)

The game mirrors live state to the browser for Playwright automation:

```js
window.__gobot = {
  game_state: "lobby" | "playing" | "game_over",
  player_size: 1.4,
  player_bot_type: "roller",
  score: 4820,
  best: 12440,
  bot_count: 62,
  density_mode: "dense",
  ready: true
}
```

## Build locally

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/index.html
node server.js          # serves build/ at http://localhost:8060
```

## Deploy

`.github/workflows/deploy.yml` builds the WASM export with Godot 4.6.3 headless
on push to `main` and publishes to GitHub Pages. Pages source must be set to
**GitHub Actions** (Settings → Pages).
