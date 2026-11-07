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
 IsInGroup=function() return s.group==true end; IsInRaid=function() return s.raid==true end
 SendChatMessage=nil; C_ChatInfo=nil
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
test('opaque native notifications count without GUID evidence',function()
 local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
 UnitGUID=function() error('native policy must not query GUID') end
 for i=1,24 do s.event(nil,'PARTY_KILL',secret,secret) end
 eq(r.kills,24);eq(n.ForcesPercent(r),48)
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
 for _,b in ipairs(r.dungeon.bosses) do s:kill('boss');s.event(nil,'BOSS_KILL',0,b.n) end
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
test('boss posts remaining time and forces once per recorded boss in party chat',function()
 local s,n=boot();s.group=true;local sent={}
 SendChatMessage=function(msg,ch) sent[#sent+1]={msg=msg,ch=ch} end
 n.StartRun(n.DUNGEONS.rfc);s.clock=160
 for i=1,3 do s:kill(i) end
 s:kill('boss')
 n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL')
 eq(#sent,1);eq(sent[1].ch,'PARTY');assert(sent[1].msg:find('59:00',1,true));assert(sent[1].msg:find('Forces 6%',1,true));assert(sent[1].msg:find('1/4',1,true))
 n.OnCreatureDead(nil,11517,'Oggleflint','ENCOUNTER_END');n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL');eq(#sent,1)
 s.clock=100+n.LIMIT+300;n.OnCreatureDead(nil,11520,'Taragaman the Hungerer','BOSS_KILL')
 eq(#sent,2);assert(sent[2].msg:find('Overtime +5:00',1,true))
 local db=ForeverPlusDB;s,n=boot(db);s.group=true;SendChatMessage=function(msg,ch) sent[#sent+1]={msg=msg,ch=ch} end
 s:entry();n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL');eq(#sent,2)
end)
test('boss party reporting uses modern chat fallback but never reports solo raid or demo',function()
 local s,n=boot();s.group=true;local sent={}
 C_ChatInfo={SendChatMessage=function(msg,ch) sent[#sent+1]={msg=msg,ch=ch} end}
 n.StartRun(n.DUNGEONS.rfc);n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL');eq(#sent,1)
 s.group=false;n.OnCreatureDead(nil,11520,'Taragaman the Hungerer','BOSS_KILL');eq(#sent,1)
 s.group=true;s.raid=true;n.OnCreatureDead(nil,11518,'Jergosh the Invoker','BOSS_KILL');eq(#sent,1)
 n.AbandonRun('test');n.ToggleDemo();n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL');eq(#sent,1)
end)
test('chat send failure does not interrupt boss credit or retry duplicate public messages',function()
 local s,n=boot();s.group=true;local calls=0
 SendChatMessage=function() calls=calls+1;error('chat unavailable') end
 local r=n.StartRun(n.DUNGEONS.rfc);n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL')
 eq(n.CountBossesDown(r),1);n.OnCreatureDead(nil,11517,'Oggleflint','BOSS_KILL');eq(calls,1)
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
 n.AbandonRun('test');r=n.StartRun(n.DUNGEONS.rfc);s.tick();eq(n.CountBossesDown(r),0)
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
test('last boss event ordering never completes at forty nine trash kills',function()
 for _,first in ipairs({true,false}) do
  local s,n=boot();local r=n.StartRun(n.DUNGEONS.rfc)
  for i=1,49 do s:kill(i) end
  for i,b in ipairs(r.dungeon.bosses) do
   if first then s:kill('boss') end
   s.event(nil,'BOSS_KILL',0,b.n)
   if not first then s:kill('boss') end
   eq(r.complete,false)
  end
  eq(r.kills,49);s:kill('fifty');eq(r.complete,true)
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
for _,t in ipairs(tests) do local ok,err=pcall(t[2]); if ok then passed=passed+1; print('PASS '..t[1]) else print('FAIL '..t[1]..': '..err) end end
print(string.format('%d/%d passed',passed,#tests)); if passed~=#tests then os.exit(1) end
