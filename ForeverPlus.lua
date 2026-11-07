local ADDON, ns = ...

ForeverPlusDB = ForeverPlusDB or {}

ns.addon = ADDON
ns.ver = "1.1.1"

local LIMIT = ns.LIMIT
local Secret = ns.IsSecret
local Read = ns.SafeRead
local function Number(v)
    return not Secret(v) and type(v) == "number" and v == v and v > -math.huge and v < math.huge
end
local function Count(v)
    if not Number(v) or v < 0 then return 0 end
    return math.floor(v)
end
local function BoolMap(v)
    if type(v) ~= "table" or Secret(v) then return {} end
    for k, value in pairs(v) do
        if Secret(k) or type(k) ~= "string" or Secret(value) or value ~= true then v[k] = nil end
    end
    return v
end

local function Print(msg)
    local prefix = "|cffd4a017ForeverPlus|r: "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    end
end
ns.Print = Print

local validatedDB
local function DB()
    if Secret(ForeverPlusDB) or type(ForeverPlusDB) ~= "table" then ForeverPlusDB = {} end
    local d = ForeverPlusDB
    if validatedDB == d then return d end
    for _,key in ipairs({"best", "peers", "pos", "minimap"}) do
        if Secret(d[key]) or type(d[key]) ~= "table" then d[key] = {} end
    end
    local function Records(records)
        for key,b in pairs(records) do
            if Secret(key) or type(key) ~= "string" or Secret(b) or type(b) ~= "table" or not Number(b.sec) or b.sec <= 0 then
                records[key] = nil
            else
                b.chest = Number(b.chest) and math.max(0, math.min(3, math.floor(b.chest))) or 0
                for _,field in ipairs({"name", "player"}) do
                    if Secret(b[field]) or type(b[field]) ~= "string" then b[field] = nil end
                end
            end
        end
    end
    Records(d.best)
    for who,records in pairs(d.peers) do
        if Secret(who) or type(who) ~= "string" or Secret(records) or type(records) ~= "table" then
            d.peers[who] = nil
        else Records(records) end
    end
    local points = {CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    if Secret(d.pos.p) or type(d.pos.p) ~= "string" or not points[d.pos.p] then d.pos = {} end
    if d.pos.p then
        if Secret(d.pos.rp) or type(d.pos.rp) ~= "string" or not points[d.pos.rp] then d.pos.rp = d.pos.p end
        if not Number(d.pos.x) then d.pos.x = 0 end
        if not Number(d.pos.y) then d.pos.y = 0 end
    end
    if not Number(d.minimap.angle) then d.minimap.angle = 198 end
    local s = d.currentRun
    if s ~= nil then
        if Secret(s) or type(s) ~= "table" or type(s.key) ~= "string" or Secret(s.key) or not Number(s.startUnix) then
            d.currentRun = nil
        else
            if not Number(s.instanceID) then s.instanceID = nil end
            s.kills, s.deaths = Count(s.kills), Count(s.deaths)
            s.bossDown, s.killSeen, s.killCredit = BoolMap(s.bossDown), BoolMap(s.killSeen), BoolMap(s.killCredit)
            s.confidence = Number(s.confidence) and math.max(0, math.min(3, s.confidence)) or 1
            s.complete = not Secret(s.complete) and s.complete == true
        end
    end
    if Secret(d.locked) or type(d.locked) ~= "boolean" then d.locked = false end
    if Secret(d.showMinimap) or type(d.showMinimap) ~= "boolean" then d.showMinimap = true end
    if d.best then d.best.demo = nil end
    validatedDB = d
    return d
end
ns.DB = DB

local run -- current timed run
local function Persist()
    if not run or run.practice then return end
    DB().currentRun = {
        key=run.key, name=run.name, instanceID=run.instanceID,
        startUnix=run.startUnix, deaths=run.deaths, kills=run.kills,
        bossDown=run.bossDown, killSeen=run.killSeen, killCredit=run.killCredit,
        confidence=run.confidence, complete=run.complete, sec=run.sec, chest=run.chest, history=run.history,
    }
end
local function SameSession(a, b, inst)
    if a.instanceID and inst.instanceID and a.instanceID ~= inst.instanceID then return false end
    if a.key == b.key then return true end
    local old = ns.DungeonByKey(a.key)
    if not old then return false end
    for _,id in ipairs(old.instanceIDs or {}) do
        for _,other in ipairs(b.instanceIDs or {}) do if id == other then return true end end
    end
    return false
end

function ns.GetRun()
    return run
end

local function Now()
    return time()
end

local function Elapsed(r)
    if not r then return 0 end
    if r.complete then return r.sec or 0 end
    if r.paused then
        return r.pausedElapsed or 0
    end
    return math.max(0, GetTime() - (r.startGetTime or GetTime()))
end
ns.Elapsed = Elapsed

local function PlayerFull()
    local name, realm
    if type(UnitFullName) == "function" then
        local ok,a,b = pcall(UnitFullName,"player")
        if ok and not Secret(a) and type(a)=="string" and not Secret(b) then name,realm=a,b end
    end
    name = name or Read(UnitName, "player")
    if type(name) ~= "string" then name = "Player" end
    if name:find("-",1,true) then return name end
    if type(realm) ~= "string" or realm=="" then realm = Read(GetNormalizedRealmName) or Read(GetRealmName) end
    if type(realm) ~= "string" then realm = "" end
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

local SafeInstance = ns.SafeInstance

function ns.StartRun(dungeon, reason)
    if not dungeon then return end
    if run and run.active and run.key == dungeon.key then
        return run
    end
    if run and run.active and ns.History then ns.History.Archive(run,"abandoned",false) end
    -- Leaving and re-entering a fresh instance starts a new key.
    run = {
        active = true,
        complete = false,
        key = dungeon.key,
        name = dungeon.name,
        dungeon = dungeon,
        instanceID = (SafeInstance() or {}).instanceID,
        confidence = select(2, ns.ResolveDungeon()) or 1,
        startUnix = Now(),
        startGetTime = GetTime(),
        deaths = 0,
        reason = reason or "enter",
        practice = dungeon.practice or reason == "demo" or false,
        kills = 0,
        forces = 0,
        bossDown = {},
        killSeen = {},
        killCredit = {},
    }
    if ns.History then ns.History.Start(run) end
    Persist()
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
    if run and run.practice then
        run = nil
        if ns.UI then ns.UI.HideNow() end
        return -- practice never owns the saved real-session marker
    end
    if run and run.complete and not run.practice then
        if ns.UI then ns.UI.HideSoon() end
        return
    end
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
    if ns.History then ns.History.Archive(run,"abandoned",reason=="slash") end
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
    if ns.History then ns.History.Archive(run,"completed",source=="manual") end
    Persist()

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
    if run then return end
    local inst = SafeInstance()
    if not inst or inst.instanceType ~= "party" then return end
    local saved = DB().currentRun
    if not saved or not saved.startUnix then return end
    local dungeon, confidence = ns.ResolveDungeon()
    if not dungeon then return end
    if not SameSession(saved, dungeon, inst) then DB().currentRun = nil; return end
    if (saved.confidence or 1) >= (confidence or 1) then
        dungeon = ns.DungeonByKey(saved.key) or dungeon
    end
    local elapsedUnix = Now() - saved.startUnix
    if not saved.complete and (elapsedUnix < 0 or elapsedUnix > 12 * 3600) then
        DB().currentRun = nil
        return
    end
    run = {
        active = not saved.complete,
        complete = saved.complete or false,
        confidence = saved.confidence or confidence or 1,
        key = dungeon.key,
        name = dungeon.name,
        dungeon = dungeon,
        instanceID = inst.instanceID,
        startUnix = saved.startUnix,
        startGetTime = GetTime() - elapsedUnix,
        deaths = saved.deaths or 0,
        reason = "resume",
        sec = saved.complete and (Number(saved.sec) and math.max(0, saved.sec) or math.max(0, elapsedUnix)) or nil,
        chest = Number(saved.chest) and saved.chest or 0,
        kills = saved.kills or 0,
        bossDown = saved.bossDown or {},
        killSeen = saved.killSeen or {},
        killCredit = saved.killCredit or {},
    }
    if ns.History then ns.History.Resume(run,saved.history) end
    Persist()
    if ns.UI then ns.UI.Show() end
    Print("Resumed key for " .. dungeon.name .. " at " .. ns.FormatTime(elapsedUnix) .. ".")
end

function ns.CheckZone(reason)
    ResumeIfNeeded()
    local inst = SafeInstance()
    if not inst then return end
    if inst.instanceType == "party" then
        local dungeon, confidence = ns.ResolveDungeon()
        if dungeon then
            if run and run.practice then run = nil; ResumeIfNeeded() end
            if run and SameSession(run, dungeon, inst) then
                if not run.complete and (confidence or 1) > (run.confidence or 1) then
                    run.key, run.name, run.dungeon = dungeon.key, dungeon.name, dungeon
                    run.confidence = confidence
                    Persist()
                end
                return
            end
            if run and run.active and ns.History then ns.History.Archive(run,"abandoned",false) end
            run = nil
            DB().currentRun = nil
            ns.StartRun(dungeon, reason)
        end
    else
        -- A real departure ends its session even if a practice overlay is up.
        DB().currentRun = nil
        if run and run.practice then
            return
        end
        if run and run.active and not run.complete then
            ns.AbandonRun(reason or "left")
        elseif run and run.complete then
            run.active = false
            if ns.UI then ns.UI.HideSoon() end
            if ns.Comm then ns.Comm.QueueShare() end
            run = nil
        end
    end
end

local function NpcIdFromGUID(guid)
    if Secret(guid) or type(guid) ~= "string" then return nil end
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
    if Secret(name) or type(name) ~= "string" then name = nil end
    if Secret(guid) then guid = nil end
    if Secret(npcId) then npcId = nil end

    run.killSeen = run.killSeen or {}
    local isNewKill = NpcIdFromGUID(guid) and run.killCredit and run.killCredit[guid] and not run.killSeen[guid]
    if isNewKill then run.killSeen[guid] = true end
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
        run.confidence = 3
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
                run.confidence = 3
            end
        end
    end

    local idx, boss = ns.MatchRequiredBoss(dungeon, npcId, name)
    if boss then run.confidence = 3 end
    if boss and not ns.IsBossMarked(run, boss) then
        ns.MarkBoss(run, boss, npcId, name)
        if DB().currentRun then
            DB().currentRun.bossDown = run.bossDown
        end
        local down, total = ns.CountBossesDown(run)
        Print(string.format("%s down. Bosses %d/%d. Forces %d%%.", boss.n or name or "Boss", down, total, ns.ForcesPercent(run)))
    end

    Persist()
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
        local plates = Read(C_NamePlate.GetNamePlates)
        if type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                local tok = not Secret(plate) and type(plate) == "table" and plate.namePlateUnitToken
                if not Secret(tok) and type(tok) == "string" then units[#units + 1] = tok end
            end
        end
    end
    for i = 1, #units do
        local u = units[i]
        if Read(UnitExists, u) == true then
            local dead = Read(UnitIsDead, u) == true or Read(UnitIsDeadOrGhost, u) == true
            if dead then
                local n = Read(UnitName, u)
                local guid = Read(UnitGUID, u)
                local npcId = NpcIdFromGUID(guid)
                if Read(UnitIsPlayer, u) == false and Read(UnitCanAttack, "player", u) == true then
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
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("BOSS_KILL")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_FLAGS")
f:RegisterEvent("UNIT_PET")
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
        if ns.Sync then ns.Sync.Init() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.4, function()
            ResumeIfNeeded()
            ns.CheckZone(event)
            if ns.Comm then ns.Comm.OnZone() end
            if ns.Sync then ns.Sync.OnZone() end
        end)
        return
    end

    if event == "PLAYER_DEAD" then
        if run and run.active and not run.complete then
            if ns.History and run.history then ns.History.Death(run,Read(UnitGUID,"player"),true)
            else run.deaths = (run.deaths or 0) + 1 end
            if DB().currentRun then DB().currentRun.deaths = run.deaths end
        end
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        local unit = ...
        -- Never query alive state from a death event: the unit API may still be stale.
        if not Secret(unit) and type(unit) == "string" and (unit == "player" or unit:match("^party[1-4]$"))
            and Read(UnitExists,unit) == true and Read(UnitIsDeadOrGhost,unit) == false then
            if ns.History then ns.History.Alive(run,Read(UnitGUID,unit)) end
        end
        return
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if ns.History then ns.History.Alive(run,Read(UnitGUID,"player"),true) end
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        if not Secret(success) and (success == 1 or success == true) then
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

    if event == "UNIT_PET" then
        if ns.History then ns.History.Roster(run,true); Persist() end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if ns.History then ns.History.Roster(run); Persist() end
        if ns.Comm then ns.Comm.OnRoster() end
        if ns.Sync then ns.Sync.OnRoster() end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local result = {pcall(CombatLogGetCurrentEventInfo)}
        local ok = table.remove(result,1)
        if ns.History and run and run.history then
            if ok then ns.History.Observe(run,result) else run.history.coverage="partial" end
            Persist()
        end
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags = unpack(result)
        if not ok or Secret(subevent) or Secret(sourceFlags) or Secret(destFlags) then return end
        if run and run.active and not run.practice and NpcIdFromGUID(destGUID) and type(sourceFlags) == "number" and type(destFlags) == "number" and bit and bit.band then
            local group = bit.band(sourceFlags, 7) ~= 0
            local hostileNPC = bit.band(destFlags, 64) ~= 0 and bit.band(destFlags, 2048) ~= 0
            if group and hostileNPC and (subevent == "PARTY_KILL" or subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT") then
                run.killCredit = run.killCredit or {}
                run.killCredit[destGUID] = true
                Persist()
            end
        end
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
        if run and not run.practice and run.complete then
            local dungeon = run.dungeon
            run = nil; DB().currentRun = nil
            ns.StartRun(dungeon, "reset")
        elseif run and run.active then
            if ns.History then ns.History.Archive(run,"reset",true) end
            run.startGetTime = GetTime()
            run.startUnix = Now()
            run.deaths = 0
            run.kills = 0
            run.forces = 0
            run.bossDown = {}
            run.killSeen = {}
            run.killCredit = {}
            if ns.History then ns.History.Start(run) end
            Persist()
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
    if msg == "sync" then
        if ns.Sync then ns.Sync.Request("manual") end
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
        Print("/fplus lock | reset | complete | abandon | times | share | sync | demo")
        return
    end
    Print("Unknown command. /fplus help")
end

SLASH_FOREVERPLUSDEMO1 = "/demo"
SlashCmdList.FOREVERPLUSDEMO = function()
    ns.ToggleDemo()
end

ns.CoreReady = true
