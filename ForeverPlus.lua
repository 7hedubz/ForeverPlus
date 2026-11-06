local ADDON, ns = ...

ForeverPlusDB = ForeverPlusDB or {}

ns.addon = ADDON
ns.ver = "1.0.0"

local LIMIT = ns.LIMIT
local Secret = function(v)
    return issecretvalue and issecretvalue(v)
end

local function Print(msg)
    local prefix = "|cffd4a017ForeverPlus|r: "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    end
end
ns.Print = Print

local function DB()
    ForeverPlusDB = ForeverPlusDB or {}
    local d = ForeverPlusDB
    d.best = d.best or {}
    d.peers = d.peers or {}
    d.pos = d.pos or {}
    d.minimap = d.minimap or { angle = 198 }
    if d.locked == nil then d.locked = false end
    if d.showMinimap == nil then d.showMinimap = true end
    if d.best then d.best.demo = nil end
    return d
end
ns.DB = DB

local run -- current timed run

function ns.GetRun()
    return run
end

local function Now()
    return time()
end

local function Elapsed(r)
    if not r then return 0 end
    if r.paused then
        return r.pausedElapsed or 0
    end
    return math.max(0, GetTime() - (r.startGetTime or GetTime()))
end
ns.Elapsed = Elapsed

local function PlayerFull()
    local name = UnitName("player") or "Player"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or ""
    realm = realm:gsub("%s+", "")
    if realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end
ns.PlayerFull = PlayerFull

function ns.GetBest(key)
    local b = DB().best[key]
    if b and b.sec then return b end
    return nil
end

function ns.SaveBest(key, sec, chest, dungeonName)
    local d = DB()
    local prev = d.best[key]
    local isNew = (not prev) or (sec < (prev.sec or 1e12))
    if isNew then
        d.best[key] = {
            sec = sec,
            chest = chest,
            at = Now(),
            player = PlayerFull(),
            name = dungeonName,
        }
    elseif prev then
        prev.lastSec = sec
        prev.lastChest = chest
        prev.lastAt = Now()
    end
    return isNew, d.best[key]
end

local function SafeInstance()
    local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = pcall(GetInstanceInfo)
    if not ok then
        return nil, "none"
    end
    if Secret(name) then name = nil end
    if Secret(instanceType) then instanceType = "none" end
    return {
        name = name,
        instanceType = instanceType,
        instanceID = instanceID,
    }
end

function ns.StartRun(dungeon, reason)
    if not dungeon then return end
    if run and run.active and run.key == dungeon.key then
        return run
    end
    -- Leaving and re-entering a fresh instance starts a new key.
    run = {
        active = true,
        complete = false,
        key = dungeon.key,
        name = dungeon.name,
        dungeon = dungeon,
        instanceID = select(8, GetInstanceInfo()),
        startUnix = Now(),
        startGetTime = GetTime(),
        deaths = 0,
        reason = reason or "enter",
        practice = dungeon.practice or reason == "demo" or false,
        kills = 0,
        forces = 0,
        bossDown = {},
        killSeen = {},
    }
    if not run.practice then
        DB().currentRun = {
            key = run.key,
            name = run.name,
            startUnix = run.startUnix,
            instanceID = run.instanceID,
            deaths = 0,
            kills = 0,
            bossDown = {},
        }
    else
        DB().currentRun = nil
    end
    if ns.UI then ns.UI.Show() end
    if not run.practice then
        Print(string.format("Key started: |cffffd100%s|r — 1:00:00. Kill every standard boss and 50 mobs (2%% each) to time it.", run.name))
        if dungeon.manual then
            Print("Boss list is incomplete for this dungeon. Type |cffffd100/fplus complete|r if the tracker can't see a kill.")
        end
    end
    return run
end

function ns.AbandonRun(reason)
    if not run or not run.active then
        run = nil
        DB().currentRun = nil
        if ns.UI then ns.UI.HideSoon() end
        return
    end
    if run.complete then
        run.active = false
        DB().currentRun = nil
        if ns.UI then ns.UI.HideSoon() end
        return
    end
    Print("Key abandoned (" .. (reason or "left instance") .. "). Time not saved.")
    run = nil
    DB().currentRun = nil
    if ns.UI then ns.UI.HideSoon() end
end

function ns.CompleteRun(bossName, source)
    if not run or not run.active or run.complete then
        return
    end
    local sec = Elapsed(run)
    local chest = ns.ChestForTime(sec)
    run.complete = true
    run.active = false
    run.endGetTime = GetTime()
    run.sec = sec
    run.chest = chest
    run.boss = bossName
    DB().currentRun = nil

    local elapsedStr = ns.FormatTime(sec)
    local clock, over = ns.FormatClock(sec, LIMIT)
    local chestTxt
    if chest >= 3 then
        chestTxt = "|cff00ff96+3|r"
    elseif chest == 2 then
        chestTxt = "|cffffd200+2|r"
    elseif chest == 1 then
        chestTxt = "|cffff7d0a+1|r"
    else
        chestTxt = "|cffff2020depleted|r (timer kept running)"
    end

    if run.practice then
        Print(string.format(
            "Practice run |cffffd100%s|r finished in %s  %s. |cffaaaaaaNot saved.|r",
            run.name, elapsedStr, chestTxt
        ))
        if ns.UI then ns.UI.OnComplete(run) end
        return
    end

    local isNew, best = ns.SaveBest(run.key, sec, chest, run.name)

    Print(string.format(
        "Cleared |cffffd100%s|r in |cff00ff96%s|r  %s  via %s.",
        run.name, elapsedStr, chestTxt, bossName or source or "last boss"
    ))
    if over then
        Print("Overtime was " .. clock .. " past the 1-hour deplete line. Time still counts.")
    end
    if isNew then
        Print("|cff00ff96New personal best!|r")
        pcall(function()
            if PlaySound then PlaySound(17316, "Master") end
        end)
    else
        local delta = sec - best.sec
        Print(string.format("Personal best remains %s (%s).", ns.FormatTime(best.sec), delta >= 0 and ("+" .. ns.FormatTime(delta)) or ns.FormatTime(-delta)))
    end

    if ns.UI then ns.UI.OnComplete(run) end
    if ns.Comm then ns.Comm.QueueShare() end
end

local function ResumeIfNeeded()
    local inst = SafeInstance()
    if not inst or inst.instanceType ~= "party" then return end
    local saved = DB().currentRun
    if not saved or not saved.startUnix then return end
    local dungeon = ns.ResolveDungeon()
    if not dungeon then return end
    if saved.key ~= dungeon.key and saved.instanceID ~= inst.instanceID then
        return
    end
    local elapsedUnix = Now() - saved.startUnix
    if elapsedUnix < 0 or elapsedUnix > 12 * 3600 then
        DB().currentRun = nil
        return
    end
    run = {
        active = true,
        complete = false,
        key = dungeon.key,
        name = dungeon.name,
        dungeon = dungeon,
        instanceID = inst.instanceID,
        startUnix = saved.startUnix,
        startGetTime = GetTime() - elapsedUnix,
        deaths = saved.deaths or 0,
        reason = "resume",
        kills = saved.kills or 0,
        bossDown = saved.bossDown or {},
        killSeen = {},
    }
    if ns.UI then ns.UI.Show() end
    Print("Resumed key for " .. dungeon.name .. " at " .. ns.FormatTime(elapsedUnix) .. ".")
end

function ns.CheckZone(reason)
    local inst = SafeInstance()
    if not inst then return end
    if inst.instanceType == "party" then
        local dungeon = ns.ResolveDungeon()
        if dungeon then
            if run and run.practice then
                run = nil
            end
            if run and run.active and not run.complete then
                -- Upgrade wing key if we learned it.
                if run.key ~= dungeon.key then
                    run.key = dungeon.key
                    run.name = dungeon.name
                    run.dungeon = dungeon
                end
                return
            end
            ns.StartRun(dungeon, reason)
        end
    else
        if run and run.practice then
            return
        end
        if run and run.active and not run.complete then
            ns.AbandonRun(reason or "left")
        elseif run and run.complete then
            run.active = false
            if ns.UI then ns.UI.HideSoon() end
            if ns.Comm then ns.Comm.QueueShare() end
        end
    end
end

local function NpcIdFromGUID(guid)
    if type(guid) ~= "string" or Secret(guid) then return nil end
    if not strsplit then return nil end
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcId)
    end
    return nil
end

function ns.OnCreatureDead(guid, npcId, name, source)
    if not run or not run.active or run.complete then
        return
    end
    if run.practice then
        return
    end
    if Secret(name) then name = nil end
    if Secret(guid) then guid = nil end

    run.killSeen = run.killSeen or {}
    local countForces = source ~= "ENCOUNTER_END" and source ~= "BOSS_KILL"
    local isNewKill = countForces
    if guid then
        if run.killSeen[guid] then
            isNewKill = false
        else
            run.killSeen[guid] = true
        end
    elseif not countForces then
        isNewKill = false
    end
    if isNewKill then
        run.kills = (run.kills or 0) + 1
        run.forces = ns.ForcesPercent(run)
        if DB().currentRun then
            DB().currentRun.kills = run.kills
        end
    end

    local dungeon = run.dungeon or ns.DungeonByKey(run.key) or ns.ResolveDungeon()
    local _, viaLast = ns.IsLastBossOf(dungeon, npcId, name)
    if viaLast and ns.DUNGEONS[viaLast] then
        run.key = viaLast
        run.name = ns.DUNGEONS[viaLast].name
        run.dungeon = ns.DUNGEONS[viaLast]
        dungeon = run.dungeon
    else
        local via = ns.KeyFromKill(npcId, name)
        if via and ns.DUNGEONS[via] and via ~= run.key then
            local a, b = dungeon and dungeon.instanceIDs or {}, ns.DUNGEONS[via].instanceIDs or {}
            local sibling = false
            for i = 1, #a do
                for j = 1, #b do
                    if a[i] == b[j] then sibling = true end
                end
            end
            if sibling then
                run.key = via
                run.name = ns.DUNGEONS[via].name
                run.dungeon = ns.DUNGEONS[via]
                dungeon = run.dungeon
            end
        end
    end

    local idx, boss = ns.MatchRequiredBoss(dungeon, npcId, name)
    if boss and not ns.IsBossMarked(run, boss) then
        ns.MarkBoss(run, boss, npcId, name)
        if DB().currentRun then
            DB().currentRun.bossDown = run.bossDown
        end
        local down, total = ns.CountBossesDown(run)
        Print(string.format("%s down. Bosses %d/%d. Forces %d%%.", boss.n or name or "Boss", down, total, ns.ForcesPercent(run)))
    end

    if ns.ObjectivesMet(run) then
        ns.CompleteRun(name or "objectives", source)
    end
end

local function ScanBossUnits()
    if not run or not run.active or run.complete then return end
    local units = {"boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus", "mouseover"}
    for i = 1, 4 do
        units[#units + 1] = "party" .. i .. "target"
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for i = 1, #plates do
                local tok = plates[i].namePlateUnitToken
                if tok then units[#units + 1] = tok end
            end
        end
    end
    for i = 1, #units do
        local u = units[i]
        if UnitExists(u) then
            local dead = UnitIsDead(u) or UnitIsDeadOrGhost(u)
            if dead then
                local n = UnitName(u)
                local guid = UnitGUID(u)
                local npcId = NpcIdFromGUID(guid)
                if UnitIsPlayer and UnitIsPlayer(u) then
                    -- skip
                else
                    ns.OnCreatureDead(guid, npcId, n, u)
                end
                if run and run.complete then return end
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("BOSS_KILL")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(function() f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end)
pcall(function() f:RegisterEvent("ENCOUNTER_START") end)

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        DB()
        return
    end

    if event == "PLAYER_LOGIN" then
        if ns.UI then ns.UI.Init() end
        if ns.Comm then ns.Comm.Init() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.4, function()
            ResumeIfNeeded()
            ns.CheckZone(event)
            if ns.Comm then ns.Comm.OnZone() end
        end)
        return
    end

    if event == "PLAYER_DEAD" then
        if run and run.active and not run.complete then
            run.deaths = (run.deaths or 0) + 1
            if DB().currentRun then DB().currentRun.deaths = run.deaths end
        end
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        if success == 1 or success == true then
            ns.OnCreatureDead(nil, nil, encounterName, "ENCOUNTER_END")
        end
        return
    end

    if event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        ns.OnCreatureDead(nil, nil, encounterName, "BOSS_KILL")
        return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_REGEN_ENABLED" then
        ScanBossUnits()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if ns.Comm then ns.Comm.OnRoster() end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local ok, timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = pcall(CombatLogGetCurrentEventInfo)
        if not ok or Secret(subevent) then return end
        if subevent == "UNIT_DIED" or subevent == "PARTY_KILL" then
            ns.OnCreatureDead(destGUID, NpcIdFromGUID(destGUID), destName, subevent)
        end
        return
    end
end)

-- Smooth timer; also re-scan boss frames in case combat log is locked down.
C_Timer.NewTicker(0.1, function()
    if run and run.active and not run.complete then
        ScanBossUnits()
    end
    if ns.UI then ns.UI.Tick() end
end)

function ns.ToggleDemo()
    if run and run.practice then
        run = nil
        DB().currentRun = nil
        if ns.UI then
            ns.UI.HideNow()
        end
        Print("Demo timer closed. Nothing was saved.")
        return
    end
    if run and run.active and not run.complete then
        Print("A real key is already running. /fplus abandon first if you want the demo.")
        return
    end
    local fake = {
        key = "demo",
        name = "Demo Key",
        lastBosses = {},
        lastNpc = {},
        practice = true,
    }
    ns.StartRun(fake, "demo")
    if run then
        run.practice = true
        run.startGetTime = GetTime() - 2145 -- just inside +3, ~35:45 elapsed
        run.startUnix = Now() - 2145
    end
    Print("Demo timer on (~35:45 elapsed, not saved). /demo again to hide it.")
end

-- Slash
SLASH_FOREVERPLUS1 = "/fplus"
SLASH_FOREVERPLUS2 = "/foreverplus"
SLASH_FOREVERPLUS3 = "/mythicplus"
SlashCmdList.FOREVERPLUS = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or msg == "toggle" then
        if ns.UI then ns.UI.ToggleBoard() end
        return
    end
    if msg == "lock" then
        DB().locked = not DB().locked
        Print(DB().locked and "Frame locked." or "Frame unlocked. Drag the timer.")
        return
    end
    if msg == "reset" then
        if run and run.active then
            run.startGetTime = GetTime()
            run.startUnix = Now()
            run.deaths = 0
            run.kills = 0
            run.forces = 0
            run.bossDown = {}
            run.killSeen = {}
            Print("Timer reset to 1:00:00. Bosses and forces cleared.")
        else
            Print("No active key.")
        end
        return
    end
    if msg == "complete" or msg == "done" then
        if run and run.active then
            ns.CompleteRun("slash command", "manual")
        else
            Print("No active key to complete.")
        end
        return
    end
    if msg == "abandon" then
        ns.AbandonRun("slash")
        return
    end
    if msg == "times" or msg == "best" then
        if ns.UI then ns.UI.ToggleBoard() end
        local n = 0
        Print("Personal bests:")
        for key, d in pairs(ns.DUNGEONS) do
            local b = ns.GetBest(key)
            if b then
                n = n + 1
                Print(string.format("  %s  %s  +%d", d.name, ns.FormatTime(b.sec), b.chest or 0))
            end
        end
        if n == 0 then Print("  none yet") end
        return
    end
    if msg == "share" then
        if ns.Comm then ns.Comm.ShareNow("manual") end
        return
    end
    if msg == "demo" then
        ns.ToggleDemo()
        return
    end
    if msg == "help" then
        Print("/fplus — open best-times board")
        Print("/fplus lock | reset | complete | abandon | times | share | demo")
        return
    end
    Print("Unknown command. /fplus help")
end

SLASH_FOREVERPLUSDEMO1 = "/demo"
SlashCmdList.FOREVERPLUSDEMO = function()
    ns.ToggleDemo()
end

ns.CoreReady = true
