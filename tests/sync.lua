-- Run from the addon directory with LuaJIT (Lua 5.1).
local clock, timers, peers, traffic = 0, {}, {}, {}
local function check(ok, msg) assert(ok, msg or 'check failed') end
local function copy(v) if type(v)~='table' then return v end local r={} for k,x in pairs(v) do r[k]=copy(x) end return r end
local function fixture()
 return {id='Player-A:100:1',dungeonKey='rfc',dungeonName='Ragefire Chasm',startUnix=100,endUnix=200,sec=100,chest=3,status='completed',manual=false,recordedBy='Owner-Realm',coverage='observed',players={
 {guid='Player-A',name='Owner-Realm',class='MAGE',damage=1234.5,healing=2,deaths=0},
 {guid='Player-B',name='Friend-Realm',class='PRIEST',damage=3,healing=100,deaths=1}}}
end
local function newPeer(name, records)
 local p={name=name,records=records or {},frames={},sent={},members={'Owner-Realm','Friend-Realm','Third-Realm'},instance=false,failures={},receives=0}
 peers[#peers+1]=p
 local env=setmetatable({}, {__index=_G}); env._G=env
 local ns={}; p.ns=ns
 ns.PlayerFull=function() return p.name end
 ns.Print=function() end
 ns.DB=function() p.db=p.db or {history={}} return p.db end
 env.GetTime=function() return clock end; env.time=function() return 100000+math.floor(clock) end
 env.GetRealmName=function() return 'Realm' end
 env.UnitFullName=function(unit)
  local s=unit=='player' and p.name or ((unit:match('^party%d+$') or unit:match('^raid%d+$')) and p.members[tonumber(unit:match('%d+'))])
  if s then return s:match('^([^-]+)%-(.+)$') end
 end
 env.UnitName=env.UnitFullName
 env.UnitGUID=function(unit) local n=env.UnitFullName(unit); return n and 'Player-'..n end
 env.IsInInstance=function() return p.instance,'none' end
 env.IsInGroup=function() return #p.members>1 end; env.IsInRaid=function() return p.raid or false end
 env.GetNumGroupMembers=function() return #p.members end
 env.GetNumSubgroupMembers=function() return #p.members end
 env.IsInGuild=function() return p.guild or false end
 env.GetNumGuildMembers=function() return #p.members end
 env.GetGuildRosterInfo=function(i) return p.members[i],nil,nil,nil,nil,nil,nil,nil,true end
 env.C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn,peer=p}; local n=0 for _,t in ipairs(timers) do if t.peer==p then n=n+1 end end p.maxTimers=math.max(p.maxTimers or 0,n) end}
 env.CreateFrame=function() local f={RegisterEvent=function() end,SetScript=function(self,_,fn) self.fn=fn end}; p.frames[#p.frames+1]=f; return f end
 env.Enum={SendAddonMessageResult={Success=0}}
 env.C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) p.prefix=prefix;return true end,SendAddonMessage=function(prefix,text,channel)
  check(not p.instance,'sent inside instance');check(#text<=240,'oversize send');check(channel=='PARTY' or channel=='RAID' or channel=='GUILD','forbidden channel')
  p.sent[#p.sent+1]={text=text,channel=channel,at=clock}; traffic[#traffic+1]={from=p,text=text,channel=channel}
  local failure=table.remove(p.failures,1); if failure=='throw' then error('API failure') elseif failure~=nil and failure~=true then return failure end
  for _,q in ipairs(peers) do if q~=p then q.inbox=q.inbox or {};q.inbox[#q.inbox+1]={prefix,text,channel,p.name} end end
  if p.legacy then return nil end
  if failure==true then return true end
  return p.result==nil and 0 or p.result
 end}
 local H={}
 H.SamePlayer=function(a,b) return type(a)=='string' and type(b)=='string' and a:lower()==b:lower() end
 H.Validate=function(r) if type(r)=='table' and r.id and r.players then return copy(r) end end
 H.ExportFor=function(who) local out={} for _,r in ipairs(p.records) do local me,you=false,false for _,pl in ipairs(r.players) do me=me or H.SamePlayer(pl.name,p.name);you=you or H.SamePlayer(pl.name,who) end if me and you then out[#out+1]=copy(r) end end return out end
 H.Receive=function(r,who) local me,you=false,false for _,pl in ipairs(r.players or {}) do me=me or H.SamePlayer(pl.name,p.name);you=you or H.SamePlayer(pl.name,who) end if not(me and you) then return false end p.receives=p.receives+1 for _,old in ipairs(p.records) do if old.id==r.id then return true end end p.records[#p.records+1]=copy(r);return true end
 ns.History=H; p.env=env
 local history=loadfile('History.lua')
 if history then
  env.ForeverPlusDB={history=copy(p.records)}
  ns.ChestForTime=function(sec) return sec<=1200 and 3 or 0 end
  ns.IsSecret=function(v) return env.issecretvalue and env.issecretvalue(v) end
  setfenv(history,env);history('ForeverPlus',ns)
  local receive=ns.History.Receive
  ns.History.Receive=function(r,who) p.receives=p.receives+1;local result=receive(r,who);p.records=ns.History.List();return result end
  p.records=ns.History.List();p.realHistory=true
 end
 local f=loadfile('RunSync.lua');check(f,'RunSync.lua must implement participant sync');setfenv(f,env);f('ForeverPlus',ns);check(ns.Sync,'missing ns.Sync');ns.Sync.Init();return p
end
local function drain(limit)
 local stop=clock+(limit or 100)
 for iter=1,100000 do
  local delivered=false
  for _,p in ipairs(peers) do local box=p.inbox or {};p.inbox={} for _,msg in ipairs(box) do for _,f in ipairs(p.frames) do f.fn(f,'CHAT_MSG_ADDON',unpack(msg)) end delivered=true end end
  if not delivered then
   table.sort(timers,function(a,b)return a.at<b.at end)
   if not timers[1] or timers[1].at>stop then clock=stop;return end
   local t=table.remove(timers,1);clock=t.at;t.fn()
  end
 end
 error('timer/message explosion')
end
local function reset() clock=0;timers={};peers={};traffic={} end
local function test(name,fn) reset();fn();print('PASS '..name) end

test('owner sync shares past run to later-installed friend, not unrelated third peer',function()
 local owner=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm');local third=newPeer('Third-Realm')
 owner.ns.Sync.Request('manual');drain()
 check(#friend.records==1,'owner click must push a past run to the late installer');check(#third.records==0,'unrelated peer received history')
 check(friend.records[1].players[1].damage==1234.5,'fixed wire fields preserved')
 owner.ns.Sync.Request('manual');drain();check(#friend.records==1,'repeated sync duplicates')
 for _,p in ipairs(peers) do check(p.maxTimers<=1,'more than one timer per peer') end
end)
local function inject(p,text,sender,channel)
 for _,f in ipairs(p.frames) do f.fn(f,'CHAT_MSG_ADDON',p.prefix,text,channel or 'PARTY',sender or 'Friend-Realm') end
end
local function session(p)
 p.ns.Sync.Request('manual');drain(10)
 for _,packet in ipairs(p.sent) do local token=packet.text:match('^H|[^|]+|%*|(%x+)$');if token then return token end end
 error('missing discovery')
end
local function wire(r)
 local a={};local function atom(v) if type(v)=='number' then v=string.format('%.17g',v) end a[#a+1]=#v..':'..v end
 for _,f in ipairs({'id','dungeonKey','dungeonName','startUnix','endUnix','sec','chest','status'}) do atom(r[f]) end
 atom(r.manual and '1' or '0');atom(r.recordedBy);atom(r.coverage);atom(#r.players)
 for _,pl in ipairs(r.players) do for _,f in ipairs({'guid','name','class','damage','healing','deaths'}) do atom(pl[f]) end end
 return table.concat(a)
end
local function pieces(p,token,id,body,size)
 local out={};size=size or 80;local total=math.ceil(#body/size)
 for i=1,total do out[i]='D|Friend-Realm|'..p.name..'|'..token..'|'..id..'|'..i..'|'..total..'|'..body:sub((i-1)*size+1,i*size) end
 return out
end

test('new manual request is not stalled by abandoned partial transfer timer',function()
 local p=newPeer('Owner-Realm');local token=session(p)
 inject(p,pieces(p,token,'abc',wire(fixture()))[1]);local before=#p.sent
 p.ns.Sync.Request('manual');drain(1)
 check(#p.sent>before,'partial cleanup timer stalls manual discovery')
end)
local function upvalue(fn,want,visited)
 visited=visited or {};if visited[fn] then return end;visited[fn]=true
 for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end if name==want then return value end
  if type(value)=='function' then local found=upvalue(value,want,visited);if found then return found end end end
end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end return n end

test('discovery sessions remain bounded over repeated manual requests',function()
 local p=newPeer('Owner-Realm')
 for i=1,200 do p.ns.Sync.Request('manual');drain(8.1) end
 check(count(upvalue(p.ns.Sync.Request,'sessions'))<=128,'outbound discovery sessions exceed bound')
end)
test('malformed-transfer replay cache remains bounded',function()
 local p=newPeer('Owner-Realm');local token=session(p)
 for i=1,2200 do
  local id=string.format('%x',i)
  inject(p,'D|Friend-Realm|Owner-Realm|'..token..'|'..id..'|1|2|x')
  inject(p,'D|Friend-Realm|Owner-Realm|'..token..'|'..id..'|1|2|y')
 end
 inject(p,'H|Friend-Realm|*|cafe')
 check(count(upvalue(p.frames[1].fn,'seen'))<=2048,'malformed transfers grow replay cache without bound')
end)
test('manual request is coalesced while inside then sends outside',function()
 local p=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm')
 p.instance=true
 for i=1,100 do p.ns.Sync.Request('manual');p.ns.Sync.OnZone() end
 drain(20);check(#p.sent==0,'instance sent data');check(p.ns.Sync.Status():find('outside'),'queued status missing')
 p.instance=false;p.ns.Sync.OnZone();drain(60)
 check(#friend.records==1,'queued request lost');check(p.maxTimers<=1,'timer explosion')
end)
test('bidirectional request pulls records from participant too',function()
 local p=newPeer('Owner-Realm');local friend=newPeer('Friend-Realm',{fixture()})
 p.ns.Sync.Request('manual');drain();check(#p.records==1,'initiator did not pull')
 check(p.records[1].recordedBy=='Owner-Realm','observer rewritten')
end)
test('numeric errors and thrown sends retain exact packet and back off',function()
 local p=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm')
 p.failures={4,'throw',true};p.ns.Sync.Request('manual');drain()
 check(#friend.records==1,'failed packet not retried')
 check(p.sent[1].text==p.sent[2].text and p.sent[2].text==p.sent[3].text,'failed send advanced packet')
 check(p.sent[2].at-p.sent[1].at>=2 and p.sent[3].at-p.sent[2].at>=4,'backoff missing')
 for i=2,#p.sent do check(p.sent[i].at-p.sent[i-1].at>=0.249,'packet pace violated') end
 check(p.maxTimers<=1,'retry timers exploded')
end)
test('permanently failing API has a bounded retry budget',function()
 local p=newPeer('Owner-Realm');p.failures={1,1,1,1,1,1,1,1}
 p.ns.Sync.Request('manual');drain(300);check(#p.sent==6,'failure retries not bounded');check(#timers==0,'failure timer never stops')
end)
test('reordered and duplicated chunks reconstruct one fixed record',function()
 local p=newPeer('Owner-Realm');local token=session(p);local parts=pieces(p,token,'aaa',wire(fixture()))
 for i=#parts,1,-1 do inject(p,parts[i]);inject(p,parts[i]) end
 check(#p.records==1,'reordered chunks not reconstructed');check(p.receives==1,'same transfer received twice')
 check(p.records[1].players[2].healing==100 and p.records[1].manual==false,'wire mismatch')
end)
test('missing chunks expire and cannot combine across expiration',function()
 local p=newPeer('Owner-Realm');local token=session(p);local parts=pieces(p,token,'aaa',wire(fixture()))
 inject(p,parts[1]);drain(181)
 for i=2,#parts do inject(p,parts[i]) end
 check(#p.records==0,'expired prefix combined with late suffix')
 for _,packet in ipairs(pieces(p,token,'aab',wire(fixture()))) do inject(p,packet) end
 check(#p.records==1,'fresh transfer failed after expiry')
end)
test('malformed lengths, nonfinite numbers and invalid nested identities fail closed',function()
 local p=newPeer('Owner-Realm');local token=session(p)
 local bodies={'1:x','999:x','return os.execute("bad")',wire(fixture())..'1:x'}
 for _,v in ipairs({'nan','inf','1e309','-1','1e','0/0',' 1','1.2.3'}) do local r=fixture();r.sec=v;bodies[#bodies+1]=wire(r) end
 for _,field in ipairs({'damage','healing','deaths'}) do local r=fixture();r.players[1][field]='1e309';bodies[#bodies+1]=wire(r) end
 for _,who in ipairs({'Friend','Friend-OtherRealm','Third-Realm','Friend-Realm|injected'}) do local r=fixture();r.players[2].name=who;bodies[#bodies+1]=wire(r) end
 for i,body in ipairs(bodies) do for _,packet in ipairs(pieces(p,token,string.format('%x',i),body)) do inject(p,packet) end end
 check(#p.records==0 and p.receives==0,'malformed record reached History.Receive')
end)
test('oversize, invalid chunk indexes, conflicting duplicate and totals reject',function()
 local p=newPeer('Owner-Realm');local token=session(p);local base='D|Friend-Realm|Owner-Realm|'..token..'|'
 inject(p,base..'aaa|1|1|'..string.rep('x',241))
 for _,tail in ipairs({'bbb|0|1|x','bbb|2|1|x','bbb|1|513|x','bbb|1|9999|x','bbb|1.5|2|x'}) do inject(p,base..tail) end
 local parts=pieces(p,token,'ccc',wire(fixture()));inject(p,parts[1]);inject(p,parts[1]..'x')
 for i=2,#parts do inject(p,parts[i]) end
 parts=pieces(p,token,'ddd',wire(fixture()));inject(p,parts[1]);inject(p,(parts[2]:gsub('|2|%d+|','|2|100|',1)))
 for i=2,#parts do inject(p,parts[i]) end
 check(#p.records==0,'malformed chunks accepted')
 check(count(upvalue(p.frames[1].fn,'partials'))<=16,'partial bound exceeded')
end)
test('unrelated targets, sender spoofing and nonmember channels reject',function()
 local p=newPeer('Owner-Realm');local token=session(p);local packets=pieces(p,token,'aaa',wire(fixture()))
 for _,packet in ipairs(packets) do
  inject(p,packet,'Third-Realm');inject(p,packet,'Friend-Elsewhere');inject(p,packet,'Friend-Realm','WHISPER')
  inject(p,packet:gsub('Owner%-Realm','Third-Realm',1));inject(p,packet,'Friend-Realm','GUILD')
 end
 check(p.receives==0,'spoof/nonmember reached import')
 for _,packet in ipairs(packets) do inject(p,packet,'Friend') end
 check(#p.records==1,'unique same-realm short event sender rejected')
end)
test('short sender collision across realms is never resolved as participant',function()
 local p=newPeer('Owner-Realm');p.members={'Owner-Realm','Friend-Realm','Friend-Elsewhere'};p.ns.Sync.OnRoster()
 local token=session(p);local packets=pieces(p,token,'aaa',wire(fixture()))
 for _,packet in ipairs(packets) do inject(p,packet,'Friend') end
 check(p.receives==0,'cross-realm short collision accepted')
 for _,packet in ipairs(packets) do inject(p,packet,'Friend-Realm') end
 check(#p.records==1,'qualified participant rejected')
end)
test('current membership and identity changes invalidate queued work and sessions',function()
 local p=newPeer('Owner-Realm',{fixture()});local token=session(p)
 local packets=pieces(p,token,'aaa',wire(fixture()));inject(p,packets[1])
 p.members={'Owner-Realm','Third-Realm'};p.ns.Sync.OnRoster()
 for i=2,#packets do inject(p,packets[i]) end
 check(p.receives==0,'departed peer completed stale transfer')
 p.members={'Owner-Realm','Friend-Realm','Third-Realm'};p.ns.Sync.OnRoster()
 for _,packet in ipairs(packets) do inject(p,packet) end
 check(p.receives==0,'rejoined member resurrected stale session')
 p.ns.Sync.Request('manual');p.name='Newowner-Realm';p.ns.Sync.OnRoster();drain(20)
 for _,packet in ipairs(p.sent) do if packet.at>10 then check(not packet.text:find('|Owner%-Realm|'),'identity change replayed old sender') end end
end)
test('participant exports are bounded to 500 rows and chunks to 240 bytes',function()
 local p=newPeer('Owner-Realm');p.ns.History.ExportFor=function() local out={} for i=1,510 do local r=fixture();r.id='id:'..i;r.startUnix=1000*i;r.endUnix=r.startUnix+100;out[#out+1]=r end return out end
 inject(p,'H|Friend-Realm|*|abc');drain(2000)
 local transfers={};for _,packet in ipairs(p.sent) do check(#packet.text<=240,'oversize');local id=packet.text:match('^D|[^|]+|[^|]+|[^|]+|([^|]+)|');if id then transfers[id]=true end end
 check(count(transfers)==500,'export row bound not honored')
end)
test('partial transfer and response queues remain bounded under floods',function()
 local p=newPeer('Owner-Realm');local token=session(p)
 for i=1,100 do inject(p,'D|Friend-Realm|Owner-Realm|'..token..'|'..string.format('%x',i)..'|1|2|x') end
 check(count(upvalue(p.frames[1].fn,'partials'))==4,'per-peer partial bound missing')
 for i=1,1000 do inject(p,'H|Friend-Realm|*|'..string.format('%x',i)) end
 check(#upvalue(p.ns.Sync.Request,'queue')<=64,'queue bound missing');check(p.maxTimers<=1,'flood exploded timers')
end)
test('restricted or failing roster APIs fail closed without public API errors',function()
 local p=newPeer('Owner-Realm');local token=session(p)
 p.env.UnitFullName=function() error('restricted unit information') end
 check(pcall(p.ns.Sync.OnRoster),'roster hook propagated restricted API failure')
 check(pcall(p.ns.Sync.OnZone),'zone hook propagated restricted API failure')
 local parts=pieces(p,token,'aaa',wire(fixture()));for _,packet in ipairs(parts) do inject(p,packet) end
 check(p.receives==0,'stale roster used after failed refresh')
end)
test('raid channel sends only on current raid membership',function()
 local p=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm')
 for _,q in ipairs(peers) do q.raid=true;q.ns.Sync.OnRoster() end
 p.ns.Sync.Request('manual');drain();check(#friend.records==1,'raid synchronization failed')
 for _,packet in ipairs(traffic) do check(packet.channel=='RAID','party packet after raid change') end
end)
test('guild sync uses only online guild roster membership',function()
 local p=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm')
 for _,q in ipairs(peers) do q.guild=true;q.env.IsInGroup=function() return false end;q.ns.Sync.OnRoster() end
 p.ns.Sync.Request('manual');drain();check(#friend.records==1,'guild synchronization failed')
 for _,packet in ipairs(traffic) do check(packet.channel=='GUILD','wrong guild channel') end
 local outsider=newPeer('Third-Realm');outsider.guild=true;outsider.env.IsInGroup=function() return false end
 outsider.members={'Third-Realm','Friend-Realm'};outsider.ns.Sync.OnRoster()
 local before=#outsider.sent;inject(outsider,'H|Owner-Realm|*|abc','Owner-Realm','GUILD');drain(1)
 check(#outsider.sent==before,'non-guild sender accepted')
end)
test('missing recipients preserve request without busy-loop timers',function()
 local p=newPeer('Owner-Realm',{fixture()});p.members={'Owner-Realm'};p.ns.Sync.OnRoster()
 p.ns.Sync.Request('manual');drain(100);check(#p.sent==0 and #timers==0,'no-recipient busy loop')
 local friend=newPeer('Friend-Realm');p.members={'Owner-Realm','Friend-Realm'};p.ns.Sync.OnRoster();drain()
 check(#friend.records==1,'request lost without recipients')
end)
test('enum success and legacy nil success are accepted exactly',function()
 local p=newPeer('Owner-Realm',{fixture()});local friend=newPeer('Friend-Realm')
 p.env.Enum.SendAddonMessageResult.Success=7;p.result=7;friend.legacy=true
 p.ns.Sync.Request('manual');drain();check(#friend.records==1,'documented enum/legacy success rejected')
 check(#p.sent<15,'successful sends retried')
end)
test('largest allowed identities and ten-player records fit the byte budget',function()
 local ownerName=string.rep('A',48)..'-'..string.rep('R',47)
 local friendName=string.rep('B',48)..'-'..string.rep('R',47)
 local r=fixture();r.recordedBy=ownerName;r.players[1].name=ownerName;r.players[2].name=friendName
 for i=3,10 do r.players[i]={guid='Player-'..i,name=string.rep(string.char(64+i),48)..'-'..string.rep('R',47),class='MAGE',damage=1e15,healing=1e15,deaths=100000} end
 r.id=string.rep('i',96);r.dungeonKey=string.rep('k',64);r.dungeonName=string.rep('d',96)
 local p=newPeer(ownerName,{r});local friend=newPeer(friendName)
 for _,q in ipairs(peers) do q.members={ownerName,friendName};q.ns.Sync.OnRoster() end
 p.ns.Sync.Request('manual');drain(180);check(#friend.records==1,'maximum fixed contract record not delivered')
 for _,packet in ipairs(traffic) do check(#packet.text<=240,'max identity oversize send') end
end)
test('actual History fuzzy merge does not sum repeated observer statistics',function()
 local a=fixture();local b=fixture();b.id='Player-B:100:1';b.recordedBy='Friend-Realm';b.players[1].damage=900
 local p=newPeer('Owner-Realm',{a});local friend=newPeer('Friend-Realm',{b})
 check(p.realHistory and friend.realHistory,'real History required for merge test')
 p.ns.Sync.Request('manual');drain();p.ns.Sync.Request('manual');drain()
 check(#p.records==1 and #friend.records==1,'observer runs did not fuzzy merge')
 check(p.records[1].players[1].damage==1234.5 and friend.records[1].players[1].damage==900,'observer totals added or local preference lost')
end)
test('secret instance result is treated as blocked rather than open world',function()
 local p=newPeer('Owner-Realm');p.env.issecretvalue=function(v) return v=='restricted' end
 p.env.IsInInstance=function() return 'restricted' end
 p.ns.Sync.Request('manual');drain(1);check(#p.sent==0,'secret instance flag enabled send')
end)
test('secret membership flags cannot authorize a channel',function()
 local p=newPeer('Owner-Realm');p.env.issecretvalue=function(v) return v=='restricted' end
 p.env.IsInGroup=function() return 'restricted' end
 p.ns.Sync.Request('manual');drain(1);check(#p.sent==0,'secret group flag authorized channel')
end)
test('secret GUID is not stringified during roster refresh',function()
 local p=newPeer('Owner-Realm');local touched=0
 local guid=setmetatable({},{__tostring=function() touched=touched+1;error('secret conversion') end})
 p.env.issecretvalue=function(v) return v==guid end;p.env.UnitGUID=function() return guid end
 p.ns.Sync.OnRoster();check(touched==0,'secret GUID stringified before validation')
 p.ns.Sync.Request('manual');drain(1);check(#p.sent==0,'secret roster did not fail closed')
end)
test('successful import refreshes an existing history board',function()
 local p=newPeer('Owner-Realm');local token=session(p);local refreshes=0
 p.ns.UI={RefreshBoard=function() refreshes=refreshes+1 end}
 for _,packet in ipairs(pieces(p,token,'aaa',wire(fixture()))) do inject(p,packet) end
 check(refreshes==1,'received history is invisible until board is reopened')
end)
test('secret realm is validated before normalization and cannot authorize fallback',function()
 local p=newPeer('Owner-Realm');local touched=0
 local realm=setmetatable({},{__index=function() touched=touched+1;error('secret realm operation') end})
 p.env.issecretvalue=function(v) return v==realm end
 local names=p.env.UnitFullName;p.env.UnitFullName=function(unit) local name=names(unit);return name,'' end
 p.env.GetRealmName=function() return realm end
 p.ns.Sync.OnRoster();check(touched==0,'secret realm normalized before validation')
 p.ns.Sync.Request('manual');drain(1);check(#p.sent==0,'secret realm did not fail closed')
end)
print('Sync tests complete (real History='..tostring(peers[1] and peers[1].realHistory)..')')
