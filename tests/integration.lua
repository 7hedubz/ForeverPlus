-- Full TOC-order integration smoke test, using mocked WoW APIs.
local clock, frames, timers, tickers, sent = 100, {}, {}, {}, {}
local kind, dungeonName, instanceID = 'none', '', 0
local cleu
local methods = {}
local function obj(name)
 local o={shown=true,width=140,text='',scripts={},events={}}
 if name then _G[name]=o end
 return setmetatable(o,{__index=function(_,key) return methods[key] or function() end end})
end
methods.CreateTexture=function() return obj() end
methods.CreateFontString=function() return obj() end
methods.SetSize=function(s,w,h) s.width=w;s.height=h end
methods.GetWidth=function(s) return s.width end
methods.SetWidth=function(s,w) s.width=w end
methods.SetHeight=function(s,h) s.height=h end
methods.SetScript=function(s,key,fn) s.scripts[key]=fn end
methods.RegisterEvent=function(s,event) s.events[event]=true end
methods.SetText=function(s,text) s.text=text end
methods.Show=function(s) s.shown=true end
methods.Hide=function(s) s.shown=false end
methods.IsShown=function(s) return s.shown end
methods.GetFont=function() return 'font',12,'' end
CreateFrame=function(_,name) local f=obj(name);frames[#frames+1]=f;return f end
UIParent=obj('UIParent');Minimap=obj('Minimap');GameTooltip=obj('GameTooltip')
DEFAULT_CHAT_FRAME={AddMessage=function() end}
GetTime=function() return clock end
time=function() return 100000+math.floor(clock) end
GetInstanceInfo=function() return dungeonName,kind,1,'Normal',5,0,false,instanceID end
GetRealZoneText=function() return dungeonName end
GetSubZoneText=function() return '' end
GetMinimapZoneText=GetSubZoneText
GetNormalizedRealmName=function() return 'Realm' end
GetRealmName=GetNormalizedRealmName
UnitName=function() return 'Tester' end
UnitExists=function() return false end
IsInInstance=function() return kind=='party' end
IsInGroup=function() return true end
IsInRaid=function() return false end
IsInGuild=function() return false end
issecretvalue=function() return false end
strsplit=function(delim,str) local parts={};for x in str:gmatch('[^'..delim..']+') do parts[#parts+1]=x end;return unpack(parts) end
bit=require('bit')
SlashCmdList={}
C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn} end,NewTicker=function(_,fn) tickers[#tickers+1]=fn end}
C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,SendAddonMessage=function(prefix,payload,channel)
 assert(kind~='party','sent inside instance');sent[#sent+1]={prefix,payload,channel};return 0
end}
CombatLogGetCurrentEventInfo=function() return unpack(cleu) end
local function fire(event,...)
 local copy={unpack(frames)}
 for _,f in ipairs(copy) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
local function advance(seconds)
 local target=clock+seconds
 for step=1,10000 do
  table.sort(timers,function(a,b) return a.at<b.at end)
  if #timers==0 or timers[1].at>target then clock=target;for _,fn in ipairs(tickers) do fn() end;return end
  local t=table.remove(timers,1);clock=t.at;t.fn()
 end
 error('runaway timer queue')
end
local function loadAddon()
 local ns={}
 for _,name in ipairs({'Dungeons.lua','ForeverPlus.lua','UI.lua','Comm.lua'}) do assert(loadfile(name))('ForeverPlus',ns) end
 fire('ADDON_LOADED','ForeverPlus');fire('PLAYER_LOGIN');return ns
end
local ns=loadAddon();fire('PLAYER_ENTERING_WORLD');advance(6)
kind,dungeonName,instanceID='party','Ragefire Chasm',389
fire('PLAYER_ENTERING_WORLD');advance(1)
assert(ns.GetRun().active)
local function emit(sub,guid,name)
 cleu={clock,sub,false,'Player-1','Tester',1,0,guid,name,2112,0}
 fire('COMBAT_LOG_EVENT_UNFILTERED')
end
for _,boss in ipairs(ns.DUNGEONS.rfc.bosses) do
 fire('BOSS_KILL',0,boss.n)
end
local before=#sent
advance(60)
for i=1,50 do
 local guid='Creature-0-0-0-0-999-'..i
 emit('SPELL_DAMAGE',guid,'Trash');emit('UNIT_DIED',guid,'Trash')
end
assert(ns.GetRun().complete)
assert(ns.GetBest('rfc').sec>=60)
advance(10);assert(#sent==before,'completion broadcast inside instance')
fire('ZONE_CHANGED_NEW_AREA');advance(1);assert(not ns.GetRun().active,'completed session restarted')
kind,dungeonName,instanceID='none','Outside',0
fire('PLAYER_ENTERING_WORLD');advance(10)
local shared=false
for i=before+1,#sent do if sent[i][2]:find('rfc=',1,true) then shared=true end end
assert(shared,'leaving did not flush completion share')
ns.ToggleDemo();advance(1);SlashCmdList.FOREVERPLUS('complete')
assert(ns.GetBest('demo')==nil)
ns.ToggleDemo();advance(1)
assert(ns.GetRun()==nil)
assert(ForeverPlusFrame.deaths.text=='Deaths: 0')
print('PASS full TOC load, login, dungeon clear, no in-instance sends, queued share, demo isolation')
