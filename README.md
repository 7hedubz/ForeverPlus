# ForeverPlus

Gag Mythic+ timer for **World of Warcraft: Forever**. Version **1.0.1**, Interface `16001` (Camelot).

Install the `ForeverPlus` folder directly in `World of Warcraft/_forever_/Interface/AddOns`. Fully quit and relaunch for a new installation. An existing installation can load Lua changes with `/reload`.

## Completion rules

- Enter a 5-man dungeon to start a **one-hour** timer.
- Rewards: **+3 through 36:00**, **+2 through 48:00**, **+1 through 60:00**.
- Overtime continues in red; depleted completions still record a time.
- Automatic completion requires **every configured required boss** and **100% enemy forces**. Each eligible hostile creature death counts for **2%** (50 kills). Boss creature deaths can contribute forces too.
- Forces require a stable creature GUID and observed party/pet kill credit. Players, friendly pets, duplicate corpse scans, and unrelated deaths do not count. If Forever withholds combat information, the tracker deliberately does not invent kill credit; use manual completion when necessary.
- Missing or unverified boss rosters, including Shaper's Terrace and unknown dungeons, require `/fplus complete`. An empty boss list never automatically completes a run.
- Boss-confirmed wing identification is not replaced by ambiguous entrance defaults.
- Reset/resume preserve consistent saved progress. A completed session does not automatically restart on another zone notification or reload; use `/fplus reset` for an intentional restart.
- Practice/demo runs never save personal bests or share demo results.

## Commands

| Command | Action |
|---|---|
| `/fplus` | Toggle best-times board |
| `/fplus lock` | Toggle timer dragging lock |
| `/fplus reset` | Restart/reset the current dungeon timer and clear objectives |
| `/fplus complete` | Force-complete and save the current real run |
| `/fplus abandon` | Drop the current run without saving a completion |
| `/fplus times` | Print personal bests and toggle the board |
| `/fplus share` | Share best times outside instances; queue while inside |
| `/fplus demo` or `/demo` | Toggle the unsaved "Demo Key" practice timer |

## UI

Drag the timer to move it. Right-click it to open the board. The minimap button toggles the timer on left-click and the board on right-click. Unknown boss rosters are labeled **manual**. Idle fields are cleared instead of showing the previous run's progress.

## Sharing and trust

Forever blocks addon messages inside instances. Shares are queued until outside, sent in whole-record packets, and rate-limited. Receiving is limited to validated party/raid/guild contexts and members. Incoming records are checked and peer data is bounded and expires.

Peer times are **unverified claims**, not authenticated runs. Validation prevents malformed/obviously invalid data, not a group member advertising a plausible fabricated time. Manual completion and timer reset also mean this is not a competitive anti-cheat leaderboard. Your personal bests remain separate from peer records.

Upgrade all participants to this version for the updated sharing behavior and fallback dungeon-key format. Failed sends remain queued for retry rather than reporting false success.

## Tests

With Python 3, LuaJIT, and `luac` installed:

```sh
python3 tests/run.py
```

Tests execute the addon logic against mocked WoW APIs and cover run lifecycle, persistence, kill counting, boss matching, communications, and idle HUD state. They do **not** verify real-client rendering, Forever's actual boss rosters, or secret-value/API behavior in the live client. The tracker fails closed when required values are unavailable; manual completion remains available.
