# ForeverPlus

Dungeon timer and run journal for **World of Warcraft: Forever**. Version **1.3.0**, Interface `16001` (Camelot).

## Install / upgrade

Put the `ForeverPlus` folder directly in `World of Warcraft/_forever_/Interface/AddOns`. Upgrading from **1.1.0–1.2.1 to 1.3.0** only needs `/reload`. New installs or upgrades from before 1.1.0 need a full quit and relaunch to load the history/sync files. Existing personal bests and settings are preserved.

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

- Historical run/PB synchronization retains its outside-instance queue policy. Abandon voting uses a separate live party transport attempt; rejected sends fail without ending the run. Do not assume acceptance proves delivery.
- Both characters must be online and reachable through the same supported party/raid/guild context, using this run-sync version. This is not offline mail or cross-account cloud storage.
- The addon only exports a run to another recorded participant and only imports runs containing the receiver and sending participant. Realm-qualified names prevent matching a different realm's same-named character.
- Transfers are chunked, bounded, paced, validated, and retried on send failures. Independent observations of the same physical run are conservatively deduplicated; overlapping observer totals are **never added together**.
- Shared observations are **unverified**, not anti-cheat-certified. Personal bests are not rewritten by imported run history.
- Transfers use addon group/guild channels with logical participant addressing, not encryption. Other channel members can potentially inspect network payloads with another addon even when ForeverPlus does not display/import the run for them.

## Timer rules

Enter a 5-man dungeon to start a one-hour timer. Rewards are **+3 through 36:00**, **+2 through 48:00**, **+1 through 60:00**. Overtime keeps counting and depleted completions still record a time.

Automatic completion requires **all configured required bosses plus 100% enemy forces**: each native party-kill notification contributes 0.5%, with recognized bosses deducted (200 net non-boss notifications). Bosses do not contribute forces. Empty/unverified rosters, such as Shaper's Terrace and unknown dungeons, are manual-only. If a required kill is unavailable to the client, `/fplus complete` is the explicit override.

### Run lifetime and explicit abandon

**Until explicitly abandoned or completed, an active real run never resets itself.** Death, releasing, corpse runs, resurrection, leaving/re-entering, visiting another dungeon, and reload outside the dungeon preserve the original start time, elapsed wall-clock time, deaths, recorded stats, bosses, and forces ledger. There is no automatic twelve-hour expiration. A different dungeon does not replace an unfinished run or contribute objective credit; complete or abandon the old run first. `/fplus reset` remains an intentional manual restart command, not an automatic lifecycle action.

Use the HUD **Abandon** button, **right-click minimap → Abandon run**, or `/fplus abandon`. Solo abandonment requires explicit Yes confirmation. Grouped requests discover compatible voting peers for about three seconds. With responders, all discovered addon voters must agree within twenty seconds; No, timeout, party/run changes, or a rejected local send leave the run active. Non-addon and older-addon players cannot vote. Successful discovery with no responders offers a clearly labeled **local-only** confirmation, not proof that nobody else has the addon. API send rejection never falls back to abandoning automatically.

Voting is best-effort live party communication, not atomic distributed state: packet loss can make clients disagree despite local API acceptance. Votes are not queued for later historical replay, nor can an outsider/guild/raid packet approve a party vote. A reload cancels local in-flight voting while preserving the active run. If the server blocks live transport, the vote reports failure rather than silently approving.

Explicit abandonment archives one abandoned attempt and does not immediately auto-start another timer while you remain in the instance, including after reload. Completed sessions likewise do not restart on another zone notification. A subsequent new entry can start a new attempt; `/fplus reset` deliberately starts fresh when desired.

### Any-mob forces and boss reports

Forces now use the requested **event-counting policy**: each native **PARTY_KILL** notification received during an active real party-instance run adds one kill (0.5%), even when its payload is secret, absent, or unreadable. No selected target, readable GUID, threat, or tap/hostility check is required. Native notifications are the only force-count source; legacy combat-log deaths and visible corpse scans cannot add another force kill.

**Bosses are excluded:** recognized boss deaths are deducted once from the native notification total. Required-boss name/alias matching, BOSS_KILL, and successful ENCOUNTER_END signals share exclusion state to avoid subtracting duplicate notifications. Known optional/unknown-roster boss signals are excluded too. Arrival before or after a native notification must converge to the same net count; forces may adjust downward when a boss notification arrives later.

**Opaque boss-signal limit:** a BOSS_KILL receipt with neither readable name nor encounter ID deducts once per receipt. A fully opaque ENCOUNTER_END does not add a second fallback deduction. Duplicate fully opaque boss receipts, or two sources without any shared readable identity, cannot be reliably correlated and may over-deduct; no hidden boss identity is inferred.

This is an event counter, not GUID-verified enemy classification: two native notifications count as two events even if any readable payload happens to match. No hidden identifier is read or reconstructed. A boss the client never identifies cannot be distinguished from an ordinary opaque kill; classification is limited to observed boss signals.

The saved run keeps its existing progress when upgrading, then persists its new native-event total, boss deductions, and exclusion state across reload. Earlier rejected session-only notifications are not guessed/backfilled. Reset starts a fresh ledger; completed, abandoned, practice, and non-party-instance runs do not gain forces.

Boss tracking remains independent of force GUID eligibility: exact readable names/aliases and verified death can identify required bosses with restricted GUIDs. A prior living-hostile observation supports a corpse that stops being attackable; mere disappearance is not a death. Name-only boss tracking excludes the recognized boss but does not create a native kill event.

### Refresh reliability and rate migration

HUD timer/objectives refresh independently of optional history scanning, boss scanning, report/vote panels, best/death extras, and journal status. Failures are isolated by stage, counted and safely recorded rather than silently freezing the forces display; there is no automatic public-chat send in recovery. Native kill changes also request an immediate safe HUD refresh. `/fplus debug` includes refresh health and the actual displayed HUD snapshot/age to distinguish current core values, stale renderings and old chat snapshots.

The global **0.5% per counted non-boss event** rate requires **200 net kills**. The timer and raw kill ledger are retained on upgrade; an ongoing run's percentage is recalculated at the new rate, not preserved at the old 2% figure. Existing completed runs are not reopened, and saved PB/history records are not rewritten. Half-percent values are shown without truncation in HUD, chat and debug.

A flat 200-kill requirement may be unattainable on short dungeons, individual wings or skip-heavy routes. There is no verified per-dungeon Forever population table bundled with this addon, so no per-dungeon safety guarantee or automatic scaling is claimed. Use `/fplus complete` for an explicit manual completion if all available content is exhausted below the target. Dungeon-specific quotas would be a separate balancing change.

### Click-to-send boss reports

Each newly recorded required boss **prepares** a one-line snapshot: boss name, time remaining/overtime, Forces % after boss deduction, and boss progress. It does **not** call public chat from the boss event, a timer, OnUpdate, or a combat-end callback. The user reproduced public guild chat delivering from an immediate `/run` but silently not delivering after `C_Timer.After`, despite both returning `pcall: true, result: nil`. This points to the player-action context; it is not proof of all server permission/channel rules.

The HUD opens with **Send report (N)** ready. Click it **out of combat** to attempt one report synchronously in that button's click handler; alternatively use **minimap → Send boss report** or **`/fplus report`** directly in game chat. One player action sends one pending line, not a multi-line burst. PARTY is used normally, INSTANCE_CHAT for a confirmed instance-category group. The legacy global API is preferred, with the modern namespace as an availability fallback, matching the successful direct test. There is no automatic retry or second-API attempt.

Reports are bounded, session-only snapshots, not a timer-driven sender queue. Duplicate boss signals do not create more reports. Completion permits its queued final report, while explicit reset/abandonment, a new attempt, changed party membership/context, and reload discard stale pending work. Report text and its tooltip are explicitly labeled **at boss death**: time and forces describe that historical snapshot, not a later click or current HUD. Demo/solo/raid runs do not prepare public reports.

Thrown/explicitly rejected sends remain for a **manual** retry; leaving combat only re-enables the button, never sends. A normal void return consumes one attempted line but does **not** prove delivery. `/fplus debug` reports cumulative attempt/error counters and the last status, with delivery explicitly unverified; the HUD button shows the pending count. Check the actual party/instance chat after clicking. No cross-client announcer election or hidden-API bypass is claimed.

The forbidden CLEU registration remains removed. Optional legacy-parser tests are synthetic and do not imply live damage/healing availability. Run `/fplus debug` after a party kill to see the native-event ledger and boss deductions; target details are optional diagnostics, not a gameplay requirement.

## Commands and minimap

`/fplus report` attempts one pending boss report immediately from the typed command, out of combat. It does not schedule a timer.

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
