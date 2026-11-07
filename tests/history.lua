local tests={}
local function test(n,f) tests[#tests+1]={n,f} end
local function boot(db)
 ForeverPlusDB=db or {}; local ns={}
 issecretvalue=function(v) return _G.secret~=nil and rawequal(v,_G.secret) end
 assert(loadfile('Dungeons.lua'))('ForeverPlus',ns)
 ns.PlayerFull=function() return 'Me-Realm' end
 ns.DB=function() return ForeverPlusDB end
 assert(loadfile('History.lua'))('ForeverPlus',ns)
 return ns.History,ns
end
local function record(id)
 return {id=id or 'run-1',dungeonKey='rfc',dungeonName='Ragefire Chasm',startUnix=1000,endUnix=1600,sec=600,chest=0,status='completed',manual=false,recordedBy='Peer-Realm',coverage='partial',players={{guid='Player-1',name='Me-Realm',class='MAGE',damage=100,healing=10,deaths=1},{guid='Player-2',name='Peer-Realm',class='PRIEST',damage=20,healing=200,deaths=0}}}
end
test('validation copies and derives chest; identities preserve realms',function()
 local h=boot(); local r=record(); local v=assert(h.Validate(r)); assert(v.chest==3 and v.players~=r.players)
 assert(h.SamePlayer('Me-Some Realm','me-somerealm')); assert(not h.SamePlayer('Me-Realm','Me-Other')); assert(not h.SamePlayer('Me','Me'))
 v.players[1].damage=9; assert(r.players[1].damage==100)
end)
test('receive authorized dedup exports copies and keeps PB isolated',function()
 local h=boot({best={rfc={sec=9}}}); local r=record(); assert(h.Receive(r,'Peer-Realm'))
 assert(#h.List()==1 and h.Get(r.id)); assert(not h.Receive(r,'Other-Realm'))
 local v=record('observer-2'); v.players[1].damage=999; assert(h.Receive(v,'Peer-Realm')); assert(#h.List()==1)
 assert(h.Get(v.id)); local a=h.ExportFor('Peer-Realm'); assert(#a==1); a[1].players[1].damage=0; assert(h.List()[1].players[1].damage~=0)
 assert(#h.ExportFor('Stranger-Realm')==0 and ForeverPlusDB.best.rfc.sec==9)
end)
test('validation rejects malformed nested and secret stats bounded storage',function()
 local h=boot(); local r=record(); r.players[1].damage=0/0; assert(not h.Validate(r)); r=record(); r.players[2]=nil; assert(not h.Validate(r))
 r=record(); r.players[1].name='Me'; assert(not h.Validate(r)); r=record(); r.players[1].healing=math.huge; assert(not h.Validate(r))
 secret={}; r=record(); r.players[1].damage=secret; assert(not h.Validate(r)); secret=nil
 for i=1,510 do r=record('r'..i); r.startUnix=i*1000;r.endUnix=r.startUnix+600; assert(h.Receive(r,'Peer-Realm')) end
 assert(#h.List()==500 and not h.Get('r1') and h.List()[1].id=='r510')
end)
local function core(db)
 local h,n=boot(db); local s={clock=100,unix=100000,units={player={name='Me',guid='Player-1',class='MAGE'},party1={name='Peer',guid='Player-2',class='PRIEST'},partypet1={guid='Pet-2'}}}
 GetTime=function() return s.clock end; time=function() return s.unix end
 UnitName=function(u) return (s.units[u] or {}).name end
 UnitFullName=function(u) return (s.units[u] or {}).name,'Realm' end
 UnitClass=function(u) return '',(s.units[u] or {}).class end
 UnitGUID=function(u) return (s.units[u] or {}).guid end
 UnitExists=function(u) return s.units[u]~=nil end
 UnitIsDeadOrGhost=function(u) return (s.units[u] or {}).dead or false end
 GetRealmName=function() return 'Realm' end; GetNormalizedRealmName=GetRealmName
 GetInstanceInfo=function() return 'Ragefire Chasm','party',1,'Normal',5,0,false,389 end
 GetRealZoneText=function() return 'Ragefire Chasm' end
 CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) s.event=fn end} end
 C_Timer={After=function(_,fn) fn() end,NewTicker=function(_,fn) s.tick=fn end}; SlashCmdList={}
 CombatLogGetCurrentEventInfo=function() return unpack(s.cleu) end
 assert(loadfile('ForeverPlus.lua'))('ForeverPlus',n)
 function s:emit(kind,src,dst,...)
  self.cleu={self.clock,kind,false,src,'Source',1,0,dst,'Dest',2112,0,...}; self.event(nil,'COMBAT_LOG_EVENT_UNFILTERED')
 end
 return s,n,h
end
test('readable teammate death without CLEU is counted once and resurrects for a second death',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc);local p=r.history.players[2]
 s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1');s.event(nil,'UNIT_FLAGS','party1')
 assert(p.deaths==1,'visible teammate corpse must count without CLEU');assert(r.deaths==0,'legacy counter stays local')
 assert(h.TotalDeaths(r)==1)
 s.units.party1.dead=false;s.event(nil,'UNIT_FLAGS','party1');s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1')
 assert(p.deaths==2 and h.TotalDeaths(r)==2 and r.deaths==0)
end)
test('core records non-addon roster effective pet stats local deaths and archives',function()
 local s,n,h=core(); local r=n.StartRun(n.DUNGEONS.rfc)
 s:emit('SWING_DAMAGE','Player-1','Creature-1',120,20)
 s:emit('SPELL_DAMAGE','Pet-2','Creature-1',123,'Spell',1,200,50)
 s:emit('SPELL_HEAL','Player-2','Player-1',123,'Heal',1,100,30)
 s.event(nil,'PLAYER_DEAD'); s:emit('UNIT_DIED','Creature-1','Player-1'); assert(r.deaths==1)
 s.clock=200;s.unix=100100;n.CompleteRun('slash','manual')
 local rows=h.List(); assert(#rows==1 and rows[1].manual)
 local p=rows[1].players; assert(#p==2 and p[1].damage==100 and p[1].deaths==1 and p[2].damage==150 and p[2].healing==70)
 assert(rows[1].coverage~='observed'); n.ToggleDemo();n.CompleteRun('demo');assert(#h.List()==1)
end)
test('active stats persist reload reset archives and resurrection permits another death',function()
 local s,n,h=core();n.StartRun(n.DUNGEONS.rfc);s:emit('SWING_DAMAGE','Player-1','Creature-1',100,-1)
 s.units.player.dead=true;s.event(nil,'PLAYER_DEAD');local db=ForeverPlusDB;s,n,h=core(db);s.units.player.dead=true;s.event(nil,'PLAYER_ENTERING_WORLD')
 s:emit('UNIT_DIED','Creature-1','Player-1');assert(n.GetRun().deaths==1)
 s.units.player.dead=false;s.event(nil,'PLAYER_ALIVE');s.units.player.dead=true;s.event(nil,'PLAYER_DEAD');assert(n.GetRun().deaths==2)
 s.clock=200;s.unix=100100;SlashCmdList.FOREVERPLUS('reset');assert(#h.List()==1 and h.List()[1].status=='reset')
 assert(h.List()[1].players[1].damage==100);s.clock=250;s.unix=100150;n.AbandonRun('slash');assert(#h.List()==2)
 assert(h.List()[1].players[1].damage==0)
end)
test('teammate graveyard resurrection clears death only on verified unit alive event',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc);local p=r.history.players[2]
 -- Combat-log death can precede the unit API update: duplicates must not query stale alive state.
 s:emit('UNIT_DIED','Creature-1','Player-2');s:emit('UNIT_DIED','Creature-1','Player-2');assert(p.deaths==1)
 s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1');assert(r.history.dead['Player-2'])
 local deadAPI=UnitIsDeadOrGhost
 UnitIsDeadOrGhost=function() return nil end;s.event(nil,'UNIT_HEALTH','party1');assert(r.history.dead['Player-2'])
 secret={};UnitIsDeadOrGhost=function() return secret end;s.event(nil,'UNIT_FLAGS','party1');assert(r.history.dead['Player-2']);secret=nil
 UnitIsDeadOrGhost=deadAPI
 s.units.party1=nil;s.event(nil,'UNIT_HEALTH','party1');assert(r.history.dead['Player-2'])
 s.units.party1={name='Peer',guid='Player-2',class='PRIEST',dead=false}
 s.event(nil,'UNIT_HEALTH','party1');assert(not r.history.dead['Player-2'],'verified alive must clear teammate death latch')
 s.units.party1.dead=true;s:emit('UNIT_DIED','Creature-1','Player-2');assert(p.deaths==2)
end)
test('verified guardian survives unchanged roster and unit pet refresh',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc);local p=r.history.players[2]
 s:emit('SPELL_SUMMON','Player-2','Guardian-1',1,'Summon',1)
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==50)
 s.event(nil,'GROUP_ROSTER_UPDATE')
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==100,'unchanged roster must retain guardian attribution')
 s.units.partypet1={guid='Pet-Replacement'};s.event(nil,'UNIT_PET','party1')
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==150)
 s:emit('SWING_DAMAGE','Pet-2','Creature-1',50,0);assert(p.damage==150,'old primary pet must expire')
 s:emit('SWING_DAMAGE','Pet-Replacement','Creature-1',50,0);assert(p.damage==200,'unit pet refresh must verify new primary pet')
end)
test('guardian evidence expires on death despawn owner departure and new session and stays bounded',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc);local p=r.history.players[2]
 for _,kind in ipairs({'UNIT_DIED','UNIT_DESTROYED','UNIT_DISSIPATES'}) do
  s:emit('SPELL_SUMMON','Player-2','Guardian-1',1,'Summon',1)
  s:emit(kind,'Creature-1','Guardian-1')
  s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==0,kind..' must invalidate guardian')
 end
 s:emit('SPELL_SUMMON','Player-2','Guardian-1',1,'Summon',1)
 s:emit('UNIT_DIED','Creature-1','Player-2')
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==0,'owner death must invalidate guardian')
 s:emit('SPELL_SUMMON','Player-2','Guardian-1',1,'Summon',1)
 s.units.party1=nil;s.event(nil,'GROUP_ROSTER_UPDATE')
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==0)
 s:emit('SPELL_SUMMON','Player-2','Guardian-Late',1,'Summon',1)
 s:emit('SWING_DAMAGE','Guardian-Late','Creature-1',50,0);assert(p.damage==0,'departed owner must not create new evidence')
 s.units.party1={name='Peer',guid='Player-2',class='PRIEST'};s.event(nil,'GROUP_ROSTER_UPDATE')
 s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(p.damage==0)
 for i=1,150 do s:emit('SPELL_SUMMON','Player-2','Guardian-'..i,1,'Summon',1) end
 local count=0;for _ in pairs(r.history.pets) do count=count+1 end;assert(count<=100)
 SlashCmdList.FOREVERPLUS('reset');s:emit('SWING_DAMAGE','Guardian-1','Creature-1',50,0);assert(r.history.players[2].damage==0)
end)
test('observer preference aliases survive richer replacement and short manual runs stay separate',function()
 local h=boot();local a=record();assert(h.Receive(a,'Peer-Realm'))
 local b=record('richer');b.coverage='observed';b.players[1].damage=900;assert(h.Receive(b,'Peer-Realm'));assert(h.Get('richer') and h.List()[1].players[1].damage==900)
 local c=record('local');c.recordedBy='Me-Realm';c.players[1].damage=7;assert(h.Receive(c,'Peer-Realm'));assert(h.List()[1].players[1].damage==900) -- remote observer identity is not local provenance
 local short=record('short');short.manual=true;short.sec=5;short.startUnix=1595;assert(h.Receive(short,'Peer-Realm'));short.id='short2';assert(h.Receive(short,'Peer-Realm'));assert(#h.List()==3)
 local bad=record('bad');secret={};bad.chest=secret;assert(not h.Validate(bad));secret=nil
end)
test('roster freezes leavers adds late joins ignores unknown pets environmental and incoming damage',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 s.units.party1={name='Late',guid='Player-3',class='WARRIOR'};s.event(nil,'GROUP_ROSTER_UPDATE')
 s:emit('SWING_DAMAGE','Pet-Unknown','Creature-1',100,0)
 s:emit('SWING_DAMAGE','Creature-1','Player-1',100,0)
 s:emit('ENVIRONMENTAL_DAMAGE','Player-1','Player-1','FALLING',100,0)
 s:emit('SPELL_SUMMON','Player-3','Pet-New',1,'Summon',1)
 s:emit('SWING_DAMAGE','Pet-New','Creature-1',50,0)
 s:emit('SPELL_PERIODIC_HEAL','Player-2','Player-1',1,'Heal',1,50,10)
 s.clock=200;s.unix=100100;n.CompleteRun('test')
 local p=h.List()[1].players;assert(#p==3 and p[1].damage==0 and p[2].healing==40 and p[3].damage==50)
end)
test('local canonical UnitFullName realm overrides fallback and merge aliases stay bounded',function()
 local s,n,h=core();UnitFullName=function(u) return u=='player' and 'Me' or 'Peer',u=='player' and 'Other Realm' or 'Realm' end
 assert(n.PlayerFull()=='Me-OtherRealm')
 local hh=boot();for i=1,2100 do local r=record('alias'..i);assert(hh.Receive(r,'Peer-Realm')) end
 local count=0;for _ in pairs(hh.aliases) do count=count+1 end;assert(count<=2000)
end)
test('local deaths work without GUID and sync lifecycle forwards safely',function()
 local s,n,h=core();s.units.player.guid=nil;n.StartRun(n.DUNGEONS.rfc)
 s.event(nil,'PLAYER_DEAD');s.event(nil,'PLAYER_DEAD');assert(n.GetRun().deaths==1)
 s.units.player.dead=false;s.event(nil,'PLAYER_ALIVE');s.units.player.dead=true;s.event(nil,'PLAYER_DEAD');assert(n.GetRun().deaths==2)
 local called={};n.Sync={Init=function() called.init=true end,OnZone=function() called.zone=true end,OnRoster=function() called.roster=true end,Request=function(why) called.reason=why end}
 s.event(nil,'PLAYER_LOGIN');s.event(nil,'PLAYER_ENTERING_WORLD');s.event(nil,'GROUP_ROSTER_UPDATE');SlashCmdList.FOREVERPLUS('sync')
 assert(called.init and called.zone and called.roster and called.reason=='manual')
end)
test('remote claim of local observer cannot replace actual local observation',function()
 local s,n,h=core();n.StartRun(n.DUNGEONS.rfc);s:emit('SWING_DAMAGE','Player-1','Creature-1',10,0);s.clock=200;s.unix=100100;n.CompleteRun('test')
 local remote=h.List()[1];remote.id='forged-observer';remote.coverage='observed';remote.players[1].damage=999
 assert(h.Receive(remote,'Peer-Realm'));assert(#h.List()==1 and h.List()[1].players[1].damage==10)
end)
test('successful real completion queues archive sync once while demo and invalid archives never queue',function()
 local s,n,h=core();local calls={}
 n.Sync={Request=function(reason) assert(#h.List()==1,'archive must be stored before sync');calls[#calls+1]=reason end}
 n.StartRun(n.DUNGEONS.rfc);s.clock=200;s.unix=100100
 n.CompleteRun('test');n.CompleteRun('duplicate');assert(#calls==1 and calls[1]=='archive','real archive must queue participant sync once')
 n.ToggleDemo();n.CompleteRun('demo');assert(#calls==1)
 local r={active=true,key='rfc',name='Ragefire Chasm',startUnix=100000,history={id='bad',recordedBy='Me-Realm',players={},pets={},dead={}}}
 local old=UnitFullName;UnitFullName=function() return nil end;local oldName=UnitName;UnitName=function() return nil end
 assert(not h.Archive(r,'completed',false));assert(#calls==1)
 UnitFullName=old;UnitName=oldName
end)
test('roster baseline suppresses existing corpses and periodic scan catches missed transitions',function()
 local s,n,h=core();s.units.party1.dead=true;local r=n.StartRun(n.DUNGEONS.rfc);local p=r.history.players[2]
 s.event(nil,'UNIT_HEALTH','party1');s.tick();assert(p.deaths==0,'starting corpse is baseline, not a new death')
 s.units.party1.dead=false;s.clock=s.clock+1;s.tick()
 s.units.party1.dead=true;s.clock=s.clock+1;s.tick();assert(p.deaths==1,'periodic scan must catch a missed unit event')
 s.units.party1=nil;s.event(nil,'GROUP_ROSTER_UPDATE');s.clock=s.clock+1;s.tick();assert(h.TotalDeaths(r)==1)
 s.units.party1={name='Peer',guid='Player-2',class='PRIEST',dead=true};s.event(nil,'GROUP_ROSTER_UPDATE');s.tick();assert(p.deaths==1,'same GUID rejoin must retain latch')
 s.units.party2={name='Corpse',guid='Player-3',class='MAGE',dead=true};s.event(nil,'GROUP_ROSTER_UPDATE');s.event(nil,'UNIT_FLAGS','party2');assert(h.TotalDeaths(r)==1,'joining corpse is baseline')
 s.units.party3={name='Living',guid='Player-4',class='MAGE'};s.event(nil,'GROUP_ROSTER_UPDATE')
 s.units.party3.dead=true;s.clock=s.clock+1;s.tick();assert(h.TotalDeaths(r)==2,'living late join must be tracked')
end)
test('local mixed ordering stale alive polls and reload cannot undo the death latch',function()
 for _,first in ipairs({'PLAYER_DEAD','CLEU','POLL'}) do
  local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
  if first=='CLEU' then s:emit('UNIT_DIED','Creature-1','Player-1')
  elseif first=='POLL' then s.units.player.dead=true;s.tick()
  else s.event(nil,'PLAYER_DEAD') end
  s.event(nil,'PLAYER_DEAD');s.clock=s.clock+1;s.tick();s.event(nil,'UNIT_FLAGS','player');s.event(nil,'GROUP_ROSTER_UPDATE')
  s:emit('UNIT_DIED','Creature-1','Player-1');assert(r.deaths==1,first..' stale alive read undid latch')
  local db=ForeverPlusDB;s,n,h=core(db);s.units.player.dead=(first=='POLL');s.event(nil,'PLAYER_ENTERING_WORLD');r=n.GetRun()
  s.event(nil,'PLAYER_DEAD');s:emit('UNIT_DIED','Creature-1','Player-1');assert(r.deaths==1,first..' reload undid latch')
  s.units.player.dead=true;s.event(nil,'UNIT_HEALTH','player');s.units.player.dead=false;s.event(nil,'UNIT_FLAGS','player')
  s.units.player.dead=true;s.event(nil,'PLAYER_DEAD');s.clock=s.clock+1;s.tick();assert(r.deaths==2)
 end
end)
test('reload retains verified dead state so a real resurrection permits the next death',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 s:emit('SWING_DAMAGE','Player-1','Creature-1',100,0)
 s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1')
 local db=ForeverPlusDB;s,n,h=core(db);s.event(nil,'PLAYER_ENTERING_WORLD');r=n.GetRun()
 assert(r.history.players[1].damage==100 and h.TotalDeaths(r)==1)
 -- Already resurrected when the client comes back: saved verified-dead evidence must survive.
 s.units.party1.dead=true;s.event(nil,'UNIT_FLAGS','party1')
 assert(h.TotalDeaths(r)==2,'resume must preserve verified state and accept a later real death')
end)
test('death identity rejects secret or mismatched GUID and uses canonical names only when GUID absent',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 secret={};assert(not h.Death(r,secret,true),'secret GUID must not become a local death');secret=nil
 assert(not h.Death(r,'Player-Stranger',true),'mismatched GUID must not fall back to local player')
 local guid=UnitGUID;secret={};UnitGUID=function(u) if u=='player' then return secret end;return guid(u) end
 s.event(nil,'PLAYER_DEAD');assert(r.deaths==0,'event must not erase secret GUID before matching')
 UnitGUID=guid;secret=nil
 s.units.party1.guid=nil;s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1')
 assert(r.history.players[2].deaths==1,'canonical roster name must work when GUID is unavailable')
 assert(r.deaths==0)
end)
test('resurrection notifications need readable living state and cannot erase restricted identity latch',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 s.units.player.dead=true;s.event(nil,'PLAYER_DEAD');s.event(nil,'UNIT_HEALTH','player')
 s.event(nil,'PLAYER_ALIVE');s.event(nil,'PLAYER_DEAD');assert(r.deaths==1,'alive event while still dead must not clear latch')
 s:emit('SPELL_RESURRECT','Player-2','Player-1');s:emit('UNIT_DIED','Creature-1','Player-1');assert(r.deaths==1,'resurrection cast alone is not a verified resurrection')
 s.units.player.dead=false;local guid=UnitGUID;secret={};UnitGUID=function() return secret end
 s.event(nil,'PLAYER_UNGHOST');UnitGUID=guid;secret=nil;s.event(nil,'PLAYER_DEAD');assert(r.deaths==1,'secret GUID must not clear local latch')
 s.event(nil,'PLAYER_ALIVE');s.event(nil,'PLAYER_DEAD');assert(r.deaths==2,'verified alive event permits next death')
end)
test('debug includes tracked players and party death total with optional history',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1')
 local out={};DEFAULT_CHAT_FRAME={AddMessage=function(_,message) out[#out+1]=message end}
 SlashCmdList.FOREVERPLUS('debug');local message=table.concat(out,'\n');assert(message:find('tracked players 2',1,true) and message:find('party deaths 1',1,true),'debug must report roster and party total')
 out={};n.History=nil;SlashCmdList.FOREVERPLUS('debug');assert(table.concat(out,'\n'):find('tracked players 0',1,true))
 DEFAULT_CHAT_FRAME=nil
end)
test('late readable GUID preserves name-keyed death baseline and deduplication',function()
 local s,n,h=core();s.units.party1.guid=nil;local r=n.StartRun(n.DUNGEONS.rfc)
 assert(h.Death(r,nil,false,'Peer-Realm'));assert(h.TotalDeaths(r)==1)
 s.units.party1.guid='Player-2';s.event(nil,'GROUP_ROSTER_UPDATE');s:emit('UNIT_DIED','Creature-1','Player-2')
 assert(h.TotalDeaths(r)==1,'GUID promotion must migrate the canonical-name death latch')
 s.units.party1.dead=true;s.event(nil,'UNIT_FLAGS','party1')
 s.units.party1.dead=false;s.event(nil,'UNIT_FLAGS','party1');s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1');assert(h.TotalDeaths(r)==2)
end)
test('unavailable restricted and absent party reads never invent deaths or clear latches',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc);local exists,dead,guid=UnitExists,UnitIsDeadOrGhost,UnitGUID
 for _,field in ipairs({'exists','dead','guid'}) do
  for _,value in ipairs({'nil','secret','throw'}) do
   if not (field=='guid' and value=='nil') then -- Missing GUID with a readable canonical name is intentionally supported.
    secret={};local function unreadable() if value=='throw' then error('restricted') elseif value=='secret' then return secret end end
    UnitExists=field=='exists' and unreadable or exists;UnitIsDeadOrGhost=field=='dead' and unreadable or dead;UnitGUID=field=='guid' and unreadable or guid
    s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1');s.clock=s.clock+1;s.tick();assert(h.TotalDeaths(r)==0,field..' '..value)
   end
  end
 end
 UnitExists=exists;UnitIsDeadOrGhost=dead;UnitGUID=guid;secret=nil
 s.event(nil,'UNIT_FLAGS','party1');assert(h.TotalDeaths(r)==1)
 s.units.party1=nil;s.event(nil,'UNIT_HEALTH','party1');s.clock=s.clock+1;s.tick();assert(r.history.dead['Player-2'])
end)
test('completed inactive and practice runs cannot gain new deaths',function()
 local s,n,h=core();local r=n.StartRun(n.DUNGEONS.rfc)
 s.units.party1.dead=true;s.event(nil,'UNIT_FLAGS','party1');s.clock=200;s.unix=100100;n.CompleteRun('test')
 s.units.party1.dead=false;s.event(nil,'UNIT_FLAGS','party1');s.units.party1.dead=true;s.event(nil,'UNIT_HEALTH','party1');s:emit('UNIT_DIED','Creature-1','Player-2');s.event(nil,'PLAYER_DEAD');s.tick()
 assert(h.TotalDeaths(r)==1 and h.List()[1].players[2].deaths==1 and r.deaths==0)
 r.active=true;assert(not h.Death(r,'Player-1'),'completed wins even with stale active flag');r.active=false;r.complete=false;assert(not h.Death(r,'Player-1'))
 r.active=true;r.practice=true;assert(not h.Death(r,'Player-1'));h.UnitState(r,'player');assert(h.TotalDeaths(r)==1)
end)
local failures=0
for _,t in ipairs(tests) do local ok,e=pcall(t[2]); if ok then print('PASS '..t[1]) else failures=failures+1; print('FAIL '..t[1]..': '..tostring(e)) end end
assert(failures==0,failures..' history tests failed')
print(#tests..' history tests passed')
