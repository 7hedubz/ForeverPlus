local ADDON, ns = ...

-- Forever (Mainline API) blocks addon messages inside instances.
-- We never send while IsInInstance(); we queue and flush in the open world,
-- using PARTY / RAID / GUILD only.

local Comm = {}
ns.Comm = Comm

local PREFIX = ns.PREFIX
-- All work shares one timer, one active job, and a globally paced stream.
local pending, manual, queryPending = false, false, false
local active, timerPending, initialized = nil, false, false
local nextPacket, lastShare, lastQuery = 0, -math.huge, -math.huge
local replies, querySenders, lastReply = {}, {}, -math.huge
local Pump
local function Wake(delay)
    if timerPending then return end
    timerPending = true
    C_Timer.After(math.max(0, delay or 0), function()
        timerPending = false
        Pump()
    end)
end

local function InInstance()
    return IsInInstance and select(1, IsInInstance()) == true
end

local function Channels()
    local channels = {}
    if IsInRaid and IsInRaid() then channels[#channels + 1] = "RAID"
    elseif IsInGroup and IsInGroup() then channels[#channels + 1] = "PARTY" end
    if IsInGuild and IsInGuild() then channels[#channels + 1] = "GUILD" end
    return channels
end

local function SafeString(value, limit)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "string" and #value > 0 and #value <= limit
end

local function ValidTime(sec)
    return type(sec) == "number" and sec == sec and sec > 0 and sec <= 86400
end

local function ValidKey(key)
    if not SafeString(key, 64) then return false end
    if ns.DUNGEONS and ns.DUNGEONS[key] then return true end
    local id = key:match("^id:([1-9]%d*)$")
    if id then return #id <= 6 and tonumber(id) <= 999999 end
    local name = key:match("^name:(.+)$")
    return name and #name <= 48 and not name:find("[%z\1-\31\127]")
        and name:find("%S") ~= nil and not name:match("^%s") and not name:match("%s$")
end

local function AllowedChannel(channel)
    if channel == "GUILD" then return IsInGuild and IsInGuild() end
    if channel == "RAID" then return IsInRaid and IsInRaid() end
    if channel == "PARTY" then return IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) end
    return false
end

local function PrunePeers()
    local peers, now, owners = ns.DB().peers, time(), {}
    for who, records in pairs(peers) do
        local newest, fallbacks = 0, {}
        if not SafeString(who, 96) or type(records) ~= "table" then
            peers[who] = nil
        else
            for key, b in pairs(records) do
                if type(b) ~= "table" or not ValidKey(key) or not ValidTime(b.sec)
                    or type(b.at) ~= "number" or b.at ~= b.at or b.at > now or b.at < now - 7*86400 then
                    records[key] = nil
                else
                    newest = math.max(newest, b.at)
                    if not ns.DUNGEONS[key] then fallbacks[#fallbacks + 1] = key end
                end
            end
            table.sort(fallbacks)
            for i = 33, #fallbacks do records[fallbacks[i]] = nil end
            if not next(records) then peers[who] = nil else owners[#owners + 1] = {who=who, at=newest} end
        end
    end
    table.sort(owners, function(a,b) if a.at == b.at then return a.who < b.who end return a.at > b.at end)
    for i = 101, #owners do peers[owners[i].who] = nil end
end

local function EncodeKey(key)
    return (key:gsub("([^%w_])", function(c) return string.format("%%%02X", c:byte()) end))
end

local function EncodeBests()
    -- Each B packet stands alone; never split a record or require reassembly.
    local keys, packets = {}, {}
    for key, b in pairs(ns.DB().best) do
        if ValidKey(key) and type(b) == "table" and ValidTime(b.sec) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local packet = "B"
    for _, key in ipairs(keys) do
        local b = ns.DB().best[key]
        local record = EncodeKey(key) .. "=" .. string.format("%.17g:%d", b.sec, ns.ChestForTime(b.sec))
        if #record + 2 <= 240 then
            if #packet + 1 + #record > 240 then packets[#packets + 1] = packet; packet = "B" end
            packet = packet .. "|" .. record
        end
    end
    if packet ~= "B" then packets[#packets + 1] = packet end
    if #packets == 0 then return nil end
    return packets
end

local function Send(payload, channel)
    if InInstance() or not AllowedChannel(channel) or #payload > 240
        or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel)
    if not ok or (issecretvalue and issecretvalue(result)) then return false end
    if result == nil or result == true then return true end -- legacy API
    if type(result) ~= "number" then return false end
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    return result == 0 or (success ~= nil and result == success)
end

local function NewJob(kind, packets, channels, isManual)
    return {kind=kind, packets=packets, channels=channels, part=1, dest=1, manual=isManual, failures=0}
end

Pump = function()
    PrunePeers()
    if InInstance() then return end -- zone/roster events wake the paused queue
    local now = GetTime()
    if now < nextPacket then Wake(nextPacket-now); return end
    local channels = Channels()
    if #channels == 0 then return end -- keep work until membership changes
    if not active then
        if pending and now >= lastShare + 2 then
            local packets = EncodeBests()
            pending = false
            if packets then active = NewJob("share", packets, channels, manual) end
            manual = false
        end
        if not active and queryPending and now >= lastQuery + 8 then
            queryPending = false
            lastQuery = now
            active = NewJob("query", {"Q"}, channels)
        end
        if not active then
            for _, channel in ipairs({"PARTY", "RAID", "GUILD"}) do
                if replies[channel] then
                    replies[channel] = nil
                    if AllowedChannel(channel) then
                        local packets = EncodeBests()
                        if packets then active = NewJob("reply", packets, {channel}) end
                    end
                    if active then break end
                end
            end
        end
    end
    if not active then
        if pending then Wake(math.max(0.25,lastShare+2-now))
        elseif queryPending then Wake(math.max(0.25,lastQuery+8-now)) end
        return
    end
    local job = active
    local channel = job.channels[job.dest]
    if not AllowedChannel(channel) then
        -- A party->raid transition must not leak a stale PARTY packet.
        if job.kind == "share" then pending = true; manual = manual or job.manual
        elseif job.kind == "query" then queryPending = true end
        active = nil
        Wake(0.25)
        return
    end
    if not Send(job.packets[job.part], channel) then
        job.failures = math.min(job.failures + 1, 5)
        nextPacket = now + math.min(30, 2 ^ job.failures)
        Wake(nextPacket-now)
        return -- preserve this exact packet and manual completion status
    end
    job.failures = 0
    nextPacket = now + 0.25 -- at most four packets/sec across ALL jobs/channels
    job.part = job.part + 1
    if job.part > #job.packets then job.part = 1; job.dest = job.dest + 1 end
    if job.dest > #job.channels then
        active = nil
        if job.kind == "share" then
            lastShare = now
            if job.manual and ns.Print then ns.Print("Shared best times with party/raid/guild.") end
        end
    end
    if active or pending or queryPending or next(replies) then Wake(0.25) end
end

function Comm.ShareNow(reason)
    local isManual = reason == "manual" or reason == "button"
    if not EncodeBests() then
        if isManual and ns.Print then ns.Print("No times to share yet.") end
        return
    end
    pending = true
    manual = manual or isManual
    if isManual and ns.Print then
        if InInstance() then ns.Print("Times queued — they'll send after you leave the instance.")
        elseif #Channels() == 0 then ns.Print("No party/raid or guild recipients; times queued.") end
    end
    Wake(0)
end

function Comm.QueueShare()
    pending = true
    Wake(3)
end

function Comm.Query()
    if GetTime() < lastQuery + 8 then return end
    queryPending = true
    Wake(0)
end

local function StorePeer(who, key, sec)
    if not ValidKey(key) or not ValidTime(sec) then return end
    if who == ns.PlayerFull() then return end
    local db = ns.DB()
    db.peers[who] = db.peers[who] or {}
    local prev = db.peers[who][key]
    if prev and ValidTime(prev.sec) and prev.sec <= sec then
        prev.at = time()
        return
    end
    db.peers[who][key] = {sec=sec, chest=ns.ChestForTime(sec), at=time()}
    PrunePeers()
    if ns.UI and ns.UI.RefreshBoard then ns.UI.RefreshBoard() end
end

local function ParseSeconds(token)
    if #token > 32 then return nil end
    local mantissa = token:match("^([%d%.]+)[eE][+-]?%d+$") or token
    if not (mantissa:match("^%d+$") or mantissa:match("^%d+%.%d+$")) then return nil end
    local sec = tonumber(token)
    if ValidTime(sec) then return sec end
end

local function Handle(prefix, text, channel, sender)
    if not SafeString(prefix,16) or not SafeString(text,255) or not SafeString(channel,16)
        or not SafeString(sender,96) then return end
    if prefix ~= PREFIX or not AllowedChannel(channel) then return end
    PrunePeers()
    local me = UnitName("player")
    local short = sender
    if Ambiguate then short = Ambiguate(sender, "short") end
    if short == me or sender == me then return end
    if text == "Q" then
        local now, size = GetTime(), 0
        for who, at in pairs(querySenders) do
            if now-at >= 60 then querySenders[who] = nil else size = size + 1 end
        end
        if querySenders[sender] and now-querySenders[sender] < 30 then return end
        if now-lastReply < 8 or (not querySenders[sender] and size >= 128) then return end
        querySenders[sender], lastReply = now, now
        replies[channel] = true
        Wake(0.4)
        return
    end
    if text:sub(1,2) == "B|" then
        -- B|rfc=123.4:3|dm=400.0:1
        for piece in string.gmatch(text, "([^|]+)") do
            if piece ~= "B" then
                local key, token = piece:match("^([%w_%%]+)=([^:]+):[0-3]$")
                if not key then key, token = piece:match("^([%w_%%]+)=([^:]+)$") end
                local sec = token and ParseSeconds(token)
                if key and sec then
                    local encoded = key
                    key = key:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
                    if EncodeKey(key) == encoded then StorePeer(sender, key, sec) end
                end
            end
        end
    end
end

function Comm.Init()
    if initialized then return end
    initialized = true
    PrunePeers()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    pcall(function() f:RegisterEvent("CHAT_MSG_ADDON_LOGGED") end)
    f:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
        -- Never let malformed or secret addon arguments throw into the UI.
        pcall(Handle, prefix, text, channel, sender)
    end)
    pending, queryPending = true, true
    Wake(5)
end

function Comm.OnZone()
    PrunePeers()
    Comm.Query()
    Wake(0)
end

function Comm.OnRoster()
    pending = true
    if GetTime() >= lastQuery + 8 then queryPending = true end
    Wake(2)
end
