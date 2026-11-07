-- Standalone Lua 5.1 / LuaJIT multi-client transport harness.
local root = (debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or "./").."../"
local function world(count)
    local w={now=100,clients={},queue={},sent={}}
    for i=1,count do
        local c={name=string.char(64+i).."-Realm",run={active=true,key="rfc",startUnix=1000+i},abandoned=0,frames={},result=0}
        w.clients[i]=c
    end
    for _,c in ipairs(w.clients) do
        local env=setmetatable({}, {__index=_G})
        c.env=env
        env.GetTime=function() return w.now end
        env.time=function() return 100000+math.floor(w.now) end
        env.IsInGroup=function() return #w.clients>1 end
        env.GetNumSubgroupMembers=function() return #w.clients-1 end
        env.IsInRaid=function() return w.raid or false end
        env.IsInInstance=function() return true end
        env.GetNormalizedRealmName=function() return "Realm" end
        env.UnitFullName=function(unit)
            local peer
            if unit=="player" then peer=c else
                local n=tonumber(unit:match("^party(%d)$")); local k=0
                for _,v in ipairs(w.clients) do if v~=c then k=k+1; if k==n then peer=v end end end
            end
            if peer then return peer.name:match("^([^-]+)%-(.+)$") end
        end
        env.UnitName=env.UnitFullName
        env.issecretvalue=function(v) return c.secret~=nil and v==c.secret end
        env.CreateFrame=function()
            local f={scripts={}}; c.frames[#c.frames+1]=f
            function f:RegisterEvent() end
            function f:SetScript(kind,fn) self.scripts[kind]=fn end
            return f
        end
        env.C_ChatInfo={RegisterAddonMessagePrefix=function(p) c.prefix=p; return true end,
            SendAddonMessage=function(prefix,payload,ch)
                assert(ch=="PARTY" and #prefix<=16 and #payload<=255)
                if c.throw then error("restricted") end
                if c.result==0 or c.result==nil or c.result==true then
                    local p={sender=c.name,prefix=prefix,payload=payload,ch=ch}; w.sent[#w.sent+1]=p; w.queue[#w.queue+1]=p
                end
                return c.result
            end}
        env.Enum={SendAddonMessageResult={Success=0}}
        local ns={PlayerFull=function() return c.name end,GetRun=function() return c.run end,
            AbandonRun=function(reason) assert(reason=="vote"); c.abandoned=c.abandoned+1; c.run.active=false end}
        c.ns=ns
        for _,file in ipairs({"Dungeons.lua","Comm.lua"}) do
            local f=assert(loadfile(root..file)); setfenv(f,env); f("ForeverPlus",ns)
        end
        function c.receive(payload,sender,ch,prefix)
            for _,f in ipairs(c.frames) do if f.scripts.OnEvent then f.scripts.OnEvent(f,"CHAT_MSG_ADDON",prefix or c.prefix,payload,ch or "PARTY",sender or "X-Realm") end end
        end
        function c.get() return c.ns.Vote.Get() end
    end
    function w.flush()
        local n=0
        while #w.queue>0 do
            n=n+1; assert(n<100,"message flood")
            local p=table.remove(w.queue,1)
            for _,c in ipairs(w.clients) do if c.name~=p.sender then c.receive(p.payload,p.sender,p.ch,p.prefix) end end
        end
    end
    function w.advance(dt)
        w.now=w.now+dt
        for _,c in ipairs(w.clients) do for _,f in ipairs(c.frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,dt) end end end
        w.flush()
    end
    function w.propose()
        w.clients[1].ns.Vote.Request(); w.flush(); w.advance(3.1); w.flush()
    end
    return w,unpack(w.clients)
end
local tests={}
local function test(name,fn) tests[#tests+1]={name,fn} end
-- Reset mutates the existing run; wall-clock seconds may not advance at all.
local function resetAttempt(c)
    c.run.attemptGeneration=c.run.attemptGeneration+1
    c.run.startGetTime=c.env.GetTime()
end
test("same-second reset during discovery cancels the old attempt",function()
    local w,a,b=world(2)
    a.run.attemptGeneration=1; a.run.startGetTime=w.now
    a.ns.Vote.Request(); w.flush()
    local run,start=a.run,a.run.startUnix
    w.now=w.now+0.1; resetAttempt(a)
    assert(a.run==run and a.run.startUnix==start)
    w.advance(3.1); a.ns.Vote.Cast(true); w.flush()
    assert(a.get().phase=="cancelled" and a.abandoned==0 and a.run.active,
        "old discovery must not authorize abandoning the reset attempt")
end)
test("same-second reset during vote cancels before late YES or cast",function()
    for _,recipient in ipairs({false,true}) do
        local w,a,b=world(2)
        a.run.attemptGeneration=1; b.run.attemptGeneration=7
        w.propose()
        local c=recipient and b or a
        local run,start=c.run,c.run.startUnix
        resetAttempt(c)
        assert(c.run==run and c.run.startUnix==start)
        b.ns.Vote.Cast(true); w.flush(); c.ns.Vote.Cast(true)
        assert(c.get().phase=="cancelled" and c.abandoned==0 and c.run.active,
            "old vote must not abandon the reset attempt")
    end
end)
test("ACK offer before same-second reset cannot authorize a later proposal",function()
    local w,a,b=world(2)
    b.run.attemptGeneration=1
    a.ns.Vote.Request(); w.flush(); assert(not b.get())
    resetAttempt(b)
    w.advance(3.1)
    assert(not b.get(),"stale ACK offer must not open a vote on the reset attempt")
    b.ns.Vote.Cast(true); w.flush()
    assert(b.abandoned==0 and b.run.active)
end)
test("solo requires explicit confirmation and abandons once",function()
    local w,a=world(1)
    assert(a.ns.Vote,"Vote API must be provided")
    a.ns.Vote.Request(); assert(a.get().phase=="confirm" and a.get().canVote and a.abandoned==0)
    a.ns.Vote.Cast(true); a.ns.Vote.Cast(true); assert(a.abandoned==1 and a.get().phase=="passed")
end)
test("three clients require unanimous witnessed yes despite different local start times",function()
    local w,a,b,c=world(3); w.propose()
    assert(a.get().phase=="vote" and a.get().yes==1 and a.get().total==3 and not a.get().canVote)
    assert(b.get().canVote and c.get().canVote)
    b.ns.Vote.Cast(true); w.flush(); assert(a.abandoned+b.abandoned+c.abandoned==0)
    c.ns.Vote.Cast(true); w.flush()
    assert(a.abandoned==1 and b.abandoned==1 and c.abandoned==1)
    for _,p in ipairs(w.sent) do for _,v in ipairs(w.clients) do v.receive(p.payload,p.sender) end end
    assert(a.abandoned==1 and b.abandoned==1 and c.abandoned==1)
end)
test("no declines immediately; timeout never abandons",function()
    local w,a,b,c=world(3); w.propose(); b.ns.Vote.Cast(false); w.flush()
    assert(a.get().phase=="cancelled" and c.get().phase=="cancelled")
    assert(a.abandoned+b.abandoned+c.abandoned==0)
    w,a,b,c=world(3); w.propose(); w.advance(21)
    assert(a.get().phase=="cancelled" and b.get().phase=="cancelled" and a.abandoned==0)
end)
test("run fingerprint and party roster changes cancel before cast",function()
    for _,change in ipairs({"startUnix","key","complete","active","roster"}) do
        local w,a,b,c=world(3); w.propose()
        if change=="roster" then table.remove(w.clients,3)
        elseif change=="startUnix" then b.run.startUnix=999
        elseif change=="key" then b.run.key="dm"
        elseif change=="complete" then b.run.complete=true
        else b.run.active=false end
        b.ns.Vote.Cast(true); assert(b.get().phase=="cancelled" and b.abandoned==0,change)
    end
end)
test("no responders requires clearly labelled local only confirmation",function()
    local w,a,b=world(2); b.run.key="dm"; a.ns.Vote.Request(); w.flush(); w.advance(3.1)
    assert(a.get().phase=="confirm" and a.get().text:lower():find("local only",1,true))
    assert(a.get().text:lower():find("no compatible peers detected",1,true) and a.abandoned==0)
    a.ns.Vote.Cast(true); assert(a.abandoned==1 and b.abandoned==0)
end)
test("send restrictions fail closed, including later YES and result failures",function()
    for _,result in ipairs({false,1,9,"restricted"}) do
        local w,a=world(2); a.result=result; a.ns.Vote.Request(); w.advance(4)
        assert(a.get().phase=="failed" and a.abandoned==0)
        a.ns.Vote.Cast(true); assert(a.abandoned==0)
    end
    local w,a=world(2); a.throw=true; a.ns.Vote.Request(); assert(a.get().phase=="failed")
    local b,c; w,a,b,c=world(3); w.propose(); b.result=false; b.ns.Vote.Cast(true); w.flush()
    assert(b.get().phase=="failed" and b.abandoned==0 and a.abandoned==0)
end)
test("outsiders, nonparty channels, malformed and secret messages cannot prompt or vote",function()
    local w,a,b,c=world(3); a.ns.Vote.Request(); local hello=w.queue[1].payload
    for _,ch in ipairs({"WHISPER","GUILD","RAID"}) do b.receive(hello,a.name,ch); assert(not b.get()) end
    b.receive(hello,"Outsider-Realm"); assert(not b.get())
    for _,s in ipairs({"",string.rep("x",256),"1|P|x|rfc|A-Realm,B-Realm",hello.."|extra","1|H|bad|rfc"}) do b.receive(s,a.name) end
    b.secret=hello; b.receive(hello,a.name); b.secret=nil
    assert(not b.get()); w.flush(); w.advance(3.1)
    local before=a.get().yes
    a.receive("1|Y|"..a.get().id.."|rfc","Outsider-Realm")
    a.receive("1|R|"..a.get().id.."|rfc",b.name)
    a.receive("1|R|"..a.get().id.."|rfc",a.name)
    assert(a.get().yes==before and a.abandoned==0)
end)
test("discovery alone never prompts peers; duplicate request and stale packets bounded",function()
    local w,a,b,c=world(3); a.ns.Vote.Request(); a.ns.Vote.Request(); assert(#w.queue==1)
    w.flush(); assert(not b.get() and not c.get()); w.advance(3.1)
    local packets={}; for i,p in ipairs(w.sent) do packets[i]=p end
    b.ns.Vote.Cast(false); w.flush(); w.advance(30)
    for _,p in ipairs(packets) do b.receive(p.payload,p.sender) end
    assert(b.get().phase=="cancelled" and b.abandoned==0)
end)
test("secret run fields, sender, roster and send result fail closed",function()
    local w,a,b=world(2); a.secret=a.run.key; a.ns.Vote.Request(); assert(not a.get() or a.get().phase=="failed")
    w,a,b=world(2); a.secret=a.result; a.ns.Vote.Request(); assert(a.get().phase=="failed" and a.abandoned==0)
    w,a,b=world(2); a.ns.Vote.Request(); local p=w.queue[1]; b.secret=p.sender; b.receive(p.payload,p.sender); assert(not b.get())
end)
test("invalid recipient list, unsolicited YES, wrong run and old run proposals rejected",function()
    local w,a,b,c=world(3); a.ns.Vote.Request(); w.flush(); w.advance(3.1)
    local id=a.get().id
    a.receive("1|Y|other~1~1|rfc",b.name); assert(a.get().yes==1)
    a.receive("1|Y|"..id.."|dm",b.name); assert(a.get().yes==1)
    local p; for _,v in ipairs(w.sent) do if v.payload:find("1|P|",1,true)==1 then p=v.payload end end
    b.run.startUnix=999; b.receive(p,a.name); assert(b.get().phase=="cancelled")
    local ww,x,y=world(2); x.ns.Vote.Request(); ww.flush()
    local hh=ww.sent[1].payload; local ident=hh:match("^1|H|([^|]+)|")
    for _,list in ipairs({"A-Realm","A-Realm,B-Realm,X-Realm","A-Realm,B-Realm,B-Realm"}) do
        y.receive("1|P|"..ident.."|rfc|"..list,x.name); assert(not y.get())
    end
end)
test("secret roster size never silently removes roster validation",function()
    local w,a=world(3); a.secret=2; a.ns.Vote.Request()
    assert(a.get().phase=="failed" and #w.sent==0)
end)
test("rejoined party cannot replay a prior discovery to reopen a prompt",function()
    local w,a,b,c=world(3); w.propose()
    local packets={}; for i,p in ipairs(w.sent) do packets[i]=p end
    b.ns.Vote.Cast(false); w.flush()
    table.remove(w.clients,1); w.advance(1)
    table.insert(w.clients,1,a); w.advance(8)
    for _,p in ipairs(packets) do if p.sender==a.name then b.receive(p.payload,p.sender) end end
    assert(b.get().phase=="cancelled")
end)
test("five clients, duplicate ballots, proposal and owner result send failures",function()
    local w,a,b,c,d,e=world(5); w.propose(); assert(a.get().total==5)
    b.ns.Vote.Cast(true); b.ns.Vote.Cast(true); w.flush(); assert(a.get().yes==2)
    c.ns.Vote.Cast(true); d.ns.Vote.Cast(true); e.ns.Vote.Cast(true); w.flush()
    for _,v in ipairs(w.clients) do assert(v.abandoned==1) end
    w,a,b=world(2); a.ns.Vote.Request(); w.flush(); a.result=3; w.advance(3.1)
    assert(a.get().phase=="failed" and a.abandoned==0 and not b.get())
    w,a,b=world(2); w.propose(); a.result=3; b.ns.Vote.Cast(true); w.flush()
    assert(a.get().phase=="failed" and a.abandoned==0)
end)
test("HELLO ACK floods bounded; raid refuses and no unsolicited startup sends",function()
    local w,a,b=world(2); assert(#w.sent==0); a.ns.Vote.Request(); local hello=w.sent[1].payload
    for i=1,100 do b.receive(hello,a.name) end
    assert(#w.sent==2)
    w.raid=true; w.advance(1); assert(a.get().phase=="cancelled")
end)
test("oversize proposal fails closed and Get returns defensive state",function()
    local w,a,b,c=world(3)
    for i,v in ipairs(w.clients) do v.name=string.rep(string.char(64+i),70).."-Realm" end
    a.ns.Vote.Request(); w.flush(); local view=a.get(); view.phase="passed"; view.canVote=true
    assert(a.get().phase=="discover" and not a.get().canVote)
    w.advance(3.1); assert(a.get().phase=="failed" and a.abandoned==0)
end)
test("secret fields and Cast cannot bypass local confirmation",function()
    for _,field in ipairs({"startUnix","active","complete","practice"}) do
        local w,a=world(1); a.run[field]={}; a.secret=a.run[field]
        a.ns.Vote.Request(); assert(a.get().phase=="failed" and a.abandoned==0,field)
    end
    local w,a=world(1); a.ns.Vote.Request(); a.secret=true; a.ns.Vote.Cast(true)
    a.secret=nil; assert(a.abandoned==0 and a.get().canVote); w.advance(21)
    assert(a.get().phase=="cancelled" and a.abandoned==0)
end)
test("receipt identities capped without evicting replay protection",function()
    local w,a,b=world(2)
    local first
    for i=1,40 do
        a.name="Peer"..i.."-Realm"; w.now=w.now+6
        local payload="1|H|"..a.name.."~100000~1|rfc"
        first=first or payload; b.receive(payload,a.name)
    end
    assert(#w.sent==32 and not b.get())
    a.name="Peer1-Realm"; w.now=w.now+6; b.receive(first,a.name)
    assert(#w.sent==32)
end)
for _,t in ipairs(tests) do t[2](); print("PASS "..t[1]) end
print("Vote tests: "..#tests.." passed")
