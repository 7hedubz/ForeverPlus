ForeverPlus 1.3.1 — WoW Forever dungeon timer and run journal
============================================================
Author: DoHeal. Interface16001 / Camelot.
Install in _forever_/Interface/AddOns/ForeverPlus.
From 1.1.0-1.3.0: /reload. New install or upgrade from before1.1.0: relaunch.

DUNGEON JOURNAL
/fplus opens dungeon -> individual run -> roster, damage/healing, deaths.
The list toggles Alphabetical / Level Range, remembering your choice.
New completed, abandoned, and reset attempts are recorded; demos never save.
History retains up to500 runs. Old personal bests cannot recreate missing stats.

FORCES: ANY MOB, EXCLUDING RECOGNIZED BOSSES
Each native PARTY_KILL notification during an active real party-instance run
adds one kill (1.2%), even if all payload values are secret or absent. No target,
readable GUID, threat, tap, or hostility filter is required. Eighty-four net kills
reach100%. Recognized boss deaths are deducted once; duplicate boss signals
must not subtract again. Optional/unknown-roster boss signals also exclude.
Order before/after a native notification converges; a late boss notification
can correct forces downward. A boss the client never identifies cannot be
classified from an opaque kill. Two native notifications count as two events,
not a GUID-verified unique enemy. No hidden IDs are exposed or reconstructed.
Only native notifications add forces: scans/CLEU cannot double-count a kill.
Kill counts, timer and ledger/exclusions persist on reload. The uniform 1.2%
rate recalculates ongoing percentages from the same kills, without resetting
the run. There are no RFC, Wetlands, SFK or other dungeon exceptions. Old PBs/history stay intact. Earlier rejected session notifications are not guessed/backfilled.

RUN LIFETIME / ABANDON
An active run never resets until explicitly abandoned or completed. Death,
release, corpse runs, resurrection, zone changes, another dungeon and /reload
(including outside the dungeon) preserve the original timer and run data.
There is no automatic 12-hour expiration. A different dungeon cannot replace
an unfinished attempt or add objective credit to it. /fplus reset is still an
intentional manual restart, never an automatic action.

Click HUD Abandon, minimap -> Abandon run, or /fplus abandon. Solo: Yes/No
confirmation. Group: discover compatible peers for about 3 seconds, then all
discovered addon voters must agree within 20 seconds. No/timeout/run or roster
change/local send failure keeps the attempt active. No responders after an
accepted discovery offers explicitly LOCAL-ONLY confirmation, not proof that
nobody else uses the addon. Older/non-addon members cannot vote. Rejected
transport never silently falls back to local abandon. Voting is best-effort,
not atomic: lost packets can make clients disagree despite API acceptance.
Reload cancels in-flight voting but preserves the active run. The vote panel
appears even with the timer HUD hidden. Explicit abandon archives once and
suppresses automatic restarts while still inside, including after reload.

BOSSES AND TIMER
One hour; +3 through36:00, +2 through48:00, +1 through60:00. Overtime continues.
Auto-complete requires all configured bosses plus100% non-boss forces.
Unknown/empty boss rosters require /fplus complete. Exact names/aliases and
verified death can identify bosses with restricted GUIDs; disappearance alone
never counts. Each new required boss PREPARES a time/forces/progress snapshot.
Click HUD Send report (N), minimap Send boss report, or type /fplus report
OUT OF COMBAT. Each click/command attempts ONE pending line synchronously;
boss callbacks, timers, UI ticks and combat-end events NEVER send public chat.
Direct guild /run worked in the client while a delayed identical call silently
did not deliver despite pcall true/nil, so sends must stay in player context.
The direct test does not prove party delivery; check actual chat after clicking.
PARTY/INSTANCE_CHAT is selected for the current group category. Plain-text
payloads have no invalid pipes. Global API first, modern availability fallback.
No automatic retry/fallback after a send. Rejected calls retain the report for
manual retry. A normal nil return consumes the attempted line, NOT proof of
delivery. /fplus debug shows cumulative attempts/errors and last status, with
delivery unverified. The HUD report button shows how many lines are pending.
Report text/tooltip explicitly say AT BOSS DEATH, not current HUD progress.
Report snapshots are session-only and bounded; reset/abandon/new attempt,
party context changes or reload discard stale reports. Completion permits
its final queued snapshot. No solo/raid/demo reports or duplicate boss-event
reports; no cross-client announcer election.

REFRESH RELIABILITY
History/boss scan failures and optional report/vote/best/death/journal UI errors
cannot block the core HUD timer/objective refresh. Kill changes request an
immediate safe HUD update. /fplus debug shows refresh errors by stage and the
actual last-displayed HUD state, distinct from frozen boss-death reports.
84 net kills may exceed a short dungeon/wing's available trash. No verified
Forever population quotas are bundled. /fplus complete remains the manual
override; dungeon-specific scaling is not silently applied.

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
/fplus debug           native ledger and public-report attempt diagnostics
/fplus report          directly attempt one pending boss report out of combat
/fplus lock            toggle timer dragging
/fplus reset           archive reset attempt, restart timer/objectives/ledger
/fplus complete        force-complete real run
/fplus abandon         explicit confirmation / compatible-party abandon vote
/fplus times           print personal bests and toggle journal
/fplus share           legacy personal-best sharing
/fplus demo or /demo   unsaved practice timer
Minimap left-click: timer. Right-click: history / sync / lock / abandon / report.

TESTS
python3 tests/run.py requires Python3, LuaJIT, luac. Mocked-API tests do not
replace live-client verification. See README.md for full behavior/limitations.
