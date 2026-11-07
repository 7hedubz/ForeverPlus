# ForeverPlus

Dungeon timer and run journal for **World of Warcraft: Forever**. Version **1.1.3**, Interface `16001` (Camelot).

## Install / upgrade

Put the `ForeverPlus` folder directly in `World of Warcraft/_forever_/Interface/AddOns`. Upgrading from **1.1.0–1.1.2 to 1.1.3** only needs `/reload`. New installs or upgrades from before 1.1.0 need a full quit and relaunch to load the history/sync files. Existing personal bests and settings are preserved.

## Dungeon journal

Open with `/fplus`, or right-click the minimap icon and choose **Dungeon history**.

Use the button above the dungeon list to toggle **Alphabetical / Level Range**. Your choice is saved. Level Range sorts by the lowest recommended level, then the upper level, then dungeon name. Recommended bands are shown next to run counts and come from the installed ForeverGuide catalog; they are not admission requirements. Unknown bands sort last in Level Range mode. **All dungeons** stays pinned and sorting preserves the selected dungeon/run.

1. Select a dungeon in the left column (or **All dungeons**).
2. Select an individual run in the middle column.
3. View date, elapsed time, completion status, recorder, stats coverage, the participant roster, and per-player **damage**, **healing**, and **deaths** on the right.

New completed runs are recorded, including overtime and manually completed runs. Abandoned and reset attempts are retained with their own status rather than pretending to be completions. Demo/practice runs are never saved or synced. Run history is capped at 500 records, evicting the oldest; it is not an unlimited combat-log archive.

**Old personal-best entries cannot be turned into detailed runs:** previous versions did not store the roster or combat totals. No historical stats are invented.

### How combat stats work

The addon snapshots group members, including members who do not have ForeverPlus, and records the combat events this client can observe. Damage excludes overkill, healing excludes overhealing, known pets are attributed to their owners, and duplicate death notifications are deduplicated. Roster changes are retained within the run's participant limit.

Coverage is explicitly labeled **Observed**, **Partial**, or **Unavailable**. Observed does not mean server-certified or globally complete. If Forever restricts combat information, unavailable damage/healing is shown as a dash rather than fabricated zero totals. Range, restrictions, disconnected clients, and joining mid-run can limit what was observed.

The timer HUD's **Deaths** is the total for the recorded party, including members who do not have the addon. The journal retains each participant's own death count. Readable party dead/alive unit state is observed directly as well as CLEU/local death events; resurrection clears the per-player latch so another death can count, while duplicate death notifications do not. Unavailable or secret unit values do not invent deaths. New participants already dead when first observed form a baseline rather than a fabricated earlier death.

## Syncing past runs

Use **`/fplus sync`**, the journal's **Sync runs** button, or **right-click minimap → Sync runs**. Archiving a new real run also queues participant sync automatically; requests made in an instance wait until outside.

Example: you record a dungeon with a friend who has no addon. After they install ForeverPlus, group with them (or be online in the same guild), both outside instances, and click Sync. The participant handshake exchanges eligible recorded runs so the friend can see the shared dungeon and its recorded stats. Either participant can initiate; repeated sync is duplicate-safe.

- Forever blocks addon messages inside instances. A request made there waits until outside.
- Both characters must be online and reachable through the same supported party/raid/guild context, using this run-sync version. This is not offline mail or cross-account cloud storage.
- The addon only exports a run to another recorded participant and only imports runs containing the receiver and sending participant. Realm-qualified names prevent matching a different realm's same-named character.
- Transfers are chunked, bounded, paced, validated, and retried on send failures. Independent observations of the same physical run are conservatively deduplicated; overlapping observer totals are **never added together**.
- Shared observations are **unverified**, not anti-cheat-certified. Personal bests are not rewritten by imported run history.
- Transfers use addon group/guild channels with logical participant addressing, not encryption. Other channel members can potentially inspect network payloads with another addon even when ForeverPlus does not display/import the run for them.

## Timer rules

Enter a 5-man dungeon to start a one-hour timer. Rewards are **+3 through 36:00**, **+2 through 48:00**, **+1 through 60:00**. Overtime keeps counting and depleted completions still record a time.

Automatic completion requires **all configured required bosses plus 100% enemy forces**: each eligible, party-credited hostile creature kill contributes 2% (50 kills). Boss creature kills may contribute forces. Empty/unverified rosters, such as Shaper's Terrace and unknown dungeons, are manual-only. If a required kill is unavailable to the client, `/fplus complete` is the explicit override.

Reset/resume and boss-confirmed wing tracking preserve consistent saved state. Completed sessions do not restart merely because of another zone notification or reload; use `/fplus reset` to restart intentionally.

### Visible kill tracking and boss reports

The native **PARTY_KILL** game event is separate from the blocked combat-log stream. When its attacker GUID matches a current party member/pet and its target GUID is a readable creature/vehicle GUID, the addon awards 2% through the same saved GUID deduplication. This path does not require your selected target or `UnitGUID("target")`. Event payload availability still needs live-client confirmation; restricted payloads are rejected, not exposed or guessed.

A secondary visible-unit path is available only when creature GUIDs are readable: living, attackable creatures in combat need readable party/pet threat (or the creature targeting a party member) and a readable false tap-denied flag. Verified visible death then counts even if the corpse is no longer attackable.

Boss tracking is independent of the force GUID requirement. Readable exact boss names/aliases and verified death can mark a required boss when its GUID is unavailable; prior living-hostile boss evidence covers corpses that stop being attackable. Name-only boss tracking never invents force credit. Mere disappearance is not a death.

Forever forbids CLEU registration on this client, so the addon no longer attempts that protected registration by default. The optional legacy parser remains covered by explicit synthetic-payload tests; those tests do not imply a live combat-log stream exists.

A corpse first seen after the kill, loot rights alone, an idle selected mob, or secret/unavailable engagement data does not establish credit. Earlier missed kills cannot be reliably reconstructed and are not invented. Saved credit and deduplication survive reload. Damage/healing still require readable combat events; this forces fallback does not manufacture combat totals.

Each newly recorded required boss posts **time remaining (or overtime), current Forces %, and boss progress** to normal PARTY chat. Duplicate boss events do not repeat the report; demo/solo/raid runs do not post. Each addon instance reports its own observation; this is not cross-client announcer election. Failed public sends are not retried, to avoid duplicate chat.

If forces still do not move, run `/fplus debug` after a party kill. Native-event counters distinguish no PARTY_KILL notifications from readable/restricted event payloads. Target details are optional diagnostics, not a requirement to target enemies while healing. No command attempts to reveal secret GUIDs.

## Commands and minimap

| Command | Action |
|---|---|
| `/fplus` | Toggle dungeon journal |
| `/fplus sync` | Exchange recorded runs with eligible online participants |
| `/fplus debug` | Print kill-credit / CLEU diagnostics and target API availability |
| `/fplus lock` | Toggle timer dragging lock |
| `/fplus reset` | Archive the current attempt as reset and restart the timer |
| `/fplus complete` | Force-complete and save the current real run |
| `/fplus abandon` | Archive the active attempt as abandoned, without setting a completion PB |
| `/fplus times` | Print personal bests and toggle journal |
| `/fplus share` | Legacy best-time sharing outside instances |
| `/fplus demo` or `/demo` | Toggle unsaved practice timer |

Minimap **left-click** toggles the timer. **Right-click** opens the menu: Dungeon history, Sync runs, Lock / unlock timer, Close. Drag the timer to reposition; right-click the timer itself opens the journal.

## Tests

Requires Python 3, LuaJIT, and `luac`:

```sh
python3 tests/run.py
```

Regression tests cover lifecycle/persistence, kill and boss matching, history/stat recording, participant sync, malformed packets, retry/instance restrictions, dungeon/run selection, minimap actions, and full-TOC integration. Mocked-API checks do **not** verify actual client rendering, Forever's roster, or live-client event/API availability.
