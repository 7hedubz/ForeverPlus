# ForeverPlus

Gag Mythic+ timer for **World of Warcraft: Forever**. Interface `16001` (Camelot).

Drop the `ForeverPlus` folder into `World of Warcraft/_forever_/Interface/AddOns`, fully quit the client, enable it at character select.

## What it does

- Enter any 5-man and a **1-hour** key starts.
- Chests: **+3 at 36:00**, **+2 at 48:00**, **+1 at 60:00**.
- The clock **keeps running after 60:00** (`+M:SS` in red). Depleted runs still save a time.
- A run times only when **every standard boss** is dead **and** enemy forces hit **100%** (each mob kill is **2%**, so 50 kills). Rares and optionals do not count as bosses.
- Personal bests are saved. Party/guild members with the addon share times **outside** instances (Forever blocks addon chat inside dungeons).

## Commands

| Command | What it does |
|---|---|
| `/fplus` | Best-times board |
| `/fplus lock` | Lock / unlock dragging the timer |
| `/fplus reset` | Restart the key at 60:00; clear bosses and forces |
| `/fplus complete` | Force-end and save (if a kill is not detected) |
| `/fplus abandon` | Drop the key without saving |
| `/fplus times` | Print personal bests |
| `/fplus share` | Push times to party/guild (open world) |
| `/fplus demo` or `/demo` | Toggle a practice timer (not saved, not Deadmines) |

## UI

- Timer: dungeon name, countdown, chest, best vs this run, deaths, **Bosses x/y**, **Forces n%**. Drag to move; right-click opens the board.
- Minimap button: left-click timer, right-click board.

## Notes

- Addon messages are queued in the dungeon and sent after you leave.
- Shaper's Terrace has no published boss list yet — `/fplus complete` if needed.
