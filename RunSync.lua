local ADDON, ns = ...
-- Independent of legacy personal-best comms. No WHISPER and no in-instance send.
local Sync = {}
ns.Sync = Sync
local PREFIX = 'FPlusRun1'
local initialized, timer, pending = false, false, false
local queue, sessions, partials, seen = {}, {}, {}, {}
local signature, membership, me = nil, {}, nil
local sequence, nextSend, lastRequest = 0, 0, -math.huge
local Pump
local TTL, PART_TTL, MAX_BYTES, MAX_PARTS = 3600, 180, 16384, 512
local function Secret(v) return issecretvalue and issecretvalue(v) end
local function String(v, max, empty)
    return not Secret(v) and type(v)=='string' and #v<=max and (empty or #v>0)
        and not v:find('[%z\1-\31\127]')
end
local function Identity(v)
    return String(v,96) and not v:find('[%s|:]') and v:match('^[^-]+%-.+$')~=nil
end
local function Key(v) return v:lower() end
local function Realm()
    local realm=GetRealmName and GetRealmName()
    if not String(realm,96) then error('restricted realm') end
    return (realm:gsub('%s',''))
end
local function Full(v, realm)
    if not String(v,96) then return nil end
    if not v:find('-',1,true) then v=v..'-'..(realm or Realm()) end
    if Identity(v) then return v end
end
local function Unit(unit)
    local name, realm
    if UnitFullName then name,realm=UnitFullName(unit) elseif UnitName then name,realm=UnitName(unit) end
    if Secret(realm) then return nil end
    return Full(name, type(realm)=='string' and realm~='' and realm:gsub('%s','') or nil)
end
local function Inside()
    if not IsInInstance then return true end
    local ok,value=pcall(IsInInstance)
    return not ok or Secret(value) or type(value)~='boolean' or value
end
local function Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
local function Flag(fn)
    if not fn then return false end
    local value=fn()
    if Secret(value) or type(value)~='boolean' then error('restricted membership') end
    return value
end
local function ReadRoster()
    local localName=Unit('player') or (ns.PlayerFull and Full(ns.PlayerFull()))
    local maps={}
    local function add(map,n) if n then map[Key(n)]=n end end
    if Flag(IsInRaid) then
        maps.RAID={};add(maps.RAID,localName)
        for i=1,math.min(40,GetNumGroupMembers and GetNumGroupMembers() or 0) do add(maps.RAID,Unit('raid'..i)) end
    elseif Flag(IsInGroup) then
        maps.PARTY={};add(maps.PARTY,localName)
        for i=1,math.min(4,GetNumSubgroupMembers and GetNumSubgroupMembers() or 4) do add(maps.PARTY,Unit('party'..i)) end
    end
    if Flag(IsInGuild) then
        maps.GUILD={};add(maps.GUILD,localName)
        for i=1,math.min(1000,GetNumGuildMembers and GetNumGuildMembers() or 0) do
            local name,_,_,_,_,_,_,_,online=GetGuildRosterInfo(i)
            if not Secret(online) and online==true then add(maps.GUILD,Full(name)) end
        end
    end
    local guid=UnitGUID and UnitGUID('player')
    if Secret(guid) then error('restricted identity') end
    local sig={localName or '', String(guid,96,true) and guid or ''}
    for _,ch in ipairs({'PARTY','RAID','GUILD'}) do
        if maps[ch] then sig[#sig+1]=ch;local names={} for n in pairs(maps[ch]) do names[#names+1]=n end table.sort(names)
            for _,n in ipairs(names) do sig[#sig+1]=n end
        end
    end
    local s=table.concat(sig,'|')
    if signature and signature~=s then queue,sessions,partials,seen={},{},{},{} end
    signature,membership,me=s,maps,localName
end
local function Refresh()
    if not pcall(ReadRoster) then
        signature,membership,me=nil,{},nil
        queue,sessions,partials,seen={},{},{},{}
    end
end
local function Peer(channel, sender, declared)
    local map=membership[channel]
    if not map or not Identity(declared) or not map[Key(declared)] or not String(sender,96) then return false end
    if Identity(sender) then return Key(sender)==Key(declared) end
    -- Unqualified event senders may only identify a unique SAME-realm member.
    if sender:find('-',1,true) then return false end
    local match,n=nil,0
    for _,full in pairs(map) do if Key(full:match('^[^-]+'))==Key(sender) then match=full;n=n+1 end end
    return n==1 and Key(match)==Key(declared) and Key(match:match('^[^-]+%-(.+)$'))==Key(Realm())
end
local function Wake(delay)
    if timer then return end
    timer=true
    C_Timer.After(math.max(0,delay or 0),function() timer=false;local ok=pcall(Pump); if not ok then queue={};pending=false end end)
end
local function NewID() sequence=sequence+1;return string.format('%x',sequence)..string.format('%x',math.floor(GetTime()*10)%16777216) end
local function SessionKey(ch,who,token) return ch..'|'..Key(who)..'|'..token end
local function Prune()
    local now=GetTime()
    for k,s in pairs(sessions) do if s.expires<now then sessions[k]=nil end end
    for k,p in pairs(partials) do if p.expires<now then partials[k]=nil end end
    for k,t in pairs(seen) do if t<now then seen[k]=nil end end
end
local function Remember(key, value)
    if not sessions[key] and Count(sessions)>=128 then
        local oldest,expires
        for k,s in pairs(sessions) do if not expires or s.expires<expires then oldest,expires=k,s.expires end end
        sessions[oldest]=nil
    end
    sessions[key]=value
end
local function Mark(key,expires)
    if seen[key] or Count(seen)<2048 then seen[key]=expires end
end
local function Enqueue(job)
    if #queue>=64 then return false end
    job.expires=GetTime()+TTL;job.failures=0;queue[#queue+1]=job;Wake(0);return true
end
local function Number(n,max,integer,positive)
    return not Secret(n) and type(n)=='number' and n==n and n>=0 and n<=max
        and (not integer or n==math.floor(n)) and (not positive or n>0)
end
local function Record(r)
    if Secret(r) or type(r)~='table' then return nil end
    if not String(r.id,96) or not String(r.dungeonKey,64) or not String(r.dungeonName,96)
        or not Number(r.startUnix,1e12,true) or not Number(r.endUnix,1e12,true) or r.endUnix<r.startUnix
        or not Number(r.sec,86400,false,true) or not Number(r.chest,3,true) or Secret(r.manual) or type(r.manual)~='boolean'
        or not Identity(r.recordedBy) or Secret(r.status) or Secret(r.coverage)
        or not ({completed=true,abandoned=true,reset=true})[r.status]
        or not ({observed=true,partial=true,unavailable=true})[r.coverage]
        or Secret(r.players) or type(r.players)~='table' or #r.players<1 or #r.players>10 then return nil end
    local names={}
    for _,p in ipairs(r.players) do
        if Secret(p) or type(p)~='table' or not String(p.guid,96,true) or not Identity(p.name)
            or names[Key(p.name)] or not String(p.class,16,true) or not p.class:match('^[A-Z]*$')
            or not Number(p.damage,1e15) or not Number(p.healing,1e15) or not Number(p.deaths,100000,true) then return nil end
        names[Key(p.name)]=true
    end
    if not names[Key(r.recordedBy)] then return nil end
    return r,names
end
-- Fixed-order, length-prefixed atoms; no Lua source or executable deserialization.
local function Encode(r)
    if not Record(r) then return nil end
    local atoms={}
    local function atom(v) if type(v)=='number' then v=string.format('%.17g',v) end atoms[#atoms+1]=#v..':'..v end
    for _,field in ipairs({'id','dungeonKey','dungeonName','startUnix','endUnix','sec','chest','status'}) do atom(r[field]) end
    atom(r.manual and '1' or '0');atom(r.recordedBy);atom(r.coverage);atom(#r.players)
    for _,p in ipairs(r.players) do for _,f in ipairs({'guid','name','class','damage','healing','deaths'}) do atom(p[f]) end end
    local text=table.concat(atoms);if #text<=MAX_BYTES then return text end
end
local function Decode(text)
    local pos=1
    local function atom()
        local colon=text:find(':',pos,true);if not colon or colon-pos>3 then error('length') end
        local len=text:sub(pos,colon-1);if not len:match('^%d+$') then error('length') end
        len=tonumber(len);if len>96 or colon+len>#text then error('length') end
        local v=text:sub(colon+1,colon+len);pos=colon+len+1;return v
    end
    local function numeric()
        local v=atom();local base=v:match('^([%d%.]+)[eE][+-]?%d+$') or v
        if not (base:match('^%d+$') or base:match('^%d+%.%d+$')) then error('number') end
        return tonumber(v)
    end
    local r={id=atom(),dungeonKey=atom(),dungeonName=atom(),startUnix=numeric(),endUnix=numeric(),sec=numeric(),chest=numeric(),status=atom()}
    local manual=atom();if manual~='0' and manual~='1' then return nil end
    r.manual=manual=='1';r.recordedBy=atom();r.coverage=atom();r.players={}
    local count=numeric();if not Number(count,10,true,true) then return nil end
    for i=1,count do r.players[i]={guid=atom(),name=atom(),class=atom(),damage=numeric(),healing=numeric(),deaths=numeric()} end
    if pos~=#text+1 then return nil end
    return Record(r)
end
local function Export(ch,who,token)
    local ok,records=pcall(ns.History.ExportFor,who)
    if ok and type(records)=='table' and #records>0 then Enqueue({channel=ch,who=who,token=token,records=records,index=1}) end
end
local function NextRecord(job)
    while job.index<=math.min(500,#job.records) do
        local r=job.records[job.index];job.index=job.index+1
        local ok,body=pcall(Encode,r)
        local valid,names=Record(r)
        if ok and body and valid and names[Key(me)] and names[Key(job.who)] then
            local id=NewID()
            -- Reserve three digits each for index and total (MAX_PARTS <= 999).
            local base='D|'..me..'|'..job.who..'|'..job.token..'|'..id..'|'
            local size=240-#base-8
            local total=size>0 and math.ceil(#body/size) or MAX_PARTS+1
            if total<=MAX_PARTS then
                job.packets={};job.part=1
                for i=1,total do job.packets[i]=base..i..'|'..total..'|'..body:sub((i-1)*size+1,i*size) end
                return true
            end
        end
    end
    return false
end
local function Discovery()
    if GetTime()<lastRequest+8 then return false end
    local any=false
    for _,ch in ipairs({'PARTY','RAID','GUILD'}) do
        if membership[ch] and Count(membership[ch])>1 then
            local token=NewID();Remember(SessionKey(ch,'*',token),{expires=GetTime()+TTL,discovery=true})
            Enqueue({channel=ch,packets={'H|'..me..'|*|'..token},part=1});any=true
        end
    end
    if any then lastRequest=GetTime();pending=false end
    return any
end
Pump=function()
    Refresh();Prune()
    if Inside() or not me then return end
    local now=GetTime()
    if now<nextSend then Wake(nextSend-now);return end
    if pending then Discovery() end
    local job=queue[1]
    while job and (job.expires<now or not membership[job.channel] or (job.who and not membership[job.channel][Key(job.who)])) do table.remove(queue,1);job=queue[1] end
    if not job then if pending and next(membership) and now<lastRequest+8 then Wake(lastRequest+8-now) end return end
    if not job.packets and not NextRecord(job) then table.remove(queue,1);Wake(0);return end
    local payload=job.packets[job.part]
    local ok,result=false,nil
    if #payload<=240 and C_ChatInfo and C_ChatInfo.SendAddonMessage then ok,result=pcall(C_ChatInfo.SendAddonMessage,PREFIX,payload,job.channel) end
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    if not ok or Secret(result) or not (result==nil or result==true or (type(result)=='number' and (result==0 or result==success))) then
        job.failures=job.failures+1
        if job.failures>=6 then table.remove(queue,1) end
        nextSend=now+math.min(30,2^job.failures);Wake(nextSend-now);return
    end
    job.failures=0;job.part=job.part+1;nextSend=now+0.25
    if job.part>#job.packets then
        if job.records then job.packets=nil else table.remove(queue,1) end
    end
    if #queue>0 or pending then Wake(0.25) end
end
local function Handle(prefix,text,channel,sender)
    if not String(prefix,16) or prefix~=PREFIX or not String(text,240) or not String(channel,16) or not String(sender,96) then return end
    Refresh();Prune();if Inside() or not me then return end
    local kind,from,target,token,rest=text:match('^([HRD])|([^|]+)|([^|]+)|([^|]+)(.*)$')
    if not kind or not token:match('^%x+$') or #token>24 or not Peer(channel,sender,from) or Key(from)==Key(me) then return end
    local now=GetTime();local sk=SessionKey(channel,from,token)
    if kind=='H' then
        if target~='*' or rest~='' or sessions[sk] or Count(sessions)>=128 then return end
        local rate='H|'..channel..'|'..Key(from)
        if seen[rate] or Count(seen)>=2048 then return end
        seen[rate]=now+8;sessions[sk]={expires=now+TTL}
        Enqueue({channel=channel,who=from,packets={'R|'..me..'|'..from..'|'..token},part=1})
        Export(channel,from,token);return
    end
    if not Identity(target) or Key(target)~=Key(me) then return end
    local session=sessions[sk] or sessions[SessionKey(channel,'*',token)]
    if not session then return end
    if kind=='R' then
        if rest~='' or not session.discovery then return end
        if Count(seen)>=2048 then return end
        local key='R|'..sk;if seen[key] then return end
        seen[key]=now+TTL;Export(channel,from,token);return
    end
    local id,idx,total,piece=rest:match('^|(%x+)|(%d+)|(%d+)|(.*)$')
    if not id or #id>24 or #idx>3 or #total>3 or #piece==0 then return end
    idx,total=tonumber(idx),tonumber(total)
    if idx<1 or total<1 or idx>total or total>MAX_PARTS then return end
    local key=sk..'|'..id
    if seen[key] then return end
    local p=partials[key]
    if not p then
        local n=0;for _,v in pairs(partials) do if v.owner==Key(from) then n=n+1 end end
        if Count(partials)>=16 or n>=4 then return end
        p={owner=Key(from),total=total,parts={},count=0,bytes=0,expires=now+PART_TTL};partials[key]=p
        -- Expire lazily on every event/pump; never reserve the shared send timer
        -- for partial cleanup (which would stall newly requested work).
    end
    if p.total~=total or (p.parts[idx] and p.parts[idx]~=piece) then partials[key]=nil;Mark(key,now+PART_TTL);return end
    if not p.parts[idx] then p.parts[idx]=piece;p.count=p.count+1;p.bytes=p.bytes+#piece end
    if p.bytes>MAX_BYTES then partials[key]=nil;Mark(key,now+PART_TTL);return end
    if p.count==p.total then
        partials[key]=nil;if Count(seen)<2048 then seen[key]=now+TTL end
        local ok,r,names=pcall(Decode,table.concat(p.parts))
        if ok and r and names[Key(me)] and names[Key(from)] then
            local accepted=ns.History.Receive(r,from)
            if accepted and ns.UI and ns.UI.RefreshBoard then ns.UI.RefreshBoard() end
        end
    end
end
function Sync.Init()
    if initialized then return end
    initialized=true;Refresh()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
    local f=CreateFrame('Frame');f:RegisterEvent('CHAT_MSG_ADDON');pcall(f.RegisterEvent,f,'CHAT_MSG_ADDON_LOGGED')
    f:SetScript('OnEvent',function(_,event,...) pcall(Handle,...) end)
end
function Sync.Request(reason) pending=true;Wake(0) end
function Sync.OnZone() Refresh();Wake(0) end
function Sync.OnRoster() Refresh();Wake(0) end
function Sync.Status() if Inside() and pending then return 'Sync queued until outside the instance.' end return (#queue>0 or pending) and 'Sync queued.' or 'Sync idle.' end
