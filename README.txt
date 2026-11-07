ForeverPlus 1.0.1 — WoW Forever gag Mythic+ timer
================================================
Interface 16001 / Camelot. Install in _forever_/Interface/AddOns/ForeverPlus.
Existing install: /reload. New install: fully quit and relaunch the client.

COMPLETION
- One-hour timer. +3 through 36:00, +2 through 48:00, +1 through 60:00.
- Overtime continues and depleted completions still save a time.
- Every configured required boss PLUS 100% forces is required for auto-completion.
- Each credited hostile creature kill = 2% (50 kills). Boss kills may count too.
- Stable creature GUIDs and party/pet kill credit are required. Unrelated deaths,
  players, friendly pets, and repeated scans do not add forces.
- Empty/unverified rosters (Shaper's Terrace, unknown dungeons) are MANUAL ONLY.
- If combat information is unavailable or a required kill is missed, use
  /fplus complete. This intentionally force-completes and saves a real run.
- Completed sessions do not restart on zone notifications or reload. Use reset
  for an intentional restart. Practice runs never save/share demo times.

COMMANDS
/fplus                 toggle best-times board
/fplus lock            toggle timer dragging lock
/fplus reset           restart/reset dungeon timer and clear objectives
/fplus complete        force-complete and save current real run
/fplus abandon         abandon current run without saving completion
/fplus times           print personal bests and toggle board
/fplus share           share outside instances; queue while inside
/fplus demo or /demo   toggle unsaved Demo Key practice timer

UI
Drag timer; right-click opens board. Minimap left-click toggles timer;
right-click toggles board. Manual boss rosters are explicitly labeled.

SHARING
Party/raid/guild only, outside instances. Whole-record packets, validation,
rate limits, retries, and bounded/expiring peer storage protect data integrity.
Peer times are UNVERIFIED claims, separate from your personal bests. A member
can still advertise a plausible fabricated time. Upgrade all participants.

TESTS
python3 tests/run.py (requires Python 3, LuaJIT, luac).
Mocked-API tests do not validate real-client rendering or Forever's roster/API
behavior. See README.md for details.
