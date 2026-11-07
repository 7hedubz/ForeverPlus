ForeverPlus 1.1.4 — WoW Forever dungeon timer and run journal
============================================================
Author: DoHeal. Interface16001 / Camelot.
Install in _forever_/Interface/AddOns/ForeverPlus.
From 1.1.0-1.1.3: /reload. New install or upgrade from before1.1.0: relaunch.

DUNGEON JOURNAL
/fplus opens dungeon -> individual run -> roster, damage/healing, deaths.
The list toggles Alphabetical / Level Range, remembering your choice.
New completed, abandoned, and reset attempts are recorded; demos never save.
History retains up to500 runs. Old personal bests cannot recreate missing stats.

FORCES: ANY MOB, EXCLUDING RECOGNIZED BOSSES
Each native PARTY_KILL notification during an active real party-instance run
adds one kill (2%), even if all payload values are secret or absent. No target,
readable GUID, threat, tap, or hostility filter is required. Fifty net kills
reach100%. Recognized boss deaths are deducted once; duplicate boss signals
must not subtract again. Optional/unknown-roster boss signals also exclude.
Order before/after a native notification converges; a late boss notification
can correct forces downward. A boss the client never identifies cannot be
classified from an opaque kill. Two native notifications count as two events,
not a GUID-verified unique enemy. No hidden IDs are exposed or reconstructed.
Only native notifications add forces: scans/CLEU cannot double-count a kill.
Existing progress is preserved on upgrade; new ledger/exclusions persist on
reload. Earlier rejected session notifications are not guessed/backfilled.

BOSSES AND TIMER
One hour; +3 through36:00, +2 through48:00, +1 through60:00. Overtime continues.
Auto-complete requires all configured bosses plus100% non-boss forces.
Unknown/empty boss rosters require /fplus complete. Exact names/aliases and
verified death can identify bosses with restricted GUIDs; disappearance alone
never counts. Each new required boss posts remaining time/overtime, current
forces after boss deduction, and boss progress to PARTY chat. No solo/raid/demo
reports; no duplicate boss-event reports. No cross-client announcer election.

STATS AND DEATHS
Damage excludes overkill, healing excludes overhealing, known pets attribute
to owners. Client restrictions can make damage/healing unavailable (dash), not
fabricated zero totals. The forbidden CLEU registration remains removed.
HUD Deaths is party-wide; journal rows keep per-player deaths. Readable unit
state plus events/polling deduplicate deaths and resurrection. Existing corpses
on new joins are baselined rather than counted as fresh deaths.

SYNC
/fplus sync, journal Sync runs, or right-click minimap -> Sync runs.
New real archives queue sync automatically. A friend who installs later can
receive earlier recorded runs they participated in. Both online, outside
instances, grouped or in the same guild, using a compatible addon version.
Only recorded participants import/display the run; transport is not encrypted.
Shared stats remain unverified observations. Personal bests stay separate.

COMMANDS
/fplus                 dungeon journal
/fplus sync            participant run synchronization
/fplus debug           native notification / boss-deduction ledger diagnostics
/fplus lock            toggle timer dragging
/fplus reset           archive reset attempt, restart timer/objectives/ledger
/fplus complete        force-complete real run
/fplus abandon         archive abandoned attempt without completion PB
/fplus times           print personal bests and toggle journal
/fplus share           legacy personal-best sharing
/fplus demo or /demo   unsaved practice timer
Minimap left-click: timer. Right-click: history / sync / lock / close menu.

TESTS
python3 tests/run.py requires Python3, LuaJIT, luac. Mocked-API tests do not
replace live-client verification. See README.md for full behavior/limitations.
