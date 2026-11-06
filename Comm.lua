local ADDON, ns = ...

-- Forever (Mainline API) blocks addon messages inside instances.
-- We never send while IsInInstance(); we queue and flush in the open world,
-- using PARTY / RAID / GUILD only.

local Comm = {}
ns.Comm = Comm

local PREFIX = ns.PREFIX
local pending = false
local lastSend = 0
local lastQuery = 0

local function InInstance()
    local inInst = IsInInstance and select(1, IsInInstance())
    return inInst == true
end

local function CanSend()
    if InInstance() then return false end
    return true
end

local function Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function Send(payload, chatType)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    if not CanSend() then
        pending = true
        return false
    end
    if #payload > 240 then
        payload = payload:sub(1, 240)
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, chatType)
    return ok and result ~= false
end

local function EncodeBests()
    -- B|key=sec:chest|key=sec:chest
    local parts = {"B"}
    local n = 0
    for key, b in pairs(ns.DB().best) do
        if b.sec then
            n = n + 1
            local k = key:gsub("[^%w_]", "_")
            parts[#parts + 1] = string.format("%s=%.1f:%d", k, b.sec, b.chest or ns.ChestForTime(b.sec))
        end
        if #parts > 18 then break end -- stay under 255
    end
    if n == 0 then return nil end
    return table.concat(parts, "|")
end

function Comm.ShareNow(reason)
    if not CanSend() then
        pending = true
        if reason == "manual" or reason == "button" then
            ns.Print("Times queued — they'll send after you leave the instance.")
        end
        return
    end
    local payload = EncodeBests()
    if not payload then
        if reason == "manual" then ns.Print("No times to share yet.") end
        return
    end
    local now = GetTime()
    if now - lastSend < 2 then return end
    lastSend = now

    local ch = Channel()
    if ch then Send(payload, ch) end
    if IsInGuild and IsInGuild() then Send(payload, "GUILD") end
    if reason == "manual" or reason == "button" then
        ns.Print("Shared best times with party/guild.")
    end
    pending = false
end

function Comm.QueueShare()
    pending = true
    C_Timer.After(3, function()
        if pending then Comm.ShareNow("queue") end
    end)
end

function Comm.Query()
    if not CanSend() then return end
    local now = GetTime()
    if now - lastQuery < 8 then return end
    lastQuery = now
    local ch = Channel()
    if ch then Send("Q", ch) end
    if IsInGuild and IsInGuild() then Send("Q", "GUILD") end
end

local function StorePeer(who, key, sec, chest)
    if not who or not key or not sec then return end
    if who == ns.PlayerFull() then return end
    local short = who
    local db = ns.DB()
    db.peers[short] = db.peers[short] or {}
    local prev = db.peers[short][key]
    if prev and prev.sec and prev.sec <= sec then
        return
    end
    db.peers[short][key] = { sec = sec, chest = chest, at = time() }
    if ns.UI and ns.UI.RefreshBoard then
        ns.UI.RefreshBoard()
    end
end

local function Handle(prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    if not text or text == "" then return end
    local me = UnitName("player")
    local short = sender
    if Ambiguate then short = Ambiguate(sender, "short") end
    if short == me or sender == me then return end
    local tag = text:sub(1, 1)
    if tag == "Q" then
        -- Don't recurse: reply with bests only.
        C_Timer.After(0.4 + math.random() * 1.2, function()
            local payload = EncodeBests()
            if payload then
                Send(payload, channel)
            end
        end)
        return
    end
    if tag == "B" then
        -- B|rfc=123.4:3|dm=400.0:1
        for piece in string.gmatch(text, "([^|]+)") do
            if piece ~= "B" then
                local key, sec, chest = piece:match("^([%w_]+)=([%d%.]+):?(%d*)$")
                if key and sec then
                    StorePeer(sender, key, tonumber(sec), tonumber(chest) or 0)
                end
            end
        end
    end
end

function Comm.Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    pcall(function() f:RegisterEvent("CHAT_MSG_ADDON_LOGGED") end)
    f:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
        local ok, err = pcall(Handle, prefix, text, channel, sender)
        if not ok and ns.Print then
            -- swallow; comms must never throw into the UI
        end
    end)
    C_Timer.After(5, function()
        Comm.Query()
        Comm.ShareNow("login")
    end)
end

function Comm.OnZone()
    if CanSend() and pending then
        Comm.ShareNow("leave-instance")
    end
    if CanSend() then
        Comm.Query()
    end
end

function Comm.OnRoster()
    if CanSend() then
        C_Timer.After(2, function()
            Comm.Query()
            Comm.ShareNow("roster")
        end)
    end
end
