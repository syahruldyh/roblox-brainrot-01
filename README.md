[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/syahruldyh/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/syahruldyh/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

Built for the [make.fun bounty](https://make.fun/bounty/roblox-brainrot-01).

# SNACK ATTACK — roblox-brainrot-01

A 3D food-market brainrot game. Players collect absurd food-meme characters that earn
coins every second, keep them on their market stall, and climb a ladder of 6 rarities,
4 mutations and rebirths — while other players can steal from unlocked stalls and a
periodic Health Inspector sweep forces a dash home with the catch.

## The cast (14, across 6 rarities)

Common: Sir Fries-A-Lot ($1/s), Captain Noodle ($2/s), Baron Von Burger ($3/s) ·
Rare: Duchess Donut ($6/s), Professor Pizza ($9/s), Count Croissant ($12/s) ·
Epic: Madame Macaron ($20/s), General Taco ($30/s), Lady Boba ($45/s) ·
Legendary: Emperor Espresso ($80/s), Queen Quiche ($120/s) ·
Mythic: King Kebab ($200/s), Duke Dumpling ($300/s) ·
Brainrot: The Almighty Snack ($600/s).

Mutations: Golden x2, Rainbow x3, Void x5. Rebirth needs all 6 rarities in the
collection plus $10,000 cash, and pays +25% income forever per rebirth.

## The loop

Spawn in the market → walk to the conveyor (the first walker is always Sir
Fries-A-Lot, $25, so the first buy lands within 10 seconds) → buy → carry it to
your stall → press PLACE → it earns coins/sec → buy the next tier. Steal from an
unlocked stall with Q, lock your own stall with L ($250, 60s, 120s cooldown),
mutate a stall brainrot ($1,000), rebirth with R. Every 150 seconds the Health
Inspector warns for 30s then sweeps the plaza: carriers caught outside their own
stall drop their haul.

## First-60-seconds design

No intro, no cutscene: you spawn in the market, the cheapest brainrot is already
on the belt, the first coins land within ~30 seconds, and the HUD always shows the
next tier ("Next: Duchess Donut — $250") plus a pity counter (8 belt spawns without
an Epic-or-better guarantees the next spawn is Epic+). The wanted action glows:
BUY lights up when a walker is in reach, PLACE when you are carrying.

## Build

```sh
rojo build -o game.rbxl        # Rojo 7.7.1; writes the binary place
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts   # writes out/ + dossier.json
```

## Publish (the Roblox account owner does this)

1. Open `game.rbxl` in Roblox Studio, publish it as a **new experience** on the
   account, set it **Public** (description + genre + content questions first).
2. Put the account's make.fun play code in the experience description.
3. Fill in `PLAY.json` with the real `place_id` and `universe_id`, rebuild, and
   replace the placeholder screenshots with real Studio captures (1280x720,
   each ≤256 KiB, first by name = the Roblox thumbnail).
4. Upload an icon (512x512) and the first screenshot as the thumbnail on the
   Creator Dashboard, wait until both show on the experience page.
5. Publish the finished place over the same experience before submitting:
   `scripts/publish.sh <universe_id> <place_id>` (Open Cloud; do not run it
   without the real ids).

## Controls

- **E** buy the nearest conveyor brainrot · **F** place a carried brainrot on
  your stall · **Q** steal the nearest brainrot from an unlocked stall ·
  **L** lock your stall ($250) · **R** rebirth · touch buttons do the same on
  mobile. Walk with WASD / the touch joystick.

## Structure

- `src/shared/` — Config (cast, rarities, rates, timings), Types, Net (all remotes)
- `src/server/` — `init.server.luau` + Services: StateService (the ONE state
  module: cash, stall, collection, carrying, lock, rebirths), ConveyorService,
  StallService, EconomyService, InspectorService, CharacterFactory, Validate,
  RateLimiter
- `src/client/` — `init.client.luau` + Controllers: HudController, InputController,
  EffectsController

The server owns all state; the client renders it and sends intents. Every remote
is rate-limited and validated server-side (type, range, distance, lock, cash).

## Notes

- Session-only state: cash, stall and collection are not persisted across servers
  (no DataStore in this build). Progress resets when the server restarts.
- `PLAY.json` currently holds placeholder ids (0, 0) and `screenshots/` holds
  labelled placeholder images — both must be replaced with the real published
  experience and real Studio captures before submitting.
