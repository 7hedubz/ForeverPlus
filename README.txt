ForeverPlus 1.1.3 — WoW Forever dungeon timer and run journal
============================================================
Interface 16001 / Camelot. Install in _forever_/Interface/AddOns/ForeverPlus.
From 1.1.0-1.1.2: /reload. New install or upgrade from before 1.1.0: fully relaunch.

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
HUD Deaths is the party total; journal rows keep per-player deaths. Readable
party dead/alive unit states are tracked even without CLEU and deduplicated
against local/CLEU notifications. Already-dead new joins are baselined, not
invented as a fresh death. Secret/unavailable states do not invent counts.

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

Native PARTY_KILL (not CLEU) counts readable creature/vehicle event GUIDs from
current party/pet attackers without requiring a selected target. Event GUIDs
may still be restricted; diagnostics distinguish missing/unreadable events.
Visible force fallback only works with readable GUID and engagement evidence.
Exact-name boss tracking can use verified deaths without a readable GUID, but
name-only boss credit does not add forces. Disappearance is not proof of death.
The addon no longer attempts the forbidden CLEU registration. Damage/healing
remain unavailable without readable events. Missed kills are not invented.
Each new required boss posts time remaining/overtime and Forces% to PARTY chat,
once per recorded boss per addon instance. No demo/solo/raid announcements.

COMMANDS
/fplus                 dungeon journal
/fplus sync            synchronize eligible participant run histories
/fplus debug           show native PARTY_KILL counters and optional target diagnostics
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
