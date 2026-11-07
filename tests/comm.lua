-- Lua 5.1 regression harness; usable from any working directory.
local source = debug.getinfo(1, "S").source:sub(2)
local root = (source:match("^(.*[/\\])") or "./") .. "../"
local function client()
    local c = { now=100, wall=100000, timers={}, sent={}, messages={}, group=true, guild=false, inst=false, result=nil }
    local env = setmetatable({}, {__index=_G})
    local db = {best={}, peers={}}
    local ns = {DB=function() return db end, PlayerFull=function() return "Me-Realm" end,
        Print=function(s) c.messages[#c.messages+1]=s end}
    c.ns, c.db, c.env = ns, db, env
    env.GetTime=function() return c.now end
    env.time=function() return c.wall end
    env.IsInInstance=function() return c.inst end
    env.IsInGroup=function() return c.group end
    env.IsInRaid=function() return c.raid end
    env.IsInGuild=function() return c.guild end
    env.UnitName=function() return "Me" end
    env.Ambiguate=function(s) return s:match("^[^-]+") end
    env.issecretvalue=function(v) return c.secret ~= nil and v == c.secret end
    env.C_Timer={After=function(delay, fn) c.timers[#c.timers+1]={at=c.now+delay,fn=fn} end}
    env.C_ChatInfo={RegisterAddonMessagePrefix=function() end, SendAddonMessage=function(prefix,payload,ch)
        c.sent[#c.sent+1]={payload=payload,channel=ch,at=c.now}
        if c.throw then error("send failed") end
        return c.result
    end}
    env.Enum={SendAddonMessageResult={Success=0}}
    env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) c.event=fn end} end
    assert(loadfile(root.."Dungeons.lua")); local f=assert(loadfile(root.."Dungeons.lua")); setfenv(f,env); f("ForeverPlus",ns)
    f=assert(loadfile(root.."Comm.lua")); setfenv(f,env); f("ForeverPlus",ns)
    function c.advance(seconds)
        local stop=c.now+seconds
        local count=0
        while true do
            local ix, at
            for i,t in ipairs(c.timers) do if t.at<=stop and (not at or t.at<at) then ix,at=i,t.at end end
            if not ix then break end
            local t=table.remove(c.timers,ix); c.wall=c.wall+(t.at-c.now); c.now=t.at; t.fn()
            count=count+1; assert(count<10000,"unbounded timer loop")
        end
        c.wall=c.wall+(stop-c.now); c.now=stop
    end
    function c.init() ns.Comm.Init(); c.advance(6); c.sent={}; c.messages={} end
    function c.receive(text,channel,sender) c.event(nil,"CHAT_MSG_ADDON",ns.PREFIX,text,channel or "PARTY",sender or "Peer-Realm") end
    return c
end
local tests={}
local function test(name,fn) tests[#tests+1]={name,fn} end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

test("whole-record multipart roundtrip covers all 35 plus reversible fallback",function()
    local a,b=client(),client(); a.init(); b.init()
    local n=0
    for key in pairs(a.ns.DUNGEONS) do n=n+1; a.db.best[key]={sec=100+n/10} end
    assert(n==35,"catalog fixture must have 35 dungeons")
    a.db.best["name:the | hidden=wing: 100%"]={sec=145.6}
    a.db.best["id:123456"]={sec=200.2}
    a.ns.Comm.ShareNow("manual"); a.advance(60)
    assert(#a.sent>1,"must split all records, not cap at 18")
    for _,p in ipairs(a.sent) do assert(#p.payload<=240,"packet byte budget"); b.receive(p.payload) end
    assert(count(b.db.peers["Peer-Realm"])==37,"all records survive complete roundtrip")
    for key,v in pairs(a.db.best) do assert(b.db.peers["Peer-Realm"][key].sec==v.sec,"lossless key/time "..key) end
    local c=client(); c.init(); for key,v in pairs(a.db.best) do c.db.best[key]=v end
    c.ns.Comm.ShareNow("manual"); c.advance(60)
    assert(#a.sent==#c.sent)
    for i,p in ipairs(a.sent) do assert(p.payload==c.sent[i].payload,"deterministic packet order") end
end)

test("received times and keys are bounded, chest is derived, local bests preserved",function()
    local c=client(); c.init(); c.db.best.rfc={sec=50}
    c.receive("B|rfc=3000:3|dm=0:3|wc=999999999:3|sfk=1..2:3|unknown=100:3|id%3A0=100:3|name%3A=100:3|id%3A999999999=100:3|name%3A%01bad=100:3")
    local p=c.db.peers["Peer-Realm"]
    assert(p and count(p)==1,"reject invalid times and unknown/malformed fallback keys")
    assert(p.rfc.chest==c.ns.ChestForTime(3000),"never trust remote chest")
    c.receive("B|rfc=4000:0|dm=12.3")
    assert(p.rfc.sec==3000 and p.dm.sec==12.3,"keep faster peer and accept safe old B")
    assert(c.db.best.rfc.sec==50,"never replace own best")
    c.receive("B|wc=100:9|sfk=100:abc|brd=100:1:2|rfc=nan:1")
    assert(not p.wc and not p.sfk and not p.brd,"reject malformed reward syntax")
end)

test("receive channels require matching current membership and secret args are rejected early",function()
    local c=client(); c.init()
    c.receive("B|rfc=10:3","WHISPER"); c.receive("B|rfc=10:3","GUILD")
    c.group=false; c.receive("B|rfc=10:3","PARTY")
    c.group=true; c.receive("B|rfc=10:3","RAID")
    assert(not next(c.db.peers),"no unauthorized channels")
    c.guild=true; c.receive("B|rfc=10:3","GUILD"); assert(c.db.peers["Peer-Realm"].rfc)
    c.raid=true; c.receive("B|dm=10:3","RAID"); assert(c.db.peers["Peer-Realm"].dm)
    c.secret="B|wc=10:3"; c.receive(c.secret,"GUILD")
    assert(not c.db.peers["Peer-Realm"].wc,"secret payload ignored before parsing")
    c.secret="Secret-Realm"; c.receive("B|wc=10:3","GUILD",c.secret)
    assert(not c.db.peers[c.secret],"secret sender ignored")
    c.secret="GUILD"; c.receive("B|wc=10:3",c.secret)
    assert(not c.db.peers["Peer-Realm"].wc,"secret channel ignored")
    c.secret=c.ns.PREFIX; c.receive("B|wc=10:3","PARTY")
    assert(not c.db.peers["Peer-Realm"].wc,"secret prefix ignored")
end)

test("peer data expires and sender and fallback growth stay bounded",function()
    local c=client(); c.init()
    for i=1,500 do c.receive("B|rfc=100:3","PARTY","Peer"..i.."-Realm") end
    assert(count(c.db.peers)<=100,"bounded peer senders")
    for i=1,500 do c.receive("B|id%3A"..i.."=100:3") end
    assert(count(c.db.peers["Peer-Realm"])<=67,"bounded fallback records")
    c.advance(8*86400); c.ns.Comm.OnZone()
    assert(not next(c.db.peers),"expired peers removed even without new data")
end)

test("failed numeric and thrown sends retry with backoff and report success only after delivery",function()
    for _,failure in ipairs({1,7,false,"bad","throw"}) do
        local c=client(); c.init(); c.db.best.rfc={sec=100}; c.result=failure; c.throw=failure=="throw"
        c.ns.Comm.ShareNow("manual"); c.advance(0.5)
        assert(#c.sent==1,"first attempt must happen")
        for _,s in ipairs(c.messages) do assert(not s:find("Shared"),"failure cannot report success") end
        c.advance(5); assert(#c.sent>=2 and #c.sent<=4,"bounded backoff retries")
        c.result=0; c.throw=false; c.advance(60)
        assert(c.messages[#c.messages]:find("Shared"),"queued failure eventually succeeds")
        assert(c.sent[1].payload==c.sent[#c.sent].payload,"failed packet is preserved")
    end
end)

test("no recipients queues and reports honestly, leaving instance flushes without extra request",function()
    local c=client(); c.init(); c.db.best.rfc={sec=100}; c.group=false
    c.ns.Comm.ShareNow("manual"); c.advance(5)
    assert(#c.sent==0 and c.messages[#c.messages]:find("No party"),"no recipients is not a successful share")
    c.inst=true; c.group=true; c.ns.Comm.ShareNow("button"); c.ns.Comm.OnRoster(); c.ns.Comm.Query(); c.advance(20)
    assert(#c.sent==0,"never send inside instance")
    c.inst=false; c.ns.Comm.OnZone(); c.advance(20)
    assert(#c.sent>0,"instance exit flushes pending work")
    local shared=false; for _,s in ipairs(c.messages) do if s:find("Shared") then shared=true end end
    assert(shared,"manual status retained through queue")
end)

test("packet stream is paced and pauses if instance or memberships change mid-flight",function()
    local c=client(); c.init(); c.guild=true
    for key in pairs(c.ns.DUNGEONS) do c.db.best[key]={sec=123.4} end
    c.ns.Comm.ShareNow("manual"); c.advance(0.01); assert(#c.sent==1,"one packet per scheduler tick")
    c.inst=true; local n=#c.sent; c.advance(10); assert(#c.sent==n,"queued stream stops inside instance")
    c.inst=false; c.ns.Comm.OnZone(); c.advance(30)
    for i=2,#c.sent do assert(c.sent[i].at-c.sent[i-1].at>=0.24,"global packet pacing") end
    local d=client(); d.init(); d.db.best.rfc={sec=123}; d.ns.Comm.ShareNow("manual"); d.group=false; d.advance(10)
    assert(#d.sent==0,"membership rechecked before actual send")
end)

test("exact Q only, per-sender plus global query throttle, bounded timers",function()
    local c=client(); c.init(); c.db.best.rfc={sec=100}
    c.receive("Query"); c.receive("Q|junk"); c.receive("Q "); c.advance(3)
    assert(#c.sent==0,"query must be exactly Q")
    for i=1,1000 do c.receive("Q","PARTY","Flood"..i.."-Realm"); c.ns.Comm.OnRoster(); c.ns.Comm.QueueShare() end
    assert(#c.timers<=1,"all scheduled work is coalesced")
    c.advance(10); assert(#c.sent<=6,"global query flood cannot amplify sends")
    local d=client(); d.init(); d.db.best.rfc={sec=100}
    d.receive("Q"); d.advance(2); local n=#d.sent
    for i=1,100 do d.receive("Q") end
    d.advance(5); assert(#d.sent==n,"per-sender query cooldown")
    d.advance(31); d.receive("Q"); d.advance(2); assert(#d.sent>n,"old Q remains supported after cooldown")
end)

test("fractional positive times survive serialization without rounding to zero",function()
    local a,b=client(),client(); a.init(); b.init()
    a.db.best.rfc={sec=0.01}; a.db.best.dm={sec=123.4567}; a.db.best.wc={sec=1e-7}
    a.ns.Comm.ShareNow("manual"); a.advance(5)
    for _,p in ipairs(a.sent) do b.receive(p.payload) end
    assert(b.db.peers["Peer-Realm"] and b.db.peers["Peer-Realm"].rfc,"small positive time must not become zero")
    assert(b.db.peers["Peer-Realm"].dm.sec==123.4567,"fractional time precision retained")
    assert(b.db.peers["Peer-Realm"].wc and b.db.peers["Peer-Realm"].wc.sec==1e-7,"scientific serialization roundtrips")
end)

test("zero, explicit Enum success, and legacy nil succeed; invalid local records never broadcast",function()
    for _,mode in ipairs({"zero","enum","nil","true"}) do
        local c=client(); c.init(); c.db.best.rfc={sec=100}
        if mode=="zero" then c.env.Enum=nil; c.result=0
        elseif mode=="enum" then c.env.Enum.SendAddonMessageResult.Success=8; c.result=8
        elseif mode=="true" then c.result=true end
        c.db.best.unknown={sec=100}; c.db.best.dm={sec=math.huge}; c.db.best.wc={sec=0/0}; c.db.best.sfk={sec=-1}
        c.ns.Comm.ShareNow("manual"); c.advance(5)
        assert(#c.sent==1 and c.messages[#c.messages]:find("Shared"),mode.." success semantics")
        assert(c.sent[1].payload=="B|rfc=100:3" or c.sent[1].payload=="B|rfc=100.0:3","invalid local records excluded")
    end
end)

test("malformed and oversized wire values cannot mutate peer data",function()
    local c=client(); c.init()
    for _,token in ipairs({"0","-1","1e309","1e-999","nan","inf","1..2","1.",".5","0x10","1e","1e+","1e2x"}) do
        c.receive("B|rfc="..token..":3")
    end
    for _,key in ipairs({"unknown","demo","id%3A01","id%3A-1","name%3A%20bad","name%3Abad%20","name%3A"..string.rep("a",49),"name%3Abad%GG","name%3Abad%00","id%3a12"}) do
        c.receive("B|"..key.."=100:3")
    end
    c.receive("Bogus|rfc=100:3"); c.receive("B|rfc=100:3"..string.rep("|",256))
    c.receive({}); c.receive("B|rfc=100:3", "PARTY", {})
    assert(not next(c.db.peers),"all hostile records rejected")
end)

test("multipart failed middle packet resumes without dropping tail or replaying delivered prefix",function()
    local c,b=client(),client(); c.init(); b.init()
    for key in pairs(c.ns.DUNGEONS) do c.db.best[key]={sec=123.4} end
    c.ns.Comm.ShareNow("manual"); c.advance(0.01)
    local first=c.sent[1].payload; c.result=2; c.advance(0.25)
    assert(#c.sent==2 and c.sent[2].payload~=first,"fail after first part delivered")
    local failed=c.sent[2].payload
    c.ns.Comm.QueueShare(); c.result=0; c.advance(1.99)
    assert(c.sent[3] and c.sent[3].payload==failed,"resume exact failing part")
    for _,p in ipairs(c.sent) do b.receive(p.payload) end
    c.advance(30)
    for _,p in ipairs(c.sent) do b.receive(p.payload) end
    assert(count(b.db.peers["Peer-Realm"])==35,"complete multipart tail delivered")
end)

local failures=0
for _,t in ipairs(tests) do local ok,err=pcall(t[2]); if ok then print("PASS "..t[1]) else failures=failures+1; print("FAIL "..t[1]..": "..tostring(err)) end end
assert(failures==0,tostring(failures).." comm test(s) failed")
print(tostring(#tests).." comm tests passed")
