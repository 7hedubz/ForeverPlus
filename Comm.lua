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

-- Abandon voting is independent of PB synchronization above. Only an explicit
-- Request sends discovery; unlike PB traffic, voting attempts PARTY in instances.
-- Transport is best-effort: accepted sends do NOT prove delivery or capability.
-- Authentication is current party identity, not cryptography. Partial delivery
-- cannot provide atomic abandon across clients; every client fails closed on its
-- own rejected sends and requires all snapshot YES votes witnessed locally.
do
    local VP = "FPAbandonV1" -- own <=16-byte prefix; protocol version 1
    local Vote, state = {}, nil
    ns.Vote = Vote
    local serial, nextRequest, receipts, receiptCount = 0, 0, {}, 0
    local Poll
    local function Secret(v)
        if ns.IsSecret then return ns.IsSecret(v) end
        if not issecretvalue then return false end
        local ok, hidden = pcall(issecretvalue, v)
        return not ok or hidden
    end
    local function Read(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, v = pcall(fn, ...)
        if not ok or Secret(v) then return nil end
        return v
    end
    local function Str(v, max)
        return not Secret(v) and type(v)=="string" and #v>0 and #v<=max
    end
    local function Number(v)
        return not Secret(v) and type(v)=="number" and v==v and v>=0 and v<math.huge
    end
    local function Name(v)
        return Str(v,96) and v:match("^[^|,~%s%z\1-\31\127]+%-[^|,~%s%z\1-\31\127]+$") ~= nil
    end
    local function Now() return Read(GetTime) or 0 end
    local function Live() return state and (state.phase=="discover" or state.phase=="confirm" or state.phase=="vote") end
    local function Terminal(phase, text)
        if not state then return end
        state.phase, state.text, state.canVote = phase, text, false
    end
    local function Run()
        local r=Read(ns.GetRun)
        if type(r)~="table" then return nil end
        local activeRun, complete, practice, key, start, generation
        -- Check secret values before any comparison, indexing, or conversion.
        activeRun=Read(function() return r.active end)
        complete=Read(function() return r.complete end)
        practice=Read(function() return r.practice end)
        key=Read(function() return r.key end)
        start=Read(function() return r.startUnix end)
        generation=Read(function() return r.attemptGeneration end)
        if activeRun~=true or complete==true or not Str(key,64) or not ValidKey(key)
            or not Number(start) then return nil end
        -- Missing optional booleans are normal, but secret optional fields are not.
        if Secret(r.complete) or Secret(r.practice) or Secret(r.attemptGeneration)
            or (generation~=nil and not Number(generation)) then return nil end
        -- Copy the local attempt identity: Reset mutates the same run table and
        -- may retain startUnix. Never compare this generation between clients.
        return {key=key, start=start, practice=practice==true, generation=generation, source=r}
    end
    local function Full(unit)
        local fn=UnitFullName or UnitName
        if type(fn)~="function" then return nil end
        local ok, name, realm=pcall(fn, unit)
        if not ok or Secret(name) or Secret(realm) or not Str(name,96) then return nil end
        if realm==nil or realm=="" then realm=Read(GetNormalizedRealmName) end
        if not Str(realm,96) then return nil end
        local full=name.."-"..realm
        if Name(full) then return full end
    end
    local function Roster()
        local raid=Read(IsInRaid)
        local group=Read(IsInGroup)
        if raid==nil or group==nil or raid==true then return nil end
        local me=Read(ns.PlayerFull)
        if not Name(me) or Full("player")~=me then return nil end
        local list, members={me}, {[me]=true}
        if group then
            local expected=Read(GetNumSubgroupMembers)
            if not Number(expected) or expected<1 or expected>4 or expected~=math.floor(expected) then return nil end
            for i=1,expected do
                local who=Full("party"..i)
                if not who or members[who] then return nil end
                members[who]=true; list[#list+1]=who
            end
        end
        table.sort(list)
        return {me=me, list=list, members=members, signature=table.concat(list,","), grouped=group==true}
    end
    local function Same(a,b) return a and b and a.source==b.source and a.generation==b.generation
        and a.key==b.key and a.start==b.start and a.practice==b.practice end
    local function Context(s, r, roster)
        return Same(s.run,r) and roster and s.roster==roster.signature
    end
    local registered=false
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, result=pcall(C_ChatInfo.RegisterAddonMessagePrefix, VP)
        registered=ok and not Secret(result) and result~=false
    end
    local function Send(kind,id,key,extra)
        local roster=Roster()
        local payload="1|"..kind.."|"..id.."|"..EncodeKey(key)..(extra and "|"..extra or "")
        local ok, result=false, false
        if registered and roster and roster.grouped and #payload<=255
            and C_ChatInfo and C_ChatInfo.SendAddonMessage then
            ok,result=pcall(C_ChatInfo.SendAddonMessage, VP, payload, "PARTY")
        end
        -- WoW's success enum is ZERO, not Lua truthiness. Legacy nil is accepted.
        local success=ok and not Secret(result) and (result==nil or result==true or result==0)
        if not success and Live() then Terminal("failed","Abandon failed: party addon transport rejected; run kept.") end
        return success
    end
    local function NewState(id,r,roster,phase)
        state={id=id,run=r,roster=roster.signature,owner=roster.me,me=roster.me,
            phase=phase,text="Discovering compatible party voters (transport may be restricted)...",
            canVote=false,yes=0,total=1,deadline=Now()+3,responders={},votes={}}
    end
    local function Finish()
        if not Live() or not Context(state,Run(),Roster()) then return end
        if state.phase=="vote" then
            if state.yes~=state.total then return end
            if state.owner==state.me and not Send("R",state.id,state.run.key) then return end
        end
        Terminal("passed","Abandon approved; local run abandoned.")
        -- Mark terminal before calling Core, so reentrant UI/events cannot repeat.
        ns.AbandonRun("vote")
    end
    local function CountYes()
        state.yes=0
        for _,v in ipairs(state.voters) do if state.votes[v] then state.yes=state.yes+1 end end
        state.text="Abandon vote: "..state.yes.."/"..state.total.." yes; unanimous approval required."
    end
    Poll=function()
        local now=Now()
        local roster=Roster()
        -- Keep bounded session replay watermarks even after a member leaves.
        -- Offers, unlike watermarks, die immediately on run/roster changes.
        for _,entry in pairs(receipts) do
            if entry.offer and (now>entry.offer.expires or not Context(entry.offer,Run(),roster)) then entry.offer=nil end
        end
        if not Live() then return end
        if not Context(state,Run(),roster) then Terminal("cancelled","Abandon cancelled: run or party changed."); return end
        if now<state.deadline then return end
        if state.phase~="discover" then Terminal("cancelled","Abandon cancelled: confirmation/vote timed out; run kept."); return end
        local voters={state.me}
        for who in pairs(state.responders) do voters[#voters+1]=who end
        table.sort(voters)
        if #voters==1 then
            state.phase,state.canVote,state.deadline="confirm",true,now+20
            state.text="No compatible peers detected (not proof none exist). Confirm LOCAL ONLY abandon; other runs will not be abandoned."
            return
        end
        state.phase,state.voters,state.total,state.deadline="vote",voters,#voters,now+20
        state.eligible={}; for _,v in ipairs(voters) do state.eligible[v]=true end
        state.votes[state.me]=true; CountYes()
        if not Send("P",state.id,state.run.key,table.concat(voters,",")) then return end
    end
    function Vote.Request()
        Poll()
        local now=Now()
        if Live() or now<nextRequest then return end
        nextRequest=now+5
        local r,roster=Run(),Roster()
        if not r or not roster then
            state={phase="failed",text="Abandon unavailable: no active safe run or party roster (raids unsupported).",canVote=false,yes=0,total=0,deadline=now,id="invalid:"..tostring(now)}
            return
        end
        serial=serial+1
        local wall=Read(time)
        if not Number(wall) then wall=0 end
        local id=roster.me.."~"..string.format("%.0f",wall).."~"..string.format("%.0f",math.floor(now*1000)+serial)
        NewState(id,r,roster,roster.grouped and "discover" or "confirm")
        if not roster.grouped then
            state.text="Confirm LOCAL ONLY abandon of this run?"
            state.canVote,state.deadline=true,now+20
        else Send("H",id,r.key) end
    end
    function Vote.Get()
        Poll()
        if not state then return nil end
        -- Do not expose the mutable protocol state to UI callers.
        return {id=state.id,phase=state.phase,text=state.text,canVote=state.canVote,
            yes=state.yes,total=state.total,deadline=state.deadline}
    end
    function Vote.Cast(yes)
        if Secret(yes) or type(yes)~="boolean" then return end
        Poll()
        if not Live() or not state.canVote then return end
        state.canVote=false
        if state.phase=="confirm" then
            if yes then state.yes=1; Finish()
            else Terminal("cancelled","Local abandon declined; run kept.") end
        elseif state.phase=="vote" then
            if not Send(yes and "Y" or "N",state.id,state.run.key) then return end
            if not yes then Terminal("cancelled","Abandon declined; run kept."); return end
            state.votes[state.me]=true; CountYes(); Finish()
        end
    end
    local function Parse(payload)
        if not Str(payload,255) or payload:find("[%z\1-\31\127]") then return nil end
        local fields={}
        for v in (payload.."|"):gmatch("([^|]*)|") do
            fields[#fields+1]=v; if #fields>5 or #v==0 then return nil end
        end
        if fields[1]~="1" then return nil end
        local kind=fields[2]
        if kind~="H" and kind~="A" and kind~="P" and kind~="Y" and kind~="N" and kind~="R" then return nil end
        if #fields~=(kind=="P" and 5 or 4) or not Str(fields[3],128) then return nil end
        local owner, stamp, counter=fields[3]:match("^([^~]+)~(%d+)~(%d+)$")
        if not Name(owner) or #stamp>12 or #counter>16 then return nil end
        local key=fields[4]:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)
        if not ValidKey(key) or EncodeKey(key)~=fields[4] then return nil end
        return kind,fields[3],key,fields[5],owner,tonumber(stamp),tonumber(counter)
    end
    local function Receive(prefix,payload,channel,sender)
        if not Str(prefix,16) or not Str(channel,16) or not Name(sender) or not Str(payload,255) then return end
        if prefix~=VP or channel~="PARTY" then return end
        Poll()
        local roster,r=Roster(),Run()
        if not roster or not roster.grouped or not roster.members[sender] or sender==roster.me or not r then return end
        local kind,id,key,list,owner,stamp,counter=Parse(payload)
        if not kind or key~=r.key then return end
        local now=Now()
        if kind=="H" then
            if owner~=sender or Live() then return end
            local entry=receipts[sender]
            if entry and (now<entry.at+5 or stamp<entry.stamp or (stamp==entry.stamp and counter<=entry.counter)) then return end
            if not entry then
                -- Refuse new identities at the cap rather than evicting replay
                -- protection. A UI reload starts a new session, not persistence.
                if receiptCount>=32 then return end
                receiptCount=receiptCount+1
            end
            entry={stamp=stamp,counter=counter,at=now}; receipts[sender]=entry
            -- ACK's version 1 / A opcode explicitly advertises voting support.
            if Send("A",id,key) then entry.offer={id=id,run=r,roster=roster.signature,expires=now+8} end
            return -- HELLO never opens a vote prompt.
        end
        if kind=="A" then
            if state and state.phase=="discover" and state.id==id and owner==state.me and state.run.key==key then state.responders[sender]=true end
            return
        end
        if kind=="P" then
            if owner~=sender or Live() then return end
            local entry=receipts[sender]
            local offer=entry and entry.offer
            if not offer or offer.id~=id or not Context(offer,r,roster) or now>offer.expires then return end
            local voters,eligible={},{}
            if not Str(list,255) then return end
            for v in (list..","):gmatch("([^,]*),") do
                if not Name(v) or not roster.members[v] or eligible[v] or #voters>=5 then return end
                voters[#voters+1]=v; eligible[v]=true
            end
            if #voters<2 or not eligible[roster.me] or not eligible[sender] then return end
            entry.offer=nil -- one proposal per acknowledged discovery; no replay prompts
            NewState(id,r,roster,"vote")
            state.owner,state.voters,state.eligible=sender,voters,eligible
            state.total,state.deadline,state.canVote=#voters,now+20,true
            state.votes[sender]=true -- the owner's proposal is its affirmative vote
            CountYes()
            return
        end
        if not state or state.phase~="vote" or id~=state.id or key~=state.run.key
            or owner~=state.owner or not state.eligible[sender] then return end
        if kind=="N" then Terminal("cancelled","Abandon declined by a voter; run kept.")
        elseif kind=="Y" then
            state.votes[sender]=true; CountYes(); Finish()
        elseif kind=="R" and sender==state.owner and state.yes==state.total then
            Finish() -- never trust PASS without all locally witnessed affirmative votes
        end
    end
    local frame=CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent",function(_,event,...)
        if event=="CHAT_MSG_ADDON" then
            local ok=pcall(Receive,...)
            if not ok and Live() then Terminal("failed","Abandon failed: unsafe party input; run kept.") end
        else Poll() end
    end)
    local elapsed=0
    frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=0.1 then elapsed=0; Poll() end
    end)
end
