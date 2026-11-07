ForeverPlus 1.1.1 — WoW Forever dungeon timer and run journal
============================================================
Interface 16001 / Camelot. Install in _forever_/Interface/AddOns/ForeverPlus.
From 1.1.0: /reload. New install or upgrade from before 1.1.0: fully relaunch.

DUNGEON JOURNAL
/fplus opens a three-column journal: choose dungeon -> choose run -> stats.
The button above the dungeon list toggles Alphabetical / Level Range and saves
your choice. Recommended level bands appear beside run counts. Level order is
minimum, maximum, then name; unknown bands sort last, All dungeons stays first.
Bands follow the installed ForeverGuide catalog, not admission requirements.
Each new run records date/time, elapsed duration, completion status, roster,
observed damage/healing, and deaths. Abandoned/reset attempts have their own
status. Demo runs never save or sync. History retains up to 500 run records.
Old personal bests are preserved but cannot supply missing historical stats.

STATS
Damage excludes overkill; healing excludes overhealing. Known pets attribute
to owners. Group members do not need the addon to appear in your recording.
Coverage is labeled Observed / Partial / Unavailable. Client restrictions and
range can limit data; unavailable damage/healing displays as a dash.

SYNC
/fplus sync, journal Sync runs button, or right-click minimap -> Sync runs.
If a friend participated before installing the addon, sync after they install
this version. Both characters must be online, outside instances, grouped or
in the same guild. Either can initiate. Sync exchanges eligible past runs and
deduplicates observations rather than adding their totals together.
Requests inside instances wait until outside. No offline/cloud sync.
Only recorded participants import/display a run. Group/guild addon payloads
are logically addressed, NOT encrypted; other channel members can inspect
traffic using other addons. Received stats remain unverified observations.

TIMER
One hour; +3 through36:00, +2 through48:00, +1 through60:00. Overtime continues.
Auto-complete = all configured required bosses +100% forces (50 credited
hostile creature kills at2% each). Unknown/empty rosters require manual finish.

COMMANDS
/fplus                 dungeon journal
/fplus sync            synchronize eligible participant run histories
/fplus lock            toggle timer dragging lock
/fplus reset           archive reset attempt; restart timer/objectives/stats
/fplus complete        force-complete current real run
/fplus abandon         archive abandoned attempt, without completion PB
/fplus times           print personal bests and toggle journal
/fplus share           legacy personal-best sharing
/fplus demo or /demo   toggle unsaved practice timer

MINIMAP
Left-click toggles timer. Right-click opens history / sync / lock / close menu.

TESTS
python3 tests/run.py (requires Python3, LuaJIT, luac).
Tests mock WoW APIs; real rendering and Forever API/event behavior need live
client confirmation. See README.md for full details and limitations.
