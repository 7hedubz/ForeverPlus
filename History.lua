local _, ns = ...
local H = {}; ns.History = H
local function secret(v) return ns.IsSecret and ns.IsSecret(v) end
local function text(v,n,empty)
 return not secret(v) and type(v)=='string' and #v<=n and (empty or #v>0) and not v:find('[%c|]')
end
local function num(v,max,integer)
 return not secret(v) and type(v)=='number' and v==v and v>=0 and v<=max and (not integer or v==math.floor(v))
end
local function identity(v)
 if not text(v,96) then return end
 local name,realm=v:match('^([^%s%-]+)%-(.+)$')
 if not name then return end
 realm=realm:gsub('%s+',''); if realm=='' then return end
 return name..'-'..realm
end
function H.SamePlayer(a,b)
 a,b=identity(a),identity(b)
 return a~=nil and b~=nil and a:lower()==b:lower()
end
local classes={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,DEATHKNIGHT=true,SHAMAN=true,MAGE=true,WARLOCK=true,MONK=true,DRUID=true,DEMONHUNTER=true,EVOKER=true,['']=true}
local function validate(r)
 if secret(r) or type(r)~='table' or getmetatable(r) then return nil,'record' end
 if not text(r.id,96) or not text(r.dungeonKey,64) or r.dungeonKey=='demo' or not text(r.dungeonName,96) then return nil,'identity' end
 if secret(r.chest) or (r.chest~=nil and not num(r.chest,3,true)) then return nil,'chest' end
 if not num(r.startUnix,1e12,true) or not num(r.endUnix,1e12,true) or r.endUnix<r.startUnix or not num(r.sec,86400) or r.sec<=0 then return nil,'time' end
 if secret(r.status) or (r.status~='completed' and r.status~='abandoned' and r.status~='reset') or secret(r.manual) or type(r.manual)~='boolean' then return nil,'status' end
 if secret(r.coverage) or (r.coverage~='observed' and r.coverage~='partial' and r.coverage~='unavailable') then return nil,'coverage' end
 local who=identity(r.recordedBy); if not who then return nil,'observer' end
 if secret(r.players) or type(r.players)~='table' or getmetatable(r.players) then return nil,'players' end
 local count=0
 for k in pairs(r.players) do count=count+1; if count>10 or not num(k,10,true) or k<1 then return nil,'roster' end end
 if count<1 then return nil,'empty' end
 local out={id=r.id,dungeonKey=r.dungeonKey,dungeonName=r.dungeonName,startUnix=r.startUnix,endUnix=r.endUnix,sec=r.sec,chest=ns.ChestForTime(r.sec),status=r.status,manual=r.manual,recordedBy=who,coverage=r.coverage,players={}}
 local names,guids={},{}
 for i=1,count do
  local p=r.players[i]
  if secret(p) or type(p)~='table' or getmetatable(p) then return nil,'player' end
  local name=identity(p.name)
  if not name or not text(p.guid,96,true) or not text(p.class,16,true) or not classes[p.class] or not num(p.damage,1e15) or not num(p.healing,1e15) or not num(p.deaths,100000,true) then return nil,'stats' end
  if names[name:lower()] or (p.guid~='' and guids[p.guid]) then return nil,'duplicate player' end
  names[name:lower()]=true; if p.guid~='' then guids[p.guid]=true end
  out.players[i]={guid=p.guid,name=name,class=p.class,damage=p.damage,healing=p.healing,deaths=p.deaths}
 end
 if not names[who:lower()] then return nil,'observer absent' end
 return out
end
function H.Validate(r)
 local ok,v,why=pcall(validate,r); if ok then return v,why end
 return nil,'restricted'
end
local cached, rows
local function storage()
 local d=ForeverPlusDB
 if secret(d) or type(d)~='table' then d={}; ForeverPlusDB=d end
 if cached==d and rows==d.history then return rows,d end
 local clean={}
 if not secret(d.history) and type(d.history)=='table' and not getmetatable(d.history) then
  for i=1,500 do local raw=d.history[i]; local v=H.Validate(raw); if v then v._local=not secret(raw._local) and raw._local==true; clean[#clean+1]=v end end
 end
 table.sort(clean,function(a,b) return a.endUnix>b.endUnix or (a.endUnix==b.endUnix and a.id>b.id) end)
 d.history=clean; cached,rows=d,clean
 -- Aliases are session-local: wire records and saved history stay bounded.
 H.aliases={}
 return rows,d
end
local function contains(r,name)
 for _,p in ipairs(r.players) do if H.SamePlayer(p.name,name) then return true end end
 return false
end
local function fuzzy(a,b)
 if a.dungeonKey~=b.dungeonKey or a.status~=b.status or #a.players~= #b.players or #a.players<2 then return false end
 if (a.manual and a.sec<120) or (b.manual and b.sec<120) then return false end
 if math.abs(a.endUnix-b.endUnix)>30 or math.abs(a.startUnix-b.startUnix)>120 then return false end
 if math.min(a.endUnix,b.endUnix)-math.max(a.startUnix,b.startUnix)<math.min(a.sec,b.sec)*0.8 then return false end
 for _,p in ipairs(a.players) do if not contains(b,p.name) then return false end end
 return true
end
local rank={unavailable=0,partial=1,observed=2}
local function store(v,localObservation)
 local list=storage(); v._local=localObservation==true
 for i,old in ipairs(list) do
  if old.id==v.id or H.aliases[v.id]==old.id or fuzzy(old,v) then
   local incomingID=v.id
   local localOld=old._local==true; local localNew=v._local==true
   if (localNew and not localOld) or (localNew==localOld and rank[v.coverage]>rank[old.coverage]) then
    local id=old.id; list[i]=v; v.id=id
   end
   local aliasCount=0; for _ in pairs(H.aliases) do aliasCount=aliasCount+1 end
   if aliasCount>=2000 then H.aliases={} end
   H.aliases[incomingID]=old.id
   return true
  end
 end
 list[#list+1]=v
 table.sort(list,function(a,b) return a.endUnix>b.endUnix or (a.endUnix==b.endUnix and a.id>b.id) end)
 while #list>500 do local gone=table.remove(list); for k,id in pairs(H.aliases) do if id==gone.id then H.aliases[k]=nil end end end
 local n=0; for _ in pairs(H.aliases) do n=n+1 end; if n>2000 then H.aliases={} end
 return true
end
function H.Receive(r,sender)
 local v,why=H.Validate(r); if not v then return false,why end
 if not contains(v,sender) or not contains(v,ns.PlayerFull and ns.PlayerFull()) then return false,'participants' end
 return store(v)
end
function H.List(key)
 local out={}; for _,r in ipairs(storage()) do if key==nil or key==r.dungeonKey then out[#out+1]=H.Validate(r) end end
 return out
end
function H.Get(id)
 local list=storage(); if not text(id,96) then return end
 for _,r in ipairs(list) do if r.id==id or H.aliases[id]==r.id then return H.Validate(r) end end
end
function H.ExportFor(name)
 local out={}; for _,r in ipairs(storage()) do if contains(r,name) and contains(r,ns.PlayerFull and ns.PlayerFull()) then out[#out+1]=H.Validate(r) end end
 return out
end
local function read(fn,...)
 if type(fn)~='function' then return end
 local ok,a,b=pcall(fn,...); if ok and not secret(a) and not secret(b) then return a,b end
end
local function find(s,guid,name)
 for _,p in ipairs(s.players) do if (guid and guid~='' and p.guid==guid) or (name and H.SamePlayer(p.name,name)) then return p end end
end
local function unitIdentity(u)
 -- Do not collapse a restricted GUID into nil and then attribute it by name.
 local ok,guid=pcall(UnitGUID,u)
 if not ok or secret(guid) or (guid~=nil and not text(guid,96,true)) then return end
 local name,realm=read(UnitFullName,u)
 if not text(name,96) then name,realm=read(UnitName,u) end
 if text(name,96) and not name:find('-',1,true) then
  if not text(realm,96) then realm=read(GetNormalizedRealmName) or read(GetRealmName) end
  if text(realm,96) then name=name..'-'..realm:gsub('%s+','') end
 end
 return guid or '',identity(name)
end
local function deathPlayer(s,guid,localPlayer,name)
 if secret(guid) then return end
 if guid~=nil and guid~='' then return text(guid,96) and find(s,guid) end
 return find(s,nil,name or (localPlayer and ns.PlayerFull()))
end
function H.Roster(r,petOnly)
 if not r or r.practice or not r.history then return end
 local s=r.history
 local units={'player','party1','party2','party3','party4'}
 -- Summon evidence lasts for the owner's roster session, not the primary-pet snapshot.
 s.primaryPets={}; local owners={}
 for _,u in ipairs(units) do
  if u=='player' or read(UnitExists,u)==true then
   local guid,name=unitIdentity(u)
   if guid and name then
    local p=find(s,guid,name)
    if not p and #s.players<10 then
     local _,class=read(UnitClass,u); if not text(class,16,true) or not classes[class] then class='' end
     p={guid=guid,name=name,class=class,damage=0,healing=0,deaths=0};s.players[#s.players+1]=p
    end
    if p then
     if p.guid=='' and guid~='' then
      for _,field in ipairs({'dead','states'}) do
       if s[field] then s[field][guid]=s[field][p.name];s[field][p.name]=nil end
      end
      p.guid=guid
     end
     if p.guid~='' and guid==p.guid then owners[p.guid]=true end
     local pet=read(UnitGUID,u=='player' and 'pet' or 'partypet'..u:match('%d+'))
     if text(pet,96) and owners[p.guid] then s.primaryPets[pet]=p.guid end
     if not petOnly then H.UnitState(r,u) end
    end
   end
  end
 end
 s.owners=owners
 for pet,owner in pairs(s.pets) do if not owners[owner] then s.pets[pet]=nil end end
end
function H.Start(r)
 if r.practice then return end
 local _,d=storage(); d.historyNonce=(num(d.historyNonce,1e12,true) and d.historyNonce or 0)+1
 local guid=read(UnitGUID,'player'); if not text(guid,48) then guid=(identity(ns.PlayerFull()) or 'unknown'):sub(1,64) end
 r.history={id=guid..':'..r.startUnix..':'..d.historyNonce,recordedBy=ns.PlayerFull(),players={},dead={},pets={},coverage='unavailable'}
 H.Roster(r)
end
function H.Resume(r,saved)
 H.Start(r)
 if secret(saved) or type(saved)~='table' or getmetatable(saved) then return end
 local candidate={id=saved.id,dungeonKey=r.key,dungeonName=r.name,startUnix=r.startUnix,endUnix=math.max(r.startUnix,read(time) or r.startUnix),sec=1,status='abandoned',manual=false,recordedBy=saved.recordedBy,coverage='partial',players=saved.players}
 local v=H.Validate(candidate); if not v then return end
 r.history={id=v.id,recordedBy=v.recordedBy,players=v.players,coverage='partial',dead={},states={},pets={}}
 for _,field in ipairs({'dead','states'}) do
  if not secret(saved[field]) and type(saved[field])=='table' and not getmetatable(saved[field]) then
   for _,p in ipairs(v.players) do
    local key=p.guid~='' and p.guid or p.name;local value=saved[field][key]
    if not secret(value) and type(value)=='boolean' then r.history[field][key]=value end
   end
  end
 end
 H.Roster(r)
end
local function forgetPets(s,guid)
 if not text(guid,96) then return end
 for _,map in ipairs({s.pets,s.primaryPets or {}}) do
  for pet,owner in pairs(map) do if pet==guid or owner==guid then map[pet]=nil end end
 end
end
function H.Death(r,guid,localPlayer,name)
 if not r or not r.active or r.complete or r.practice or not r.history then return false end
 local s=r.history; forgetPets(s,guid); local p=deathPlayer(s,guid,localPlayer,name)
 if not p then return false end
 local key=p.guid~='' and p.guid or p.name
 if s.dead[key] then return false end
 s.dead[key]=true;p.deaths=math.min(100000,p.deaths+1)
 if H.SamePlayer(p.name,ns.PlayerFull()) then r.deaths=(r.deaths or 0)+1 end
 return true
end
function H.TotalDeaths(r)
 local total=0
 if r and r.history then for _,p in ipairs(r.history.players) do total=total+(p.deaths or 0) end end
 return total
end
function H.UnitState(r,u,resurrection)
 if not r or not r.active or r.complete or r.practice or not r.history then return end
 if not text(u,16) or (u~='player' and not u:match('^party[1-4]$')) or read(UnitExists,u)~=true then return end
 local s=r.history;local guid,name=unitIdentity(u)
 if not guid then return end
 local p=deathPlayer(s,guid,false,name)
 if not p then return end
 local key=p.guid~='' and p.guid or p.name
 s.states=s.states or {}
 local dead=read(UnitIsDeadOrGhost,u)
 if type(dead)~='boolean' then return end
 if s.states[key]==nil then
  -- The first readable state is a baseline, not an inferred death.
  s.states[key]=dead;if dead then s.dead[key]=true end
 elseif dead then H.Death(r,guid,false,name);s.states[key]=true
 elseif not s.dead[key] or s.states[key]==true or resurrection then
  -- Passive alive reads cannot undo a death notification until the corpse was
  -- actually observed. Explicit resurrection events still require readable alive.
  H.Alive(r,guid,false,name);s.states[key]=false
 end
end
function H.UnitDeath(r,u)
 if read(UnitExists,u)~=true then return false end
 local guid,name=unitIdentity(u)
 if guid then return H.Death(r,guid,false,name) end
 return false
end
function H.Alive(r,guid,localPlayer,name)
 if not r or not r.history then return end
 local p=deathPlayer(r.history,guid,localPlayer,name)
 if p then r.history.dead[p.guid~='' and p.guid or p.name]=nil end
end
function H.Observe(r,e)
 if not r or not r.active or r.practice or not r.history then return end
 local s=r.history
 local kind,src,dst=e[2],e[4],e[8]
 if secret(kind) or not text(kind,64) or secret(src) or secret(dst) then s.coverage='partial';return end
 if kind=='UNIT_DIED' then H.Death(r,dst);return end
 if kind=='UNIT_DESTROYED' or kind=='UNIT_DISSIPATES' then forgetPets(s,dst);return end
 if kind=='SPELL_RESURRECT' then
  if text(dst,96) then
   for _,u in ipairs({'player','party1','party2','party3','party4'}) do
    local guid=unitIdentity(u);if guid==dst then H.UnitState(r,u,true) end
   end
  end
  return
 end
 local petOwner=text(src,96) and (s.pets[src] or (s.primaryPets and s.primaryPets[src]))
 local owner=text(src,96) and (find(s,src) or (petOwner and find(s,petOwner)))
 if not owner then return end
 if kind=='SPELL_SUMMON' then
  if text(dst,96) and s.owners and s.owners[owner.guid] then
   local count=0; for _ in pairs(s.pets) do count=count+1 end
   if count<100 then s.pets[dst]=owner.guid end
  end
  return
 end
 local damage=kind=='SWING_DAMAGE' or kind=='SPELL_DAMAGE' or kind=='SPELL_PERIODIC_DAMAGE' or kind=='RANGE_DAMAGE' or kind=='DAMAGE_SHIELD' or kind=='DAMAGE_SPLIT'
 local heal=kind=='SPELL_HEAL' or kind=='SPELL_PERIODIC_HEAL'
 if not damage and not heal then return end
 local offset=kind=='SWING_DAMAGE' and 12 or 15
 local amount,excess=e[offset],e[offset+1]
 if not num(amount,1e15) or secret(excess) or type(excess)~='number' or excess~=excess or excess< -1 or excess>1e15 then s.coverage='partial';return end
 local effective=math.max(0,amount-math.max(0,excess))
 local field=heal and 'healing' or 'damage';owner[field]=math.min(1e15,owner[field]+effective)
 -- Forever may restrict events without notifying addons. Never claim complete coverage.
 s.coverage='partial'
end
function H.Archive(r,status,manual)
 if not r or r.practice or not r.history then return end
 H.Roster(r)
 local s=r.history
 local v,why=H.Validate({id=s.id,dungeonKey=r.key,dungeonName=r.name,startUnix=r.startUnix,endUnix=math.max(r.startUnix,read(time) or r.startUnix),sec=math.max(0.001,ns.Elapsed(r)),status=status,manual=manual==true,recordedBy=s.recordedBy,coverage=s.coverage,players=s.players})
 if not v then return false,why end
 local ok=store(v,true); if ns.UI and ns.UI.RefreshBoard then ns.UI.RefreshBoard() end
 if ok and ns.Sync and ns.Sync.Request then ns.Sync.Request('archive') end
 return ok
end
