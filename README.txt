ForeverPlus — gag Mythic+ timer for WoW Forever
================================================

Installed to:
  World of Warcraft\_forever_\Interface\AddOns\ForeverPlus

Enable it at character select (AddOns). Interface 16001 / Camelot.

What it does
------------
- Enter any 5-man dungeon and a 1-hour key starts.
- +3 chest at 36:00, +2 at 48:00, +1 at 60:00.
- The clock does NOT stop at 60:00. Overtime shows as +M:SS in red and
  the run is depleted, but the completion time is still recorded.
- Killing the last boss of that dungeon ends the run.
- Personal bests are saved. Party and guild members who also have
  ForeverPlus share bests when you are NOT inside an instance
  (Forever blocks addon messages in dungeons).

Commands
--------
  /fplus            best-times board
  /fplus lock       lock / unlock the timer frame
  /fplus reset      restart the current key at 60:00
  /fplus complete   force-complete (unknown last bosses, e.g. Shaper's Terrace)
  /fplus abandon    drop the current key without saving
  /fplus times      print personal bests
  /fplus share      push times to party/guild (open world only)
  /fplus demo       fake a Deadmines key ~35 minutes in

UI
--
Drag the timer. Right-click it (or the minimap button) for the board.
Minimap button: left-click toggles the timer, right-click opens times.

Last bosses
-----------
Vanilla last bosses plus Forever's published ones (Durgen Dirgehammer,
Rath'mael, Relic Guardian, Shade of the Archmage, Min'loth, Overlord Mugg,
Blazeroar, Varrox Bleakhoof). Cookie / rares do not count.
Shaper's Terrace has no published last boss yet — /fplus complete.
