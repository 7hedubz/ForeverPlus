-- Run from addon root: luajit tests/ui.lua
local ns, methods = {}, {}
local function obj(name)
 local o={shown=true,width=140,text='',scripts={}}
 if name then _G[name]=o end
 return setmetatable(o,{__index=function(_,k) return methods[k] or function() end end})
end
methods.CreateTexture=function() return obj() end
methods.CreateFontString=function() return obj() end
methods.SetSize=function(s,w,h) s.width=w;s.height=h end
methods.SetWidth=function(s,w) s.width=w end
methods.SetHeight=function(s,h) s.height=h end
methods.GetWidth=function(s) return s.width end
methods.SetScript=function(s,k,v) s.scripts[k]=v end
methods.SetText=function(s,v) s.text=v end
methods.Show=function(s) s.shown=true end
methods.Hide=function(s) s.shown=false end
methods.IsShown=function(s) return s.shown end
methods.GetFont=function() return 'font',12,'' end
CreateFrame=function(_,name) return obj(name) end
UIParent=obj('UIParent');Minimap=obj('Minimap');GameTooltip=obj('GameTooltip')
GetTime=function() return 100 end
local run=nil
local db={pos={},minimap={},best={},peers={},showMinimap=true}
ns.DB=function() return db end
ns.GetRun=function() return run end
ns.GetBest=function() return nil end
ns.Elapsed=function() return 10 end
assert(loadfile('Dungeons.lua'))('ForeverPlus',ns)
assert(loadfile('UI.lua'))('ForeverPlus',ns)
ns.UI.Init();ns.UI.Show();ns.UI.ToggleBoard();ns.UI.RefreshBoard()
run={key='rfc',name='Ragefire Chasm',active=true,deaths=7,kills=20,dungeon=ns.DUNGEONS.rfc,bossDown={}}
ns.UI.Tick()
assert(ForeverPlusFrame.deaths.text=='Deaths: 7')
run=nil;ns.UI.Tick()
assert(ForeverPlusFrame.deaths.text=='Deaths: 0','idle deaths were not cleared')
assert(ForeverPlusFrame.obj.text=='Bosses 0/0     Forces 0%','idle objectives were not cleared')
assert(ForeverPlusFrame.best.text=='Best: —','idle best was not cleared')
assert(ForeverPlusFrame.fill.width==1,'idle bar was not reset')
print('PASS idle HUD clears all previous run fields')
run={key='shapers',name="Shaper's Terrace",active=true,deaths=0,kills=50,dungeon=ns.DUNGEONS.shapers,bossDown={}}
ns.UI.Tick()
assert(ForeverPlusFrame.obj.text:find('manual',1,true),'manual roster needs explicit HUD label')
print('PASS unverified roster is labeled manual')
print('UI tests passed (mock API, not client rendering)')
