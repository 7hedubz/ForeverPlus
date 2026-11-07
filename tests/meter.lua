local tests={}
local function test(n,f) tests[#tests+1]={n,f} end
local function boot(existing)
 local state={sessions=existing or {},data={},context=true,combat=false}
 ForeverPlusDB={};local ns={PlayerFull=function() return 'Me-Realm' end,Elapsed=function() return 60 end,ChestForTime=function() return 3 end}
 local restricted={};state.secret=restricted
 issecretvalue=function(v) return rawequal(v,restricted) end
 issecrettable=function(v) return rawequal(v,restricted) end
 ns.IsSecret=issecretvalue
 UnitGUID=function(u) if u=='player' then return 'Player-1' end end
 UnitFullName=function() return 'Me','Realm' end;UnitName=UnitFullName
 UnitExists=function(u) return u=='player' end
 UnitClass=function() return '', 'MAGE' end;UnitIsDeadOrGhost=function() return false end
 time=function() return 1060 end
 InCombatLockdown=function() return state.combat end
 ns.IsRunInCurrentInstance=function() return state.context end
 C_DamageMeter={GetAvailableCombatSessions=function() if state.fail then error('restricted') end;return state.sessions end,GetCombatSessionFromID=function(id,kind) return (state.data[id] or {})[kind] end}
 assert(loadfile('History.lua'))('ForeverPlus',ns)
 local h=ns.History;local r={active=true,key='rfc',name='Ragefire Chasm',startUnix=1000};h.Start(r)
 function state:sample(id,amount,kind,name,guid,duration)
  self.sessions={{sessionID=id,name='Fight'}}
  self.data[id]=self.data[id] or {}; self.data[id][kind or 0]={durationSeconds=duration or 10,combatSources={{name=name or 'Me-Realm',sourceGUID=guid or 'Player-1',totalAmount=amount}}}
 end
 return h,r,state,ns
end
local function p(r) return r.history.players[1] end
 test('baseline excludes every preexisting ID',function()
 local h,r,s=boot({{sessionID=1,name='Old'}});s:sample(1,999);h.PollNative(r);assert(p(r).damage==0 and not r.history.combatObserved)
 s:sample(2,100);h.PollNative(r);assert(p(r).damage==100 and r.history.combatObserved)
 end)
test('cumulative snapshots survive reload and eviction without replay',function()
 local h,r,s,ns=boot();s:sample(2,100);h.PollNative(r);h.PollNative(r);assert(p(r).damage==100)
 local saved=r.history;h.Resume(r,saved);s:sample(2,150);h.PollNative(r);assert(p(r).damage==150,'reload must retain ledger')
 s.sessions={};h.PollNative(r);assert(p(r).damage==150)
 s:sample(2,160);h.PollNative(r);assert(p(r).damage==150,'evicted ID must remain excluded')
end)
test('successful enumeration absence permanently excludes a same-name reused ID',function()
 local h,r,s=boot();s:sample(2,100);h.PollNative(r)
 local gaps=r.history.native.gaps;s.sessions={};h.PollNative(r)
 assert(p(r).damage==100 and r.history.native.sessions[2].excluded,'absent ID must be excluded without losing credit')
 assert(r.history.native.gaps>gaps,'absence must record a gap')
 s:sample(2,900,0,nil,nil,20);h.PollNative(r)
 assert(p(r).damage==100 and r.history.native.sessions[2].excluded,'same-name nondecreasing reuse must never credit')
 local saved=r.history;h.Resume(r,saved);h.PollNative(r)
 assert(p(r).damage==100 and r.history.native.sessions[2].excluded,'exclusion must survive reload')
end)
test('failed enumeration does not prove an eligible ID absent',function()
 local h,r,s=boot();s:sample(2,100);h.PollNative(r)
 s.fail=true;s.sessions={};h.PollNative(r);s.fail=false
 s:sample(2,150);h.PollNative(r)
 assert(p(r).damage==150 and not r.history.native.sessions[2].excluded)
end)
test('native and CLEU overlap use maximum not addition',function()
 local h,r,s=boot();s:sample(2,100);h.PollNative(r)
 h.Observe(r,{[2]='SWING_DAMAGE',[4]='Player-1',[8]='Creature-1',[12]=50,[13]=0});assert(p(r).damage==100)
 s:sample(2,120);h.PollNative(r);assert(p(r).damage==120)
 h.Observe(r,{[2]='SWING_DAMAGE',[4]='Player-1',[8]='Creature-1',[12]=100,[13]=0});assert(p(r).damage==150)
end)
test('conflicting GUID never aliases full name',function()
 local h,r,s=boot();s:sample(2,100,0,'Me-Realm','Player-Wrong');h.PollNative(r);assert(p(r).damage==0)
end)
test('counter reset quarantines ID rather than inventing generation',function()
 local h,r,s=boot();s:sample(2,100);h.PollNative(r);s:sample(2,10);h.PollNative(r);s:sample(2,200);h.PollNative(r)
 assert(p(r).damage==100,'reset ID must stay quarantined');assert(r.history.native.gaps>0)
end)
test('metadata and duration contradictions quarantine IDs',function()
 for _,change in ipairs({'name','duration'}) do
  local h,r,s=boot();s:sample(2,100);h.PollNative(r);s:sample(2,200)
  if change=='name' then s.sessions[1].name='Different' else s.data[2][0].durationSeconds=1 end
  h.PollNative(r);assert(p(r).damage==100,change)
 end
end)
test('unavailable initial enumeration defers baseline with explicit gap',function()
 local h,r,s=boot();r.history.native=nil;s.fail=true;h.PollNative(r);s.fail=false;s:sample(2,900);h.PollNative(r)
 assert(p(r).damage==0 and r.history.native.gaps>0);s:sample(3,10);h.PollNative(r);assert(p(r).damage==10)
end)
test('archive collects final readable snapshot exactly once then freezes',function()
 local h,r,s=boot();s:sample(2,100);r.active=false;r.complete=true;assert(h.Archive(r,'completed',false))
 assert(h.List()[1].players[1].damage==100,'final snapshot missing');s:sample(3,900);h.PollNative(r);h.Archive(r,'completed',false)
 assert(h.List()[1].players[1].damage==100 and p(r).damage==100)
end)
test('status reports independent readable metrics errors gaps and final limits',function()
 local h,r,s=boot();s:sample(2,0);h.PollNative(r);local summary,status=h.NativeStatus(r)
 assert(type(summary)=='string' and status.damageKnown and not status.healingKnown and status.samples>0)
 C_DamageMeter.GetCombatSessionFromID=function() error('protected') end;h.PollNative(r)
 summary,status=h.NativeStatus(r);assert(status.errors>0 and status.gaps>0)
 h.Archive(r,'completed',false);summary,status=h.NativeStatus(r);assert(status.frozen and summary:find('boundary'))
end)
test('native zero archive survives validated list and fresh storage roundtrip',function()
 for _,kind in ipairs({0,2}) do
  local h,r,s,ns=boot();s:sample(2,0,kind);h.PollNative(r);assert(h.Archive(r,'completed',false))
  local v=assert(h.Validate(h.List()[1]));assert(v.combatObserved==nil)
  ForeverPlusDB={history={v}};assert(loadfile('History.lua'))('ForeverPlus',ns);h=ns.History
  local row=h.List()[1];local field=kind==0 and 'damage' or 'healing';local other=kind==0 and 'healing' or 'damage'
  assert(row.coverage=='partial','validated native zero lost coverage after fresh storage')
  assert(row.players[1][field]==0 and row.players[1][field..'Known']==true and not row.players[1][other..'Known'])
 end
end)
test('public unit baseline preserves independent deaths availability',function()
 local h,r,s=boot();assert(p(r).deathsKnown==true and not p(r).damageKnown)
 s:sample(2,0);h.PollNative(r);h.Archive(r,'completed',false)
 local saved=h.List()[1].players[1];assert(saved.damageKnown and not saved.healingKnown and saved.deathsKnown)
end)
test('core polls once per party scan and final context works after complete',function()
 local h,_,s,ns=boot();assert(loadfile('Dungeons.lua'))('ForeverPlus',ns)
 GetTime=function() return s.clock or 100 end
 GetInstanceInfo=function() return 'Ragefire Chasm','party',1,'Normal',5,0,false,389 end
 GetRealZoneText=function() return 'Ragefire Chasm' end
 CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,f) s.event=f end} end
 C_Timer={After=function(_,f) f() end,NewTicker=function(_,f) s.tick=f end};SlashCmdList={}
 assert(loadfile('ForeverPlus.lua'))('ForeverPlus',ns)
 local r=ns.StartRun(ns.DUNGEONS.rfc);s:sample(2,100);s.tick();assert(p(r).damage==100,'periodic stage missing')
 s:sample(2,150);s.clock=100.1;s.tick();assert(p(r).damage==100,'must not poll every HUD tick')
 s.clock=101;s.tick();assert(p(r).damage==150)
 s:sample(2,200);s.clock=160;ns.CompleteRun('slash','manual');assert(h.List()[1].players[1].damage==200,'inactive final context rejected')
 local output={};DEFAULT_CHAT_FRAME={AddMessage=function(_,message) output[#output+1]=message end};SlashCmdList.FOREVERPLUS('debug');DEFAULT_CHAT_FRAME=nil
 assert(table.concat(output,'\n'):find('Native meter:'),'provider diagnostics missing')
end)
test('different context and combat gates cannot contaminate original run',function()
 local h,r,s=boot();s.context=false;s:sample(2,900);h.PollNative(r);assert(p(r).damage==0)
 s.context=true;h.PollNative(r);assert(p(r).damage==0,'unknown sessions from other context must be baseline excluded')
 s.combat=true;s:sample(3,10);h.PollNative(r);assert(p(r).damage==0);s.combat=false;h.PollNative(r);assert(p(r).damage==10)
end)
test('damage and healing validity are independent including public zero',function()
 local h,r,s=boot();s:sample(2,s.secret,0);s:sample(2,0,2);h.PollNative(r)
 assert(not p(r).damageKnown and p(r).healingKnown and r.history.combatObserved)
 assert(r.history.coverage=='partial' and p(r).damage==0 and p(r).healing==0)
end)
test('secret GUID may use exact public full name but not bare aliases',function()
 local h,r,s=boot();s:sample(2,10,0,'Me-Realm',s.secret);h.PollNative(r);assert(p(r).damage==10)
 s:sample(3,100,0,'Me',s.secret);h.PollNative(r);assert(p(r).damage==10)
 s:sample(4,100,0,'Me-Other',s.secret);h.PollNative(r);assert(p(r).damage==10)
end)
test('entire secret protected or throwing provider data fails closed',function()
 local h,r,s=boot();s:sample(2,100)
 for _,v in ipairs({s.secret,setmetatable({},{__index=function() error('protected') end})}) do
  s.data[2][0]=v;h.PollNative(r);assert(p(r).damage==0 and not r.history.combatObserved)
 end
 s.sessions=s.secret;h.PollNative(r);assert(p(r).damage==0)
end)
test('nested restricted source and nonfinite negative amounts never credit zero',function()
 local h,r,s=boot()
 for _,amount in ipairs({s.secret,-1,math.huge,0/0}) do s:sample(2,amount);h.PollNative(r);assert(not p(r).damageKnown) end
 s:sample(2,10);s.data[2][0].combatSources=s.secret;h.PollNative(r);assert(p(r).damage==0)
 s:sample(2,10);s.data[2][0].durationSeconds=s.secret;h.PollNative(r);assert(p(r).damage==0)
end)
test('provider unavailable never turns absent metrics into known zeros',function()
 local h,r,s=boot();C_DamageMeter=nil;h.PollNative(r);h.Archive(r,'completed',false)
 local v=h.List()[1];assert(v.coverage=='unavailable' and not v.players[1].damageKnown and not v.players[1].healingKnown)
end)
test('owned ledger does not retain mutable native table references',function()
 local h,r,s=boot();s:sample(2,100);h.PollNative(r);s.data[2][0].combatSources[1].totalAmount=999
 assert(p(r).damage==100 and r.history.native.sessions[2].players['Me-Realm'].damage==100)
 local saved=r.history;h.Resume(r,saved);saved.native.sessions[2].players['Me-Realm'].damage=0
 assert(r.history.native.sessions[2].players['Me-Realm'].damage==100)
end)
test('native session ledger stays bounded without evicting credited totals',function()
 local h,r,s=boot();for id=1,140 do s:sample(id,1);h.PollNative(r) end
 local count=0;for _ in pairs(r.history.native.sessions) do count=count+1 end
 assert(count<=128 and p(r).damage==128)
end)
test('completed inactive and practice polls are frozen and blocked final never backfills',function()
 local h,r,s=boot();s:sample(2,100);r.complete=true;h.PollNative(r);assert(p(r).damage==0)
 r.complete=false;r.practice=true;h.PollNative(r);assert(p(r).damage==0)
 r.practice=false;r.active=false;h.PollNative(r);assert(p(r).damage==0)
 s.combat=true;h.Archive(r,'completed',false)
 local summary,status=h.NativeStatus(r);assert(not status.finalReadable and summary:find('Final snapshot unavailable'))
 s.combat=false;h.PollNative(r);h.Archive(r,'completed',false);assert(p(r).damage==0)
end)
test('actual zero CLEU marks only the observed metric known through resume',function()
 local h,r,s=boot();h.Observe(r,{[2]='SWING_DAMAGE',[4]='Player-1',[8]='Creature-1',[12]=0,[13]=0})
 assert(p(r).damageKnown and not p(r).healingKnown);local saved=r.history;h.Resume(r,saved)
 assert(p(r).damageKnown and not p(r).healingKnown)
end)
test('malformed saved native ledger cannot exceed owned session bounds',function()
 local h,r,s=boot();s:sample(2,10);h.PollNative(r);local saved=r.history
 for id=3,140 do saved.native.sessions[id]={name='Fight',players={}} end
 h.Resume(r,saved)
 local count=0;for _ in pairs(r.history.native.sessions) do count=count+1 end
 assert(count<=128,'saved ledger bypassed bound');assert(p(r).damage==10)
end)
test('malformed optional ledger controls reject to fresh baseline preserving credited totals',function()
 local failures={}
 for _,field in ipairs({'frozen','rebaseline','finalReadable','finalBoundary'}) do
  local values=field=='finalBoundary' and {false,7,{},string.rep('x',97),'bad|boundary','bad\nboundary','secret'} or {'false',0,{},'secret'}
  for index,value in ipairs(values) do
   local h,r,s=boot();s:sample(2,100);h.PollNative(r);local saved=r.history
   if value=='secret' then value=s.secret end
   saved.native[field]=value;h.Resume(r,saved);h.PollNative(r)
   local n=r.history.native;local label=field..'['..index..']'
   if not (p(r).damage==100 and n.gaps>0 and n.samples==0 and n.sessions[2] and n.sessions[2].excluded and n.frozen==nil and n.finalReadable==nil and n.finalBoundary==nil) then
    failures[#failures+1]=label
   end
   s:sample(2,900);h.PollNative(r)
   if p(r).damage~=100 then failures[#failures+1]=label..' replay' end
   s:sample(3,150);h.PollNative(r)
   if p(r).damage~=150 then failures[#failures+1]=label..' frozen' end
  end
 end
 assert(#failures==0,'malformed controls accepted: '..table.concat(failures,', '))
end)
test('public optional ledger booleans and bounded boundary survive resume',function()
 for _,value in ipairs({false,true}) do
  local h,r,s=boot();s:sample(2,100);h.PollNative(r);local saved=r.history
  saved.native.frozen=value;saved.native.rebaseline=value;saved.native.finalReadable=value;saved.native.finalBoundary=string.rep('x',96)
  h.Resume(r,saved);local n=r.history.native
  assert(n.frozen==value and n.rebaseline==value and n.finalReadable==value and n.finalBoundary==string.rep('x',96) and n.samples>0)
 end
end)
test('malformed public GUID and conflicting roster identities fail closed',function()
 local h,r,s=boot();s:sample(2,100,0,'Me-Realm',123);h.PollNative(r);assert(p(r).damage==0)
 r.history.players[2]={name='Other-Realm',guid='Player-2',class='MAGE',damage=0,healing=0,deaths=0}
 s:sample(3,100,0,'Other-Realm','Player-1');h.PollNative(r);assert(p(r).damage==0 and r.history.players[2].damage==0)
end)
test('CLEU cannot mutate completed or archived records even with stale active flag',function()
 local h,r,s=boot();r.complete=true
 local e={[2]='SWING_DAMAGE',[4]='Player-1',[8]='Creature-1',[12]=100,[13]=0};h.Observe(r,e);assert(p(r).damage==0)
 r.complete=false;h.Archive(r,'completed',false);h.Observe(r,e);assert(p(r).damage==0)
end)
test('completed ledger reload preserves freeze and boundary limit',function()
 local h,r,s=boot();s:sample(2,10);h.PollNative(r);h.Archive(r,'completed',false);r.complete=true;r.active=false
 local saved=r.history;h.Resume(r,saved);assert(r.history.native.frozen,'reload discarded frozen ledger')
 s:sample(3,999);h.Archive(r,'completed',false);assert(p(r).damage==10)
end)
test('a contradictory player counter rejects whole metric snapshot before credit',function()
 local h,r,s=boot();r.history.players[2]={name='Other-Realm',guid='Player-2',class='MAGE',damage=0,healing=0,deaths=0}
 s:sample(2,100);s.data[2][0].combatSources[2]={name='Other-Realm',sourceGUID='Player-2',totalAmount=50};h.PollNative(r)
 s:sample(2,200);s.data[2][0].combatSources[2]={name='Other-Realm',sourceGUID='Player-2',totalAmount=5};h.PollNative(r)
 assert(p(r).damage==100 and r.history.players[2].damage==50,'contradiction must not partially apply')
end)
for _,t in ipairs(tests) do local ok,e=pcall(t[2]);if not ok then error(t[1]..': '..tostring(e)) end;print('PASS '..t[1]) end
print('meter: '..#tests..' passed')
