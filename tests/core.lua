-- Run from addon root: luajit tests/core.lua
local root = (arg[0]:match('^(.*)tests/core.lua$') or '')
local tests, passed = {}, 0
local secret = setmetatable({}, {__tostring=function() error('secret tostring') end, __concat=function() error('secret concat') end})
local function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
local function boot(db)
 local s={clock=100, unix=100000, name='Ragefire Chasm', kind='party', id=389, sub='', units={}, registrations={}}
 ForeverPlusDB=db or {}; SlashCmdList={}
 issecretvalue=function(v) return rawequal(v,secret) or rawequal(v,'private-creature-guid') end
 GetTime=function() return s.clock end; time=function() return s.unix end
 LE_PARTY_CATEGORY_INSTANCE=nil;Enum=nil
 IsInGroup=function(category) if category~=nil then return s.instanceGroup==true end return s.group==true end; IsInRaid=function() return s.raid==true end
 SendChatMessage=nil; C_ChatInfo=nil
 UnitFullName=function(u) if u=='player' then return 'Tester','Realm' end local v=s.units[u] or {};return v.name,v.realm or 'Realm' end
 GetNumSubgroupMembers=function() return s.group and 1 or 0 end
 InCombatLockdown=function() return s.combat==true end
 GetInstanceInfo=function() return s.name,s.kind,1,'Normal',5,0,false,s.id end
 GetRealZoneText=function() return s.name end; GetSubZoneText=function() return s.sub end; GetMinimapZoneText=function() return '' end
 UnitName=function(u) if u=='player' then return 'Tester' end return (s.units[u] or {}).name end
 GetRealmName=function() return 'Realm' end; GetNormalizedRealmName=GetRealmName
 UnitExists=function(u) return s.units[u]~=nil end
 UnitIsDead=function(u) return (s.units[u] or {}).dead end; UnitIsDeadOrGhost=UnitIsDead
 UnitGUID=function(u) return (s.units[u] or {}).guid end
 UnitIsPlayer=function(u) return (s.units[u] or {}).player or false end
 UnitCanAttack=function(_,u) return (s.units[u] or {}).hostile end
 UnitIsTapDenied=function(u) local v=(s.units[u] or {}).tapDenied; if v==nil then return false end; return v end
 UnitAffectingCombat=function(u) return (s.units[u] or {}).combat end
 UnitThreatSituation=function(member,u) return ((s.units[u] or {}).threat or {})[member] end
 UnitIsUnit=function(a,b)
  local target=a:match('^(.*)target$')
  if target and s.units[target] then a=s.units[target].targetUnit end
  return a~=nil and s.units[a]~=nil and s.units[b]~=nil and s.units[a].guid==s.units[b].guid
 end
 strsplit=function(delim,str) local t={}; for x in str:gmatch('[^'..delim..']+') do t[#t+1]=x end return unpack(t) end
 bit=require('bit'); COMBATLOG_OBJECT_AFFILIATION_MINE=1; COMBATLOG_OBJECT_AFFILIATION_PARTY=2; COMBATLOG_OBJECT_AFFILIATION_RAID=4
 COMBATLOG_OBJECT_REACTION_HOSTILE=64; COMBATLOG_OBJECT_TYPE_NPC=2048
 CreateFrame=function() local f={}; f.RegisterEvent=function(_,event) s.registrations[event]=true end; f.SetScript=function(_,_,fn) s.event=fn end; return f end
 C_Timer={After=function(_,fn) fn() end,NewTicker=function(_,fn) s.tick=fn end}
 CombatLogGetCurrentEventInfo=function() return unpack(s.cleu) end
 local ns={}; assert(loadfile(root..'Dungeons.lua'))('ForeverPlus',ns); assert(loadfile(root..'ForeverPlus.lua'))('ForeverPlus',ns)
 s.ns=ns
 function s:emit(sub,guid,name,srcFlags,dstFlags)
  self.cleu={1,sub,false,'Player-1','Tester',srcFlags or 1,0,guid,name or 'Trash',dstFlags or 2112,0}
  self.event(nil,'COMBAT_LOG_EVENT_UNFILTERED')
 end
 function s:kill(i) local g='Creature-0-0-0-0-999-'..i; self.event(nil,'PARTY_KILL',secret,secret); return g end
 function s:entry() self.event(nil,'PLAYER_ENTERING_WORLD') end
 return s,ns
end
local function test(name,fn) tests[#tests+1]={name,fn} end
test('next better chest uses inclusive cutoffs and positive ceiling gaps',function()
 local _,n=boot()
 for _,case in ipairs({
  {0,3,nil,0,'+3 is the highest tier'},
  {2160,3,nil,0,'+3 is the highest tier'},
  {2160.001,2,3,1,'0:01 faster for +3'},
  {2880,2,3,720,'12:00 faster for +3'},
  {2880.001,1,2,1,'0:01 faster for +2'},
  {3600,1,2,720,'12:00 faster for +2'},
  {3600.001,0,1,1,'0:01 faster for +1'},
  {2316,2,3,156,'2:36 faster for +3'},
  {2940,1,2,60,'1:00 faster for +2'},
  {3660,0,1,60,'1:00 faster for +1'},
 }) do
  local info=n.NextChestInfo(case[1]);eq(info.chest,case[2]);eq(info.nextChest,case[3]);eq(info.fasterSeconds,case[4]);eq(info.text,case[5])
 end
end)
test('invalid elapsed inputs clamp to zero before comparisons or formatting',function()
 local _,n=boot()
 local guarded=setmetatable({}, {__lt=function() error('secret compare') end,__le=function() error('secret compare') end,__tostring=function() error('secret stringify') end})
 local original=issecretvalue;issecretvalue=function(v) return rawequal(v,guarded) or original(v) end
 for _,v in ipairs({false,'2316',{},secret,guarded,0/0,math.huge,-math.huge,-1}) do
  local info=n.NextChestInfo(v);eq(info.chest,3);eq(info.nextChest,nil);eq(info.fasterSeconds,0);eq(info.text,'+3 is the highest tier')
  eq(n.FormatTime(v),'0:00');eq(n.ChestForTime(v),3)
 end
 eq(n.NextChestInfo(nil).chest,3);eq(n.FormatTime(nil),'0:00');eq(n.ChestForTime(nil),3)
end)
test('completion prints actual unsigned elapsed plus immediately better tier for real and practice runs',function()
 for _,practice in ipairs({false,true}) do
  for _,case in ipairs({{2316,'38:36','2:36 faster for +3'},{2940,'49:00','1:00 faster for +2'},{3660,'1:01:00','1:00 faster for +1'},{2160,'36:00','+3 is the highest tier'}}) do
   local s,n=boot();local messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
   if practice then n.ToggleDemo() else n.StartRun(n.DUNGEONS.rfc) end
   messages={};s.clock=n.GetRun().startGetTime+case[1];n.CompleteRun('manual')
   local out=table.concat(messages,'\n');assert(out:find(case[2],1,true),out);assert(out:find(case[3],1,true),out)
   assert(not out:find('Overtime',1,true));assert(not out:find('Time remaining',1,true));assert(not out:find('+1:00',1,true))
   DEFAULT_CHAT_FRAME=nil
  end
 end
end)
test('attempt generation changes on same-second resets and new attempts only',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local generation=r.attemptGeneration
 assert(type(generation)=='number','new run needs a local attempt generation')
 eq(n.StartRun(n.DUNGEONS.rfc),r);eq(r.attemptGeneration,generation)
 for i=1,2 do
  s.clock=s.clock+0.1;SlashCmdList.FOREVERPLUS('reset')
  eq(n.GetRun(),r);eq(r.startUnix,100000)
  assert(r.attemptGeneration>generation,'same-second reset must advance attempt generation')
  generation=r.attemptGeneration
 end
 n.AbandonRun('slash');r=n.StartRun(n.DUNGEONS.rfc)
 assert(r.attemptGeneration>generation,'new attempt must advance generation')
 local db=ForeverPlusDB;s,n=boot(db);s:entry();r=n.GetRun()
 assert(type(r.attemptGeneration)=='number','resumed run needs a session-local generation')
 generation=r.attemptGeneration;n.CheckZone();eq(r.attemptGeneration,generation)
 SlashCmdList.FOREVERPLUS('reset');assert(r.attemptGeneration>generation)
 s,n=boot();s.name='Scarlet Monastery';s.id=189;n.CheckZone();r=n.GetRun();generation=r.attemptGeneration
 s.sub='Library';n.CheckZone();eq(r.key,'smlib');eq(r.attemptGeneration,generation)
end)
test('history unit fault cannot freeze HUD timer or stop other history units and persistence',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local visited={};local display={}
 n.History={UnitState=function(_,unit) visited[unit]=(visited[unit] or 0)+1;if unit=='player' then error('history|broken\nline') end end}
 n.UI={Tick=function() display.forces=n.FormatForces(r);display.elapsed=n.Elapsed(r) end}
 s.clock=101;s.tick();eq(display.elapsed,1);eq(visited.party4,1)
 s:kill(1);eq(display.forces,'1.2%');eq(ForeverPlusDB.currentRun.nativeCount,1)
 s.clock=102;s.tick();eq(display.elapsed,2);eq(visited.party4,2)
 local health=n.GetRefreshDiagnostics();eq(health.errors,2);eq(health.lastStage,'history:player');eq(health.lastTime,102)
 assert(not health.lastError:find('[|%c]'));health.stages['history:player'].errors=999;health.errors=999
 eq(n.GetRefreshDiagnostics().errors,2);eq(n.GetRefreshDiagnostics().stages['history:player'].errors,2)
end)
test('boss scanner faults never freeze HUD and direct events remain isolated',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local display={};local sends=0
 SendChatMessage=function() sends=sends+1 end
 n.UI={Tick=function() display.forces=n.FormatForces(r);display.elapsed=n.Elapsed(r) end}
 s.units.target={name='Trash',dead=false};n.MatchRequiredBoss=function() error('scan|failure\nline') end
 s.clock=101;s.tick();eq(display.elapsed,1);s:kill(1);eq(display.forces,'1.2%')
 s.event(nil,'UNIT_HEALTH','target');s.event(nil,'PLAYER_TARGET_CHANGED');s.clock=102;s.tick()
 eq(display.elapsed,2);eq(sends,0);eq(n.GetRefreshDiagnostics().stages.bossScan.errors,4)
end)
test('debug reports stored HUD before and after refresh plus secret-safe cumulative faults',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local messages={};local display={forces=37,lastUpdated=90,text='stored HUD'};local args
 n.UI={Tick=function() display={forces=n.ForcesPercent(r),lastUpdated=s.clock,text=n.FormatForces(r)} end,GetDisplayDiagnostics=function() return display end}
 eq(n.SafeRefresh('optional',function(...) args={n=select('#',...),...} end,1,nil,3),true);eq(args.n,3);eq(args[3],3)
 eq(n.SafeRefresh('restricted',function() error(secret) end),false)
 eq(n.GetRefreshDiagnostics().lastError,'restricted error');eq(n.GetRefreshDiagnostics().lastStage,'restricted')
 n.SafeRefresh('object',function() error(setmetatable({},{__tostring=function() error('must not stringify') end})) end)
 eq(n.GetRefreshDiagnostics().lastError,'unavailable error')
 n.SafeRefresh('long',function() error(string.rep('x',200)..'|\n') end)
 assert(#n.GetRefreshDiagnostics().lastError<=160)
 DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 SlashCmdList.FOREVERPLUS('debug');DEFAULT_CHAT_FRAME=nil
 local out=table.concat(messages,'\n');assert(out:find('HUD before refresh: forces 37',1,true),out)
 assert(out:find('HUD after refresh: forces 0',1,true),out);assert(out:find('stored HUD',1,true),out)
 assert(out:find('Refresh health: errors 3',1,true),out);assert(out:find('last stage long',1,true),out)
 n.UI.Tick=function() error(secret) end;s.tick();eq(n.GetRefreshDiagnostics().lastStage,'ui');eq(n.GetRefreshDiagnostics().errors,4)
end)
test('boss deductions immediately refresh HUD even when report UI fails without public sends',function()
 local s,n=boot();s.group=true;s.units.party1={name='Friend',realm='Realm',player=true}
 local r=n.StartRun(n.DUNGEONS.rfc);local display={};local sends=0
 SendChatMessage=function() sends=sends+1 end
 n.UI={Tick=function() display.forces=n.FormatForces(r);display.bosses=n.CountBossesDown(r) end,Show=function() error('report show failed') end,RefreshBossReport=function() error('report failed') end}
 for i=1,4 do s:kill(i) end;eq(display.forces,'4.8%')
 s.event(nil,'BOSS_KILL',101,'Oggleflint');eq(display.forces,'3.6%');eq(display.bosses,1)
 eq(ForeverPlusDB.currentRun.kills,3);eq(sends,0);assert(n.GetPendingBossReport())
 assert(n.GetRefreshDiagnostics().errors>=1)
end)
test('history event faults cannot prevent independent boss scan or later HUD updates',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local display={}
 n.History={UnitState=function() error('history event failure') end}
 n.UI={Tick=function() display.forces=n.FormatForces(r);display.elapsed=n.Elapsed(r) end}
 s.units.target={name='Oggleflint',dead=true,hostile=true}
 s.event(nil,'UNIT_HEALTH','target');eq(n.CountBossesDown(r),1)
 s:kill(1);s:kill(2);eq(display.forces,'1.2%')
 n.History.UnitState=function() error(secret) end
 s.event(nil,'PLAYER_ALIVE');s.event(nil,'PLAYER_UNGHOST');s.clock=105;s.tick();eq(display.elapsed,5)
 assert(n.GetRefreshDiagnostics().errors>=3);eq(n.GetRefreshDiagnostics().lastError,'restricted error')
end)
test('legacy fifty kills resume as sixty percent without reopening completed runs',function()
 for _,complete in ipairs({false,true}) do
  local s,n=boot({currentRun={key='rfc',instanceID=389,startUnix=99900,kills=50,forces=100,complete=complete,sec=75,chest=3,bossDown={}}})
  s:entry();local r=n.GetRun();eq(r.kills,50);eq(r.forcesBaseline,50);eq(n.ForcesPercent(r),60)
  eq(r.complete,complete);eq(r.active,not complete);eq(ForeverPlusDB.currentRun.kills,50)
  if complete then s:kill(1);eq(r.kills,50);eq(n.Elapsed(r),75) else
   s:kill(1);eq(r.kills,51);eq(n.FormatForces(r),'61.2%')
   local db=ForeverPlusDB;s,n=boot(db);s:entry();r=n.GetRun();eq(r.kills,51);eq(n.FormatForces(r),'61.2%')
   SlashCmdList.FOREVERPLUS('reset');eq(r.kills,0);eq(r.nativeCount,0);eq(r.forcesBaseline,0);eq(n.FormatForces(r),'0%')
  end
 end
end)
test('fractional local boss messages and debug do not truncate forces or flood on refresh errors',function()
 local s,n=boot();local messages={};local sends=0
 DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end};SendChatMessage=function() sends=sends+1 end
 local r=n.StartRun(n.DUNGEONS.rfc);for i=1,4 do s:kill(i) end;s.event(nil,'BOSS_KILL',101,'Oggleflint')
 assert(table.concat(messages,'\n'):find('Forces 3.6%',1,true))
 local before=#messages;n.UI={Tick=function() error('broken|refresh\nline') end}
 for i=1,10 do s.clock=s.clock+1;s.tick() end;eq(#messages,before);eq(sends,0)
 SlashCmdList.FOREVERPLUS('debug');assert(table.concat(messages,'\n'):find('Forces 3.6% (3 kills)',1,true))
 DEFAULT_CHAT_FRAME=nil
end)
test('uniform 1.2 percent boundaries apply to every catalog dungeon without exceptions',function()
 local _,catalog=boot();local checked=0
 for key in pairs(catalog.DUNGEONS) do
  local s,n=boot();local d=n.DUNGEONS[key];s.name=d.names[1];s.id=d.instanceIDs[1] or 987
  local r=n.StartRun(d);checked=checked+1
  local expected={[1]={1.2,'1.2%'},[2]={2.4,'2.4%'},[83]={99.6,'99.6%'},[84]={100,'100%'},[85]={100,'100%'}}
  for i=1,85 do
   s:kill(i)
   if expected[i] then assert(math.abs(n.ForcesPercent(r)-expected[i][1])<1e-9,key);eq(n.FormatForces(r),expected[i][2]) end
  end
  eq(r.kills,85);eq(r.complete,false);eq(n.ObjectivesMet(r),false)
 end
 assert(checked>0);print('Uniform catalog rate checked: '..checked..' dungeons')
 eq(catalog.FormatForces(nil),'0%')
end)
test('start message describes eighty four mobs at 1.2 percent',function()
 local _,n=boot();local messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 n.StartRun(n.DUNGEONS.rfc);DEFAULT_CHAT_FRAME=nil
 assert(table.concat(messages,'\n'):find('84 mobs (1.2% each)',1,true))
end)
test('missing global rate uses the same 1.2 percent fallback',function()
 local _,n=boot();n.FORCE_PER_KILL=nil
 eq(n.FormatForces({kills=1}),'1.2%');eq(n.FormatForces({kills=83}),'99.6%');eq(n.FormatForces({kills=84}),'100%')
end)
test('opaque native notifications count without GUID evidence',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 UnitGUID=function() error('native policy must not query GUID') end
 for i=1,24 do s.event(nil,'PARTY_KILL',secret,secret) end
 eq(r.kills,24);eq(n.FormatForces(r),'28.8%')
 s.event(nil,'PARTY_KILL');eq(r.kills,25)
end)
test('only native events increment forces not legacy deaths or scans',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 local g='Creature-0-0-0-0-999-1'
 s:emit('SPELL_DAMAGE',g);s:emit('PARTY_KILL',g);s:emit('UNIT_DIED',g)
 s.units.target={guid=g,name='Trash',dead=false,hostile=true,combat=true,threat={player=2}};s.tick()
 s.units.target.dead=true;s.tick();n.OnCreatureDead(g,999,'Trash','target');eq(r.kills,0);eq(next(r.killCredit),nil)
 s.event(nil,'PARTY_KILL');eq(r.kills,1);s:emit('UNIT_DIED',g);eq(r.kills,1)
end)
test('reset persists canonical state and dedup survives reload',function()
 local s,n=boot(); local r=n.StartRun(n.DUNGEONS.rfc); local g=s:kill(1)
 s.clock=200; s.unix=100100; SlashCmdList.FOREVERPLUS('reset'); eq(ForeverPlusDB.currentRun.startUnix,100100); eq(ForeverPlusDB.currentRun.kills,0)
 s:kill(2); local db=ForeverPlusDB; s,n=boot(db); s.unix=100100; s:entry(); r=n.GetRun(); eq(r.kills,1)
 s:emit('PARTY_KILL','Creature-0-0-0-0-999-2'); eq(r.kills,1)
 local before=r; s:entry(); eq(n.GetRun(),before)
end)
test('completed sentinel survives reload until leave or explicit reset',function()
 local s,n=boot(); n.StartRun(n.DUNGEONS.rfc); n.CompleteRun('test'); n.CheckZone(); eq(n.GetRun().active,false)
 s,n=boot(ForeverPlusDB); s:entry(); assert(not n.GetRun() or not n.GetRun().active)
 SlashCmdList.FOREVERPLUS('reset'); assert(n.GetRun().active)
 n.CompleteRun('test'); s.kind='none'; n.CheckZone(); s.kind='party'; n.CheckZone(); assert(n.GetRun().active)
end)
test('wing confirmation persists and different dungeon cannot replace active run',function()
 local s,n=boot(); s.name='Scarlet Monastery'; s.id=189; n.CheckZone(); local r=n.GetRun()
 n.OnCreatureDead(nil,3974,'Houndmaster Loksey','BOSS_KILL'); eq(r.key,'smlib'); eq(ForeverPlusDB.currentRun.key,'smlib')
 n.CheckZone(); eq(r.key,'smlib'); s,n=boot(ForeverPlusDB); s.name='Scarlet Monastery'; s.id=189; s:entry(); eq(n.GetRun().key,'smlib')
 r=n.GetRun(); s.name='The Deadmines'; s.id=36; n.CheckZone(); eq(n.GetRun(),r); eq(r.key,'smlib'); eq(n.CountBossesDown(r),1)
end)
test('active lifecycle survives death release ghost and every departure without archiving',function()
 local s,n=boot();local archives=0
 local r=n.StartRun(n.DUNGEONS.rfc);n.History={UnitState=function() end, Archive=function() archives=archives+1 end};s:kill(1);s:kill(2);s.event(nil,'BOSS_KILL',101,'Oggleflint')
 local start=r.startUnix;local seen=r.bossDown;local excluded=r.excludedBossKeys
 s.event(nil,'PLAYER_DEAD');s.event(nil,'PLAYER_ALIVE');s.event(nil,'PLAYER_UNGHOST')
 for _,kind in ipairs({'none','raid','pvp','arena','scenario','party'}) do
  s.kind=kind;s.clock=s.clock+10;n.CheckZone('ZONE_CHANGED_NEW_AREA')
  eq(n.GetRun(),r);eq(ForeverPlusDB.currentRun.startUnix,start);eq(r.deaths,1)
  eq(r.kills,1);eq(r.nativeCount,2);eq(r.bossDeductions,1);eq(r.bossDown,seen);eq(r.excludedBossKeys,excluded)
 end
 local api=GetInstanceInfo;GetInstanceInfo=function() error('transient') end;n.CheckZone();eq(n.GetRun(),r);GetInstanceInfo=api
 s.id=36;s.name='The Deadmines';n.CheckZone();eq(n.StartRun(n.DUNGEONS.dm),r)
 eq(r.key,'rfc');eq(n.Elapsed(r),60);eq(archives,0)
end)
test('ongoing reload resumes original dungeon and complete ledger anywhere without age expiry',function()
 for _,where in ipairs({'outside','other','missing','original','unknown'}) do
  local s,n=boot();if where=='unknown' then s.name='Uncatalogued';s.id=987 end
  s.units.player={guid='Player-1',player=true,dead=false}
  assert(loadfile(root..'History.lua'))('ForeverPlus',n)
  local r=n.StartRun(n.ResolveDungeon());s:kill(1);s:kill(2);s.event(nil,'BOSS_KILL',101,'Oggleflint');s.units.player.dead=true;s.event(nil,'PLAYER_DEAD')
  r.history.coverage='partial';local history=r.history;local key=r.key;local confidence=r.confidence
  local db=ForeverPlusDB;s,n=boot(db);assert(loadfile(root..'History.lua'))('ForeverPlus',n);s.unix=200000
  if where=='outside' or where=='unknown' then s.kind='none'
  elseif where=='other' then s.id=36;s.name='The Deadmines'
  elseif where=='missing' then GetInstanceInfo=function() error('transient') end end
  s:entry();r=assert(n.GetRun(),'saved ongoing run must resume '..where)
  eq(r.key,key);eq(r.confidence,confidence);eq(r.instanceID,where=='unknown' and 987 or 389)
  eq(r.startUnix,100000);eq(n.Elapsed(r),100000);eq(r.deaths,1);eq(r.nativeCount,2);eq(r.bossDeductions,1);eq(r.kills,1)
  eq(r.excludedBossKeys['encounter:101'],true);eq(r.history.id,history.id);eq(#n.History.List(),0)
  eq(r.history.players[1].deaths,history.players[1].deaths)
  if where~='unknown' then eq(n.CountBossesDown(r),1) end
 end
end)
test('negative future and nonfinite saved starts are rejected outside',function()
 for _,start in ipairs({-1,100001,math.huge,0/0,'bad'}) do
  local s,n=boot({currentRun={key='rfc',startUnix=start}});s.kind='none';s:entry()
  eq(n.GetRun(),nil);eq(ForeverPlusDB.currentRun,nil)
 end
end)
test('explicit abandonment archives once manually and blocks same-visit autostart across reload',function()
 for _,reason in ipairs({'slash','vote'}) do
  local s,n=boot();s.units.player={guid='Player-1',player=true,dead=false};assert(loadfile(root..'History.lua'))('ForeverPlus',n)
  n.StartRun(n.DUNGEONS.rfc);s.clock=160;s.unix=100060;n.AbandonRun(reason)
  eq(n.GetRun(),nil);eq(ForeverPlusDB.currentRun,nil);eq(#n.History.List(),1)
  eq(n.History.List()[1].manual,true);eq(n.History.List()[1].status,'abandoned')
  n.AbandonRun(reason);n.CheckZone();eq(n.GetRun(),nil);eq(#n.History.List(),1)
  local db=ForeverPlusDB;s,n=boot(db);s:entry();n.CheckZone();eq(n.GetRun(),nil)
  local api=GetInstanceInfo;GetInstanceInfo=function() error('transient') end;n.CheckZone();GetInstanceInfo=api;n.CheckZone();eq(n.GetRun(),nil)
  s.kind='none';n.CheckZone();s.kind='party';n.CheckZone();assert(n.GetRun().active)
 end
end)
test('abandon permits a different dungeon entry and explicit reset in same dungeon',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc);n.AbandonRun('slash');SlashCmdList.FOREVERPLUS('reset');assert(n.GetRun() and n.GetRun().active)
 n.AbandonRun('slash');s.name='The Deadmines';s.id=36;n.CheckZone();eq(n.GetRun().key,'dm')
 n.CompleteRun('test');s.name='Ragefire Chasm';s.id=389;n.CheckZone();eq(n.GetRun().key,'rfc');assert(n.GetRun().active)
end)
test('old zone reasons cannot abandon an active real run',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 for _,reason in ipairs({'left','ZONE_CHANGED_NEW_AREA','PLAYER_ENTERING_WORLD'}) do n.AbandonRun(reason);eq(n.GetRun(),r) end
end)
test('abandoning outside allows the next original entry and practice cannot erase saved real run',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc);s.kind='none';n.CheckZone();n.AbandonRun('slash')
 s.kind='party';n.CheckZone();assert(n.GetRun() and n.GetRun().active,'outside abandon must allow actual reentry')
 local db=ForeverPlusDB;s,n=boot(db);s.kind='none';n.ToggleDemo();assert(n.GetRun() and not n.GetRun().practice,'saved active run must prevent demo overlay')
 n.CheckZone();eq(ForeverPlusDB.currentRun.startUnix,100000)
end)
test('public start and abandon APIs restore saved ongoing state before acting after reload',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);s:kill(1);local db=ForeverPlusDB
 s,n=boot(db);s.id=36;s.name='The Deadmines';r=n.StartRun(n.DUNGEONS.dm);eq(r.key,'rfc');eq(r.kills,1);eq(r.startUnix,100000)
 db=ForeverPlusDB;s,n=boot(db);s.units.player={guid='Player-1',player=true};assert(loadfile(root..'History.lua'))('ForeverPlus',n)
 n.AbandonRun('slash');eq(n.GetRun(),nil);eq(#n.History.List(),1)
end)
test('practice preserves abandoned same-instance suppression',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc);n.AbandonRun('slash');n.ToggleDemo();n.CheckZone();assert(n.GetRun().practice)
 n.ToggleDemo();n.CheckZone();eq(n.GetRun(),nil)
end)
test('wrong dungeon cannot change progress or alive boss evidence while original run keeps ticking',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);s:kill(1)
 s.id=36;s.name='The Deadmines';n.CheckZone();eq(n.GetRun(),r)
 s.units.focus={name='Oggleflint',dead=false,hostile=true};s.tick();eq(next(r.bossNameSeen),nil)
 s:kill(2);s.event(nil,'BOSS_KILL',1,'Oggleflint');eq(r.kills,1);eq(n.CountBossesDown(r),0)
 eq(n.IsRunInCurrentInstance(),false);s.id=389;s.name='Ragefire Chasm';n.CheckZone();eq(n.IsRunInCurrentInstance(),true)
 s:kill(3);eq(r.kills,2)
end)
test('higher confidence same session wing refinement preserves timer ledger and history',function()
 local s,n=boot();s.name='Scarlet Monastery';s.id=189;n.CheckZone();local r=n.GetRun();s:kill(1);s.event(nil,'PLAYER_DEAD')
 local down=r.bossDown;local ledger=r.excludedBossKeys;s.clock=150;s.sub='Library';n.CheckZone()
 eq(n.GetRun(),r);eq(r.key,'smlib');eq(r.confidence,2);eq(r.startUnix,100000);eq(n.Elapsed(r),50);eq(r.kills,1);eq(r.deaths,1);eq(r.bossDown,down);eq(r.excludedBossKeys,ledger)
 s.sub='';n.CheckZone();eq(r.key,'smlib');eq(r.confidence,2)
end)
test('slash abandonment requests vote and refreshes UI without bypassing module',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local requests,refreshes=0,0
 n.Vote={Request=function() requests=requests+1 end};n.UI={HideSoon=function() end, RefreshVote=function() refreshes=refreshes+1 end}
 SlashCmdList.FOREVERPLUS('abandon');eq(requests,1);eq(refreshes,1);eq(n.GetRun(),r)
 n.UI=nil;n.Vote=nil;SlashCmdList.FOREVERPLUS('abandon');eq(n.GetRun(),nil)
end)
test('exact names explicit aliases conflicting IDs and no empty roster completion',function()
 local s,n=boot()
 eq(n.KeyFromKill(nil,'The Baroness'),nil); eq(n.KeyFromKill(nil,'Arugal Voidwalker'),nil)
 local _,b=n.MatchRequiredBoss(n.DUNGEONS.sfk,nil,'Arugal'); assert(b and b.id==4275)
 eq(n.MatchRequiredBoss(n.DUNGEONS.sfk,999,'Archmage Arugal'),nil)
 eq(n.KeyFromKill(999,'Archmage Arugal'),nil)
 eq(n.IsLastBossOf(n.DUNGEONS.sfk,999,'Arugal'),false)
 for _,d in ipairs({n.DUNGEONS.shapers,{bosses={}},{bosses={{n='A'}},manual=true},{bosses={},unknown=true}}) do
  eq(n.ObjectivesMet({dungeon=d,kills=200,bossDown={}}),false)
 end
 s.name=''; s.id=999; local d=n.ResolveDungeon(); assert(d.unknown)
 s.name='The Deadmines Annex'; d=n.ResolveDungeon(); assert(d.unknown)
end)
test('secret and failing instance zone unit APIs fail closed',function()
 local s,n=boot(); s.id=secret; eq(n.ResolveDungeon(),nil); n.CheckZone(); eq(n.GetRun(),nil)
 s.id=389; s.name=secret; eq(n.ResolveDungeon(),nil)
 GetInstanceInfo=function() error('restricted') end; eq(n.ResolveDungeon(),nil); n.StartRun(n.DUNGEONS.rfc)
 s,n=boot(); n.StartRun(n.DUNGEONS.rfc); s.units.target={name=secret,guid=secret,dead=secret,player=secret,hostile=secret}; s.tick(); eq(n.GetRun().kills,0)
 s.name='Dire Maul'; s.id=429; s.sub=secret; n.ResolveDungeon()
 GetSubZoneText=function() error('restricted') end; n.ResolveDungeon()
 n.OnCreatureDead(secret,secret,secret,'target'); eq(n.GetRun().kills,0)
end)
test('malformed saved migration preserves valid local bests',function()
 local s,n=boot({best={rfc={sec=200,chest=3},dm='bad'},peers=3,pos=false,minimap='bad',currentRun={key='rfc',startUnix='bad',kills='x',bossDown=1}})
 s:entry(); eq(n.GetBest('rfc').sec,200); eq(n.GetBest('dm'),nil); eq(n.GetRun().kills,0)
 s,n=boot('bad'); s:entry(); assert(n.GetRun())
 s,n=boot({currentRun={key='rfc',startUnix=100000,kills=0/0,deaths=-5,bossDown='bad',killSeen=1}}); s:entry(); eq(n.GetRun().kills,0); eq(n.GetRun().deaths,0)
end)
test('completion requires all bosses plus eighty four and preserves overtime demo isolation',function()
 local s,n=boot(); local shares=0; n.Comm={QueueShare=function() shares=shares+1 end}
 local r=n.StartRun(n.DUNGEONS.rfc)
 for _,b in ipairs(r.dungeon.bosses) do s:kill('boss');s.event(nil,'BOSS_KILL',0,b.n) end
 eq(r.kills,0); eq(r.complete,false)
 for i=1,83 do s:kill(i) end; eq(r.complete,false)
 s.clock=3800; s:kill(84); eq(r.complete,true); eq(r.chest,0); eq(n.GetBest('rfc').sec,3700); eq(shares,1)
 local clock,over=n.FormatClock(3700); eq(clock,'+1:40'); eq(over,true)
 n.ToggleDemo(); n.CompleteRun('demo'); eq(n.GetBest('demo'),nil); eq(shares,1)
 n.ToggleDemo(); n.CheckZone(); assert(not n.GetRun() or not n.GetRun().active)
end)
test('completed sentinel never expires while remaining in instance and abandon cannot restart it',function()
 local s,n=boot(); n.StartRun(n.DUNGEONS.rfc); n.CompleteRun('test'); n.AbandonRun('slash'); n.CheckZone(); assert(not n.GetRun() or not n.GetRun().active)
 s,n=boot(ForeverPlusDB); s.unix=200000; s:entry(); assert(not n.GetRun() or not n.GetRun().active)
end)
test('completed elapsed remains frozen across reload',function()
 local s,n=boot(); n.StartRun(n.DUNGEONS.rfc); s.clock=200; n.CompleteRun('test'); s.clock=400; eq(n.Elapsed(n.GetRun()),100)
 s,n=boot(ForeverPlusDB); s.unix=100400; s:entry(); eq(n.Elapsed(n.GetRun()),100); eq(n.GetRun().sec,100)
end)
test('authoritative NPC ID cannot mark a second boss through conflicting name',function()
 local s,n=boot(); local r=n.StartRun(n.DUNGEONS.rfc)
 n.OnCreatureDead(nil,11517,'Bazzalan','BOSS_KILL')
 eq(n.CountBossesDown(r),1); eq(n.IsBossMarked(r,n.DUNGEONS.rfc.bosses[4]),false)
end)
test('malformed nested preferences and peer records migrate without losing PB',function()
 local s,n=boot({best={rfc={sec=200,name={},player=4}},peers={Bad=5,Okay={rfc={sec='bad'}}},pos={p={},x='bad',y=0/0},minimap={angle=0/0},locked={},showMinimap={}})
 local d=n.DB(); eq(d.best.rfc.sec,200); eq(d.best.rfc.name,nil); eq(d.peers.Bad,nil); eq(d.peers.Okay.rfc,nil); eq(d.pos.p,nil); eq(d.locked,false); eq(d.showMinimap,true)
end)
test('demo departure clears underlying completed session',function()
 local s,n=boot(); n.StartRun(n.DUNGEONS.rfc); s.clock=160; n.CompleteRun('test'); n.ToggleDemo()
 s.kind='none'; n.CheckZone(); assert(n.GetRun().practice)
 eq(ForeverPlusDB.currentRun,nil)
 n.ToggleDemo(); s.kind='party'; n.CheckZone(); assert(n.GetRun().active and not n.GetRun().practice)
end)
test('abandoning practice preserves underlying completed session inside dungeon',function()
 local s,n=boot(); n.StartRun(n.DUNGEONS.rfc); s.clock=160; n.CompleteRun('test'); n.ToggleDemo()
 SlashCmdList.FOREVERPLUS('abandon'); assert(ForeverPlusDB.currentRun and ForeverPlusDB.currentRun.complete)
 n.CheckZone(); assert(n.GetRun().complete and not n.GetRun().active)
end)
test('visible trash fight and corpse never increment forces without native event',function()
 local s,n=boot();s.name='Blackfathom Deeps';s.id=48
 s.units.player={guid='Player-1',player=true};s.units.party1={guid='Player-2',player=true}
 local r=n.StartRun(n.DUNGEONS.bfd)
 s.units.target={guid='Creature-0-0-0-0-4824-1',name='Murkshallow Snapclaw',dead=false,hostile=true,combat=true,threat={party1=2}}
 s.tick(); eq(r.kills,0)
 s.units.target.dead=true;s.units.target.hostile=false;s.units.target.combat=false
 s.tick();eq(r.kills,0);eq(n.ForcesPercent(r),0)
 s.tick();s.event(nil,'UPDATE_MOUSEOVER_UNIT');eq(r.kills,0)
end)
test('unseen corpses unengaged targets outsiders and restricted evidence never earn forces',function()
 for _,mode in ipairs({'corpse','idle','outsider','secretThreat','secretTap'}) do
  local s,n=boot();s.units.player={guid='Player-1',player=true};local r=n.StartRun(n.DUNGEONS.rfc)
  local u={guid='Creature-0-0-0-0-4824-1',name='Murkshallow Snapclaw',dead=false,hostile=true,combat=true,threat={player=1}}
  s.units.target=u
  if mode=='corpse' then u.dead=true;u.hostile=false
  elseif mode=='idle' then u.combat=false;u.threat={}
  elseif mode=='outsider' then u.tapDenied=true
  elseif mode=='secretThreat' then u.threat.player=secret
  else u.tapDenied=secret end
  s.tick();u.dead=true;u.hostile=false;s.tick();eq(r.kills,0)
 end
end)
test('enemy targeting party cannot increment forces without native event',function()
 local s,n=boot();s.units.party1={guid='Player-2',player=true};local r=n.StartRun(n.DUNGEONS.rfc)
 UnitThreatSituation=nil
 s.units.target={guid='Creature-0-0-0-0-4824-1',name='Murkshallow Snapclaw',dead=false,hostile=true,combat=true,targetUnit='party1'}
 s.event(nil,'UNIT_HEALTH','target');s.units.target.dead=true;s.units.target.hostile=false
 s.event(nil,'UNIT_HEALTH','target');eq(r.kills,0)
end)
test('old visible trash evidence cannot count a corpse after resume',function()
 local s,n=boot();s.units.player={guid='Player-1',player=true};n.StartRun(n.DUNGEONS.rfc)
 local u={guid='Creature-0-0-0-0-4824-1',name='Murkshallow Snapclaw',dead=false,hostile=true,combat=true,threat={player=2}}
 s.units.target=u;s.tick();local db=ForeverPlusDB
 s,n=boot(db);s.units.target=u;s:entry();u.dead=true;u.hostile=false;s.tick();eq(n.GetRun().kills,0)
 s.tick();eq(n.GetRun().kills,0)
end)
test('sparse UNIT_DIED retains readable boss identity without granting forces',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local g='Creature-0-0-0-0-11517-1'
 CombatLogGetCurrentEventInfo=function() return 1,'UNIT_DIED',false,nil,nil,nil,nil,g,'Oggleflint',nil,nil end
 s.event(nil,'COMBAT_LOG_EVENT_UNFILTERED');eq(r.kills,0);eq(n.CountBossesDown(r),1);eq(r.bossDeductions,1)
end)
test('debug reports combat log and visible credit state without exposing secret values',function()
 local s,n=boot();local messages={}
 DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 n.StartRun(n.DUNGEONS.rfc);s.units.target={guid=secret,name=secret,dead=secret,hostile=secret,combat=secret}
 SlashCmdList.FOREVERPLUS('debug')
 local out=table.concat(messages,'\n');assert(out:find('CLEU',1,true) and out:find('live credits',1,true),'diagnostics unavailable')
 DEFAULT_CHAT_FRAME=nil
end)
local function reportParty(s)
 s.group=true;s.units.party1={name='Friend',realm='OtherRealm',player=true}
end
local function boss(s,name) s.event(nil,'BOSS_KILL',101,name or 'Oggleflint') end
test('boss reports freeze elapsed tier and next better gap at death with ASCII payloads',function()
 for _,case in ipairs({{2316,'Elapsed 38:36 (+2) - 2:36 faster for +3'},{2940,'Elapsed 49:00 (+1) - 1:00 faster for +2'},{3660,'Elapsed 1:01:00 (depleted) - 1:00 faster for +1'}}) do
  local s,n=boot();reportParty(s);local sent={};SendChatMessage=function(text) sent[#sent+1]=text end
  local r=n.StartRun(n.DUNGEONS.rfc);r.dungeon.bosses[1].n='B\195\182ss|\n'
  s.clock=100+case[1];boss(s,r.dungeon.bosses[1].n)
  local p=assert(n.GetPendingBossReport());assert(p.text:find(case[2],1,true),p.text);assert(not p.text:find('[\128-\255|%c]'));assert(#p.text<=255)
  s.clock=s.clock+1000;s:kill(1);s.tick();eq(#sent,0);eq(n.GetPendingBossReport().text,p.text)
  eq(n.SendPendingBossReport(),true);eq(#sent,1);eq(sent[1],p.text)
 end
end)
test('boss and deferred timers only prepare while hardware click sends one frozen snapshot',function()
 local s,n=boot();reportParty(s);local calls,delivered=0,0;local timers={};local hardware=false
 C_Timer.After=function(_,fn) timers[#timers+1]=fn end
 SendChatMessage=function(text,ch) calls=calls+1;if hardware then delivered=delivered+1 end;eq(ch,'PARTY');assert(text:find('Elapsed 1:00 (+3) - +3 is the highest tier',1,true));assert(text:find('Forces 3.6%',1,true));assert(text:find('at boss death',1,true)) end
 n.StartRun(n.DUNGEONS.rfc);s.clock=160;for i=1,4 do s:kill(i) end;boss(s)
 eq(calls,0);local pending=assert(n.GetPendingBossReport());eq(pending.count,1);eq(pending.canSend,true)
 pending.text='mutated';eq(n.GetPendingBossReport().text~=pending.text,true)
 C_Timer.After(0,function() C_Timer.After(0,function() s.tick() end) end)
 while #timers>0 do table.remove(timers,1)() end
 s.clock=400;s.event(nil,'PLAYER_DEAD');n.CompleteRun('manual');eq(calls,0)
 hardware=true;eq(n.SendPendingBossReport(),true);hardware=false;eq(calls,1);eq(delivered,1);eq(n.GetPendingBossReport(),nil)
 eq(n.SendPendingBossReport(),false);eq(calls,1)
end)
test('pending party identity and attempt are revalidated fail closed without sending',function()
 for _,mode in ipairs({'reset','abandon','roster','realm','leave','raid','secretGroup','secretRaid','secretName','secretExists','secretSize','category','secretCategory','newattempt','reload'}) do
  local s,n=boot();reportParty(s);LE_PARTY_CATEGORY_INSTANCE=2;local calls=0;SendChatMessage=function() calls=calls+1 end
  n.StartRun(n.DUNGEONS.rfc);boss(s);assert(n.GetPendingBossReport())
  if mode=='reset' then SlashCmdList.FOREVERPLUS('reset')
  elseif mode=='abandon' then n.AbandonRun('slash')
  elseif mode=='roster' then s.units.party1.name='Other'
  elseif mode=='realm' then s.units.party1.realm='Different'
  elseif mode=='leave' then s.group=false
  elseif mode=='raid' then s.raid=true
  elseif mode=='secretGroup' then IsInGroup=function() return secret end
  elseif mode=='secretRaid' then IsInRaid=function() return secret end
  elseif mode=='secretName' then s.units.party1.name=secret
  elseif mode=='secretExists' then UnitExists=function() return secret end
  elseif mode=='secretSize' then GetNumSubgroupMembers=function() return secret end
  elseif mode=='category' then s.instanceGroup=true
  elseif mode=='secretCategory' then IsInGroup=function(category) if category then return secret end return true end
  elseif mode=='newattempt' then n.CompleteRun('manual');n.StartRun(n.DUNGEONS.rfc)
  elseif mode=='reload' then s,n=boot(ForeverPlusDB);reportParty(s);s:entry() end
  eq(n.SendPendingBossReport(),false);eq(calls,0);eq(n.GetPendingBossReport(),nil)
 end
end)
test('combat blocks click and regen never resumes automatically',function()
 local s,n=boot();reportParty(s);local calls=0;SendChatMessage=function() calls=calls+1 end
 n.StartRun(n.DUNGEONS.rfc);boss(s);s.combat=true
 eq(n.GetPendingBossReport().canSend,false);eq(n.SendPendingBossReport(),false);eq(calls,0)
 s.combat=false;s.event(nil,'PLAYER_REGEN_ENABLED');s.tick();eq(calls,0);assert(n.GetPendingBossReport())
 InCombatLockdown=function() return secret end;eq(n.SendPendingBossReport(),false);eq(calls,0)
 InCombatLockdown=function() return false end;eq(n.SendPendingBossReport(),true);eq(calls,1)
end)
test('global first modern fallback and failed results retain head solely for manual retry',function()
 for _,mode in ipairs({'nil','true','zero','false','nonzero','string','table','secret','error','secretError','extraSecret','extraError','modern','missing'}) do
  local s,n=boot();reportParty(s);local calls,modern=0,0;local messages={}
  DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
  local function send()
   calls=calls+1
   if mode=='true' then return true elseif mode=='zero' then return 0 elseif mode=='false' then return false
   elseif mode=='nonzero' then return 4 elseif mode=='string' then return 'ok' elseif mode=='table' then return {}
   elseif mode=='secret' then return secret elseif mode=='error' then error('chat|blocked\nreason') elseif mode=='secretError' then error(secret)
   elseif mode=='extraSecret' then return nil,secret elseif mode=='extraError' then return nil,'blocked' end
  end
  SendChatMessage=send;C_ChatInfo={SendChatMessage=function() modern=modern+1;return send() end}
  if mode=='modern' then SendChatMessage=nil elseif mode=='missing' then SendChatMessage=nil;C_ChatInfo=nil end
  n.StartRun(n.DUNGEONS.rfc);boss(s);local id=n.GetPendingBossReport().id;eq(calls,0)
  local accepted=mode=='nil' or mode=='true' or mode=='zero' or mode=='modern'
  eq(n.SendPendingBossReport(),accepted);eq(calls,mode=='missing' and 0 or 1);eq(modern,mode=='modern' and 1 or 0)
  if accepted then eq(n.GetPendingBossReport(),nil) else
   eq(n.GetPendingBossReport().id,id);boss(s);s.tick();s.event(nil,'PLAYER_REGEN_ENABLED');eq(calls,mode=='missing' and 0 or 1)
   SendChatMessage=function() calls=calls+1 end;eq(n.SendPendingBossReport(),true);eq(n.GetPendingBossReport(),nil)
  end
  SlashCmdList.FOREVERPLUS('debug');local out=table.concat(messages,'\n');DEFAULT_CHAT_FRAME=nil
  assert(out:find('delivery unverified',1,true));assert(not out:find('confirmed sent',1,true))
 end
end)
test('preparation wakes hidden HUD and slash report synchronously sends only one FIFO line',function()
 local s,n=boot();reportParty(s);local calls,shown,refresh=0,0,0;local hardware=false;local delivered=0
 SendChatMessage=function(text) calls=calls+1;if hardware then delivered=delivered+1 end;assert(text:find(calls==1 and 'Oggleflint' or 'Taragaman',1,true)) end
 n.StartRun(n.DUNGEONS.rfc);n.UI={Tick=function() end,Show=function() shown=shown+1 end,RefreshBossReport=function() refresh=refresh+1 end}
 boss(s);boss(s,'Taragaman the Hungerer');boss(s);eq(calls,0);eq(shown,2);eq(refresh,2);eq(n.GetPendingBossReport().count,2)
 hardware=true;SlashCmdList.FOREVERPLUS('report');hardware=false;eq(calls,1);eq(delivered,1);eq(n.GetPendingBossReport().count,1)
 s.tick();eq(calls,1);hardware=true;SlashCmdList.FOREVERPLUS('report');hardware=false;eq(calls,2);eq(delivered,2)
end)
test('pending queue is bounded at eight preserves oldest and deduplicates required notifications',function()
 local s,n=boot();reportParty(s);local sent={};SendChatMessage=function(text) sent[#sent+1]=text end
 local r=n.StartRun(n.DUNGEONS.rfc);r.dungeon.bosses={}
 for i=1,12 do r.dungeon.bosses[i]={n='Required '..i,id=70000+i} end
 for i=1,12 do n.OnCreatureDead(nil,70000+i,'Required '..i,'BOSS_KILL');n.OnCreatureDead(nil,70000+i,'Required '..i,'ENCOUNTER_END') end
 eq(#sent,0);eq(n.GetPendingBossReport().count,8);eq(n.CountBossesDown(r),12)
 for i=1,8 do eq(n.SendPendingBossReport(),true);assert(sent[i]:find('Required '..i..' down',1,true)) end
 eq(n.GetPendingBossReport(),nil);eq(n.SendPendingBossReport(),false);eq(#sent,8)
end)
test('completed report survives same-party zoning but explicit abandon still clears it',function()
 local s,n=boot();reportParty(s);local calls=0;SendChatMessage=function() calls=calls+1 end
 n.StartRun(n.DUNGEONS.rfc);boss(s);local id=n.GetPendingBossReport().id
 n.CompleteRun('manual');s.kind='none';n.CheckZone('ZONE_CHANGED_NEW_AREA')
 eq(n.GetPendingBossReport().id,id);eq(n.SendPendingBossReport(),true);eq(calls,1)
 s.kind='party';n.CheckZone();boss(s);n.CompleteRun('manual');n.AbandonRun('slash');eq(n.GetPendingBossReport(),nil)
end)
test('pending readiness includes available API and release version is 1.4.0',function()
 local s,n=boot();reportParty(s);n.StartRun(n.DUNGEONS.rfc);boss(s)
 eq(n.GetPendingBossReport().canSend,false);eq(n.SendPendingBossReport(),false);assert(n.GetPendingBossReport())
 C_ChatInfo={SendChatMessage=function() end};eq(n.GetPendingBossReport().canSend,true)
 eq(n.SendPendingBossReport(),true);eq(n.ver,'1.4.0')
end)
test('known party categories route frozen lines and secret category preparation fails closed',function()
 for _,mode in ipairs({'constant','enum','absent','secret','secretMembership'}) do
  local s,n=boot();reportParty(s);s.instanceGroup=true;local calls=0
  if mode=='constant' or mode=='secretMembership' then LE_PARTY_CATEGORY_INSTANCE=2
  elseif mode=='enum' then Enum={PartyCategory={Instance=2}} elseif mode=='secret' then LE_PARTY_CATEGORY_INSTANCE=secret end
  if mode=='secretMembership' then IsInGroup=function(category) if category then return secret end return true end end
  SendChatMessage=function(text,ch) calls=calls+1;eq(ch,mode=='absent' and 'PARTY' or 'INSTANCE_CHAT') end
  n.StartRun(n.DUNGEONS.rfc);boss(s);eq(calls,0)
  if mode=='secret' or mode=='secretMembership' then eq(n.GetPendingBossReport(),nil);eq(n.SendPendingBossReport(),false)
  else assert(n.GetPendingBossReport());eq(n.SendPendingBossReport(),true);eq(calls,1) end
 end
end)
test('solo raid demo optional and unreadable roster cannot prepare public reports',function()
 for _,mode in ipairs({'solo','raid','demo','optional','missingRoster','missingName','secretName','badGroup','badRaid'}) do
  local s,n=boot();reportParty(s);local calls=0;SendChatMessage=function() calls=calls+1 end
  if mode=='solo' then s.group=false elseif mode=='raid' then s.raid=true elseif mode=='missingRoster' then s.units.party1=nil
  elseif mode=='missingName' then UnitFullName=nil elseif mode=='secretName' then s.units.party1.name=secret
  elseif mode=='badGroup' then IsInGroup=function() return secret end elseif mode=='badRaid' then IsInRaid=function() error('restricted') end end
  if mode=='demo' then n.ToggleDemo() else n.StartRun(n.DUNGEONS.rfc) end
  boss(s,mode=='optional' and 'Optional Boss' or nil);eq(n.GetPendingBossReport(),nil);eq(n.SendPendingBossReport(),false);eq(calls,0)
 end
end)
test('payload sanitation elapsed and same-run wing refinement preserve immutable pending lines',function()
 for _,long in ipairs({false,true}) do
  local s,n=boot();reportParty(s);local sent={};SendChatMessage=function(text) assert(not text:find('[|%c]'));assert(#text<=255);sent[#sent+1]=text end
  local r=n.StartRun(n.DUNGEONS.rfc);local b=r.dungeon.bosses[1];if long then b.n=string.rep('X',300)..'|\n' end
  s.clock=100+n.LIMIT+300;n.OnCreatureDead(nil,b.id,b.n,'BOSS_KILL');local p=n.GetPendingBossReport();assert(p.text:find('Elapsed 1:05:00 (depleted) - 5:00 faster for +1',1,true))
  s:kill(1);s.clock=s.clock+10;eq(n.GetPendingBossReport().text,p.text);eq(n.SendPendingBossReport(),true);eq(sent[1],p.text)
 end
 local s,n=boot();reportParty(s);s.name='Scarlet Monastery';s.id=189;n.CheckZone();boss(s,'Houndmaster Loksey');local id=n.GetPendingBossReport().id
 s.sub='Library';n.CheckZone();s.event(nil,'PLAYER_DEAD');s.kind='none';n.CheckZone();eq(n.GetPendingBossReport().id,id)
 SendChatMessage=function() end;eq(n.SendPendingBossReport(),true)
end)
test('observed roster change permanently prunes even if previous party returns before click',function()
 local s,n=boot();reportParty(s);n.StartRun(n.DUNGEONS.rfc);boss(s)
 s.units.party1.name='Replacement';s.event(nil,'GROUP_ROSTER_UPDATE');s.units.party1.name='Friend'
 eq(n.GetPendingBossReport(),nil)
end)
test('diagnostics expose prepared manual action and never claim confirmed delivery',function()
 local s,n=boot();reportParty(s);local messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 SendChatMessage=function() end;n.StartRun(n.DUNGEONS.rfc);boss(s);SlashCmdList.FOREVERPLUS('debug')
 local out=table.concat(messages,'\n');assert(out:find('prepared',1,true));assert(out:find('manual',1,true))
 messages={};n.SendPendingBossReport();SlashCmdList.FOREVERPLUS('debug');out=table.concat(messages,'\n')
 assert(out:find('attempt returned normally',1,true));assert(out:find('delivery unverified',1,true));DEFAULT_CHAT_FRAME=nil
end)
test('final automatic completion keeps boss-time after-deduction report available',function()
 local s,n=boot();reportParty(s);local sent={};SendChatMessage=function(text) sent[#sent+1]=text end
 local r=n.StartRun(n.DUNGEONS.rfc);for i=1,84 do s:kill(i) end
 for i,b in ipairs(r.dungeon.bosses) do s.clock=100+i*10;s:kill('boss');s.event(nil,'BOSS_KILL',100+i,b.n) end
 eq(r.complete,true);eq(r.kills,84);eq(#sent,0);eq(n.GetPendingBossReport().count,4)
 s.clock=1000;for i=1,4 do eq(n.SendPendingBossReport(),true) end
 assert(sent[4]:find('Elapsed 0:40 (+3) - +3 is the highest tier',1,true));assert(sent[4]:find('Forces 100%',1,true));assert(sent[4]:find('Bosses 4/4',1,true))
end)
test('unit health handles its visible unit without rescanning every nameplate',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc);local scans=0
 C_NamePlate={GetNamePlates=function() scans=scans+1;return {} end}
 s.event(nil,'UNIT_HEALTH','target');eq(scans,0)
 C_NamePlate=nil
end)
test('native registration and repeated notifications ignore GUID identity',function()
 local s,n=boot();assert(s.registrations.PARTY_KILL);assert(not s.registrations.COMBAT_LOG_EVENT_UNFILTERED)
 local r=n.StartRun(n.DUNGEONS.rfc)
 for i=1,3 do s.event(nil,'PARTY_KILL','Outsider','same-guid') end
 eq(r.kills,3);s:emit('PARTY_KILL','same-guid');eq(r.kills,3)
end)
test('native readability counters are informational only',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc);local messages={}
 DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 s.event(nil,'PARTY_KILL',secret,secret);s.event(nil,'PARTY_KILL');s.event(nil,'PARTY_KILL','Outsider','Player-2')
 eq(r.kills,3);SlashCmdList.FOREVERPLUS('debug');local out=table.concat(messages,'\n')
 assert(out:find('native PARTY_KILL events 3, readable 1, unreadable 2',1,true));DEFAULT_CHAT_FRAME=nil
end)
test('secret GUID readable boss name survives alive then verified unattackable death without forces',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 s.units.boss1={guid=secret,name='Oggleflint',dead=false,hostile=true};s.tick()
 s.units.boss1=nil;s.tick();eq(n.CountBossesDown(r),0)
 s.units.focus={guid=secret,name='Oggleflint',dead=true,hostile=false};s.tick()
 eq(n.CountBossesDown(r),1);eq(r.kills,0);eq(n.ForcesPercent(r),0)
 s.tick();eq(n.CountBossesDown(r),1)
end)
test('name evidence persists resume but reset and unrelated new runs cannot inherit it',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc)
 s.units.focus={name='Oggleflint',guid=secret,dead=false,hostile=true};s.tick()
 local db=ForeverPlusDB;s,n=boot(db);s:entry();local r=n.GetRun()
 s.units.focus={name='Oggleflint',guid=secret,dead=true,hostile=false};s.tick();eq(n.CountBossesDown(r),1)
 s.units.focus.dead=false;s.units.focus.hostile=true;s.tick();SlashCmdList.FOREVERPLUS('reset')
 s.units.focus.dead=true;s.units.focus.hostile=false;s.tick();eq(n.CountBossesDown(r),0)
 n.AbandonRun('slash');r=n.StartRun(n.DUNGEONS.rfc);s.tick();eq(n.CountBossesDown(r),0)
end)
test('name-only boss scan confirms sibling wing without forcing unrelated dungeons',function()
 local s,n=boot();s.name='Scarlet Monastery';s.id=189;n.CheckZone();local r=n.GetRun()
 s.units.party1target={name='Houndmaster Loksey',guid=secret,dead=false,hostile=true};s.tick()
 s.units.party1target.dead=true;s.units.party1target.hostile=false;s.tick()
 eq(r.key,'smlib');eq(n.CountBossesDown(r),1);eq(r.kills,0)
 s,n=boot();r=n.StartRun(n.DUNGEONS.rfc)
 s.units.focus={name='Houndmaster Loksey',guid=nil,dead=true,hostile=true};s.tick();eq(r.key,'rfc');eq(n.CountBossesDown(r),0)
end)
test('exact alias and canonical name share evidence with missing or secret string GUIDs',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.sfk)
 s.units.focus={name='Arugal',guid='private-creature-guid',dead=false,hostile=true};s.tick()
 s.units.focus={name='Archmage Arugal',guid='unknown-guid',dead=true,hostile=false};s.tick()
 eq(n.CountBossesDown(r),1);eq(r.kills,0)
end)
test('first-seen attackable boss corpse is preserved but restricted evidence and near names fail closed',function()
 for _,mode in ipairs({'attackable','unattackable','nearName','secretName','secretDead','secretHostile','player','conflictingID'}) do
  local s,n=boot();local r=n.StartRun(n.DUNGEONS.sfk)
  local u={name='Arugal',guid=nil,dead=true,hostile=true};s.units.focus=u
  if mode=='unattackable' then u.hostile=false elseif mode=='nearName' then u.name='Arugal Voidwalker'
  elseif mode=='secretName' then u.name=secret elseif mode=='secretDead' then u.dead=secret
  elseif mode=='secretHostile' then u.hostile=secret elseif mode=='player' then u.player=true
  elseif mode=='conflictingID' then u.guid='Creature-0-0-0-0-999-1' end
  s.tick();eq(n.CountBossesDown(r),mode=='attackable' and 1 or 0);eq(r.kills,0)
 end
end)
test('native secret string arguments and unavailable roster still count',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 s.event(nil,'PARTY_KILL','private-creature-guid','private-creature-guid');eq(r.kills,1)
end)
test('boss exclusion converges across native order aliases and optional signals',function()
 for _,before in ipairs({true,false}) do
  local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
  for i=1,24 do s:kill(i) end
  if before then s:kill('boss') end
  s.event(nil,'BOSS_KILL',101,'Oggleflint')
  if not before then s:kill('boss') end
  s.event(nil,'ENCOUNTER_END',101,'Oggleflint',1,5,1)
  n.OnCreatureDead(nil,11517,'Oggleflint','target')
  eq(r.kills,24);eq(r.nativeCount,25);eq(r.bossDeductions,1)
  s:kill('optional');s.event(nil,'BOSS_KILL',102,'Optional Boss');s.event(nil,'ENCOUNTER_END',102,'Optional Boss',1,5,1)
  eq(r.kills,24);eq(r.bossDeductions,2)
 end
end)
test('debug exposes ledger counts not opaque payloads',function()
 local s,n=boot();n.StartRun(n.DUNGEONS.rfc);s:kill(1);s.event(nil,'BOSS_KILL',secret,secret)
 local messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,m) messages[#messages+1]=m end}
 SlashCmdList.FOREVERPLUS('debug');local out=table.concat(messages,'\n');DEFAULT_CHAT_FRAME=nil
 assert(out:find('raw notifications 1, boss deductions 1, net kills 0',1,true),out)
end)
test('opaque boss receipts exclude kills without inspecting name or encounter ID',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 for i=1,3 do s:kill(i) end
 s.event(nil,'BOSS_KILL',secret,secret);s.event(nil,'ENCOUNTER_END',secret,secret,1,5,1)
 eq(r.bossDeductions,1);eq(r.kills,2)
 s.event(nil,'ENCOUNTER_END',secret,secret,1,5,0);eq(r.bossDeductions,1)
 s.event(nil,'BOSS_KILL',0,'');s.event(nil,'BOSS_KILL',0,'');eq(r.bossDeductions,3);eq(r.kills,0)
end)
test('last boss event ordering never completes at eighty three trash kills',function()
 for _,first in ipairs({true,false}) do
  local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
  for i=1,83 do s:kill(i) end
  for i,b in ipairs(r.dungeon.bosses) do
   if first then s:kill('boss') end
   s.event(nil,'BOSS_KILL',0,b.n)
   if not first then s:kill('boss') end
   eq(r.complete,false)
  end
  eq(r.kills,83);eq(n.FormatForces(r),'99.6%');s:kill('eighty four');eq(r.complete,true)
 end
end)
test('ledger reload persists exclusion and reset clears all new counters',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 for i=1,24 do s:kill(i) end
 s:kill('boss');s.event(nil,'BOSS_KILL',101,'Oggleflint')
 local db=ForeverPlusDB;s,n=boot(db);s:entry();r=n.GetRun()
 s.event(nil,'ENCOUNTER_END',101,'Oggleflint',1,5,1);eq(r.kills,24);eq(r.nativeCount,25);eq(r.bossDeductions,1)
 SlashCmdList.FOREVERPLUS('reset');eq(r.nativeCount,0);eq(r.bossDeductions,0);eq(r.forcesBaseline,0);eq(next(r.excludedBossKeys),nil)
 s:kill('fresh');eq(r.kills,1)
end)
test('upgrade baselines tracked kills and known bosses without retroactive events',function()
 for _,kills in ipairs({0,7}) do
  local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
  for i=1,2 do local b=r.dungeon.bosses[i];n.MarkBoss(r,b,b.id,b.n) end
  local db=ForeverPlusDB;db.currentRun.kills=kills
  db.currentRun.nativeCount=nil;db.currentRun.bossDeductions=nil;db.currentRun.forcesBaseline=nil;db.currentRun.excludedBossKeys=nil
  s,n=boot(db);s:entry();r=n.GetRun();eq(r.kills,kills);eq(r.nativeCount,0);eq(r.bossDeductions,0)
  for i=1,2 do local b=r.dungeon.bosses[i];s.event(nil,'BOSS_KILL',100+i,b.n) end
  eq(r.bossDeductions,0);eq(r.kills,kills)
  s:kill(1);eq(r.kills,kills+1)
 end
end)
test('stale outside party demo inactive and completed events do not change ledger',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 for _,kind in ipairs({'none','raid'}) do
  s.kind=kind;s:kill(1);s.event(nil,'BOSS_KILL',1,'Oggleflint');n.OnCreatureDead(nil,11517,'Oggleflint','target')
  eq(r.nativeCount,0);eq(r.bossDeductions,0);eq(n.CountBossesDown(r),0)
 end
 s.kind='party';s.id=36;s.name='The Deadmines';s:kill(1);s.event(nil,'BOSS_KILL',1,'Oggleflint');eq(r.nativeCount,0);eq(r.bossDeductions,0)
 s.id=389;s.name='Ragefire Chasm';r.active=false;s:kill(1);eq(r.nativeCount,0)
 r.active=true;n.CompleteRun('test');s:kill(1);s.event(nil,'BOSS_KILL',1,'Oggleflint');eq(r.nativeCount,0);eq(r.bossDeductions,0)
 n.ToggleDemo();r=n.GetRun();s:kill(1);s.event(nil,'BOSS_KILL',1,'Oggleflint');eq(r.nativeCount,0);eq(r.bossDeductions,0)
end)
test('canonical required aliases dedup encounter boss and corpse sources',function()
 local s,n=boot();s.name='Shadowfang Keep';s.id=33;local r=n.StartRun(n.DUNGEONS.sfk)
 s:kill(1);s.event(nil,'ENCOUNTER_END',101,'Arugal',1,5,1)
 s.event(nil,'BOSS_KILL',101,'Archmage Arugal');n.OnCreatureDead(nil,4275,'Arugal','target')
 eq(r.bossDeductions,1);eq(r.kills,0);eq(n.CountBossesDown(r),1)
end)
test('successful encounter only optional boss excludes once and failed encounters do not',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 s:kill(1);s:kill(2)
 s.event(nil,'ENCOUNTER_END',102,'Optional',1,5,0);eq(r.kills,2)
 s.event(nil,'ENCOUNTER_END',102,'Optional',1,5,1);eq(r.kills,1)
 s.event(nil,'BOSS_KILL',102,secret);s.event(nil,'ENCOUNTER_END',102,'Optional',1,5,1)
 eq(r.bossDeductions,1);eq(r.kills,1);eq(n.CountBossesDown(r),0)
end)
for _,t in ipairs(tests) do local ok,err=xpcall(t[2],debug.traceback); if ok then passed=passed+1; print('PASS '..t[1]) else print('FAIL '..t[1]..': '..err) end end
print(string.format('%d/%d passed',passed,#tests)); if passed~=#tests then os.exit(1) end
