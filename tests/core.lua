-- Run from addon root: luajit tests/core.lua
local root = (arg[0]:match('^(.*)tests/core.lua$') or '')
local tests, passed = {}, 0
local secret = setmetatable({}, {__tostring=function() error('secret tostring') end, __concat=function() error('secret concat') end})
local function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
local function boot(db)
 local s={clock=100, unix=100000, name='Ragefire Chasm', kind='party', id=389, sub='', units={}}
 ForeverPlusDB=db or {}; SlashCmdList={}
 issecretvalue=function(v) return rawequal(v,secret) end
 GetTime=function() return s.clock end; time=function() return s.unix end
 GetInstanceInfo=function() return s.name,s.kind,1,'Normal',5,0,false,s.id end
 GetRealZoneText=function() return s.name end; GetSubZoneText=function() return s.sub end; GetMinimapZoneText=function() return '' end
 UnitName=function(u) if u=='player' then return 'Tester' end return (s.units[u] or {}).name end
 GetRealmName=function() return 'Realm' end; GetNormalizedRealmName=GetRealmName
 UnitExists=function(u) return s.units[u]~=nil end
 UnitIsDead=function(u) return (s.units[u] or {}).dead end; UnitIsDeadOrGhost=UnitIsDead
 UnitGUID=function(u) return (s.units[u] or {}).guid end
 UnitIsPlayer=function(u) return (s.units[u] or {}).player or false end
 UnitCanAttack=function(_,u) return (s.units[u] or {}).hostile end
 UnitIsTapDenied=function() return false end
 strsplit=function(delim,str) local t={}; for x in str:gmatch('[^'..delim..']+') do t[#t+1]=x end return unpack(t) end
 bit=require('bit'); COMBATLOG_OBJECT_AFFILIATION_MINE=1; COMBATLOG_OBJECT_AFFILIATION_PARTY=2; COMBATLOG_OBJECT_AFFILIATION_RAID=4
 COMBATLOG_OBJECT_REACTION_HOSTILE=64; COMBATLOG_OBJECT_TYPE_NPC=2048
 CreateFrame=function() local f={}; f.RegisterEvent=function() end; f.SetScript=function(_,_,fn) s.event=fn end; return f end
 C_Timer={After=function(_,fn) fn() end,NewTicker=function(_,fn) s.tick=fn end}
 CombatLogGetCurrentEventInfo=function() return unpack(s.cleu) end
 local ns={}; assert(loadfile(root..'Dungeons.lua'))('ForeverPlus',ns); assert(loadfile(root..'ForeverPlus.lua'))('ForeverPlus',ns)
 s.ns=ns
 function s:emit(sub,guid,name,srcFlags,dstFlags)
  self.cleu={1,sub,false,'Player-1','Tester',srcFlags or 1,0,guid,name or 'Trash',dstFlags or 2112,0}
  self.event(nil,'COMBAT_LOG_EVENT_UNFILTERED')
 end
 function s:kill(i) local g='Creature-0-0-0-0-999-'..i; self:emit('SPELL_DAMAGE',g); self:emit('UNIT_DIED',g); return g end
 function s:entry() self.event(nil,'PLAYER_ENTERING_WORLD') end
 return s,ns
end
local function test(name,fn) tests[#tests+1]={name,fn} end
test('forces require hostile creature group credit and stable GUID',function()
 local s,n=boot(); local r=n.StartRun(n.DUNGEONS.rfc)
 n.OnCreatureDead('Player-1',nil,'Player','UNIT_DIED'); n.OnCreatureDead('Pet-1',nil,'Pet','UNIT_DIED'); n.OnCreatureDead(nil,nil,'Trash','target')
 s:emit('UNIT_DIED','Creature-0-0-0-0-999-1'); eq(r.kills,0)
 s:emit('SPELL_DAMAGE','Creature-0-0-0-0-999-2',nil,8); s:emit('UNIT_DIED','Creature-0-0-0-0-999-2'); eq(r.kills,0)
 s:emit('SPELL_DAMAGE','Creature-0-0-0-0-999-3',nil,1,2064); s:emit('UNIT_DIED','Creature-0-0-0-0-999-3',nil,1,2064); eq(r.kills,0)
 local g=s:kill(4); eq(r.kills,1); s:emit('UNIT_DIED',g); eq(r.kills,1)
 s:emit('PARTY_KILL','Creature-0-0-0-0-999-5'); eq(r.kills,2)
 s.units.target={name='Trash',guid='Creature-0-0-0-0-999-6',dead=true,hostile=true}; s.tick(); eq(r.kills,2)
 s:emit('SPELL_DAMAGE',s.units.target.guid); s.tick(); eq(r.kills,3)
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
test('wing confirmation persists and different dungeon starts fresh',function()
 local s,n=boot(); s.name='Scarlet Monastery'; s.id=189; n.CheckZone(); local r=n.GetRun()
 n.OnCreatureDead(nil,3974,'Houndmaster Loksey','BOSS_KILL'); eq(r.key,'smlib'); eq(ForeverPlusDB.currentRun.key,'smlib')
 n.CheckZone(); eq(r.key,'smlib'); s,n=boot(ForeverPlusDB); s.name='Scarlet Monastery'; s.id=189; s:entry(); eq(n.GetRun().key,'smlib')
 r=n.GetRun(); s.name='The Deadmines'; s.id=36; n.CheckZone(); assert(n.GetRun()~=r); eq(n.GetRun().key,'dm'); eq(n.GetRun().kills,0)
end)
test('exact names explicit aliases conflicting IDs and no empty roster completion',function()
 local s,n=boot()
 eq(n.KeyFromKill(nil,'The Baroness'),nil); eq(n.KeyFromKill(nil,'Arugal Voidwalker'),nil)
 local _,b=n.MatchRequiredBoss(n.DUNGEONS.sfk,nil,'Arugal'); assert(b and b.id==4275)
 eq(n.MatchRequiredBoss(n.DUNGEONS.sfk,999,'Archmage Arugal'),nil)
 eq(n.KeyFromKill(999,'Archmage Arugal'),nil)
 eq(n.IsLastBossOf(n.DUNGEONS.sfk,999,'Arugal'),false)
 for _,d in ipairs({n.DUNGEONS.shapers,{bosses={}},{bosses={{n='A'}},manual=true},{bosses={},unknown=true}}) do
  eq(n.ObjectivesMet({dungeon=d,kills=50,bossDown={}}),false)
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
test('completion requires all bosses plus fifty and preserves overtime demo isolation',function()
 local s,n=boot(); local shares=0; n.Comm={QueueShare=function() shares=shares+1 end}
 local r=n.StartRun(n.DUNGEONS.rfc)
 for _,b in ipairs(r.dungeon.bosses) do n.OnCreatureDead(nil,b.id,b.n,'BOSS_KILL') end
 eq(r.kills,0); eq(r.complete,false)
 for i=1,49 do s:kill(i) end; eq(r.complete,false)
 s.clock=3800; s:kill(50); eq(r.complete,true); eq(r.chest,0); eq(n.GetBest('rfc').sec,3700); eq(shares,1)
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
for _,t in ipairs(tests) do local ok,err=pcall(t[2]); if ok then passed=passed+1; print('PASS '..t[1]) else print('FAIL '..t[1]..': '..err) end end
print(string.format('%d/%d passed',passed,#tests)); if passed~=#tests then os.exit(1) end
