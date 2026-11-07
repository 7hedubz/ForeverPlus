-- Run from addon root: luajit tests/ui.lua
local ns, methods = {}, {}
local function obj(name)
 local o={shown=true,width=140,text='',scripts={}}
 if name then _G[name]=o end
 return setmetatable(o,{__index=function(_,k) if methods[k] then return methods[k] end;if k:match('^[A-Z]') then return function() end end end})
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
local records={
 {id='r1',dungeonKey='rfc',dungeonName='Ragefire Chasm',startUnix=1000,endUnix=1300,sec=300,chest=3,status='completed',manual=false,recordedBy='Tester-Realm',coverage='observed',players={{name='Tester-Realm',class='DRUID',damage=12345,healing=5000,deaths=2},{name='Friend-Realm',class='MAGE',damage=20000,healing=0,deaths=1}}},
 {id='r2',dungeonKey='dm',dungeonName='The Deadmines',startUnix=2000,endUnix=2600,sec=600,chest=3,status='abandoned',manual=false,recordedBy='Friend-Realm',coverage='partial',players={{name='Friend-Realm',class='MAGE',damage=1000,healing=0,deaths=0}}}
}
ns.History={List=function(key) local out={};for _,r in ipairs(records) do if not key or r.dungeonKey==key then out[#out+1]=r end end;return out end,Get=function(id) for _,r in ipairs(records) do if r.id==id then return r end end end}
local syncs=0
local syncStatus='Ready'
ns.Sync={Request=function() syncs=syncs+1 end,Status=function() return syncStatus end}
assert(type(ns.UI.SelectDungeon)=='function','missing dungeon selection API')
ns.UI.SelectDungeon('rfc')
assert(ForeverPlusBoard.selectedDungeon=='rfc')
assert(#ForeverPlusBoard.visibleRuns==1 and ForeverPlusBoard.visibleRuns[1].id=='r1','dungeon filter failed')
ns.UI.SelectRun('r1')
assert(ForeverPlusBoard.playerLines[1].name.text=='Tester-Realm')
assert(ForeverPlusBoard.playerLines[1].deaths.text=='2')
assert(ForeverPlusBoard.playerLines[1].damage.text:find('12.3',1,true))
ForeverPlusBoard.syncButton.scripts.OnClick()
assert(syncs==1,'board sync action missing')
ForeverPlusMinimapButton.scripts.OnClick(nil,'RightButton')
assert(ForeverPlusMinimapMenu:IsShown(),'right click did not open menu')
ForeverPlusMinimapMenu.syncButton.scripts.OnClick()
assert(syncs==2,'minimap sync action missing')
ns.UI.SelectDungeon('dm')
assert(ForeverPlusBoard.selectedRun=='r2')
assert(ForeverPlusBoard.coverage.text:find('Partial',1,true))
records[2].players[1].name='Bad|Ttexture:99|tName'
ns.UI.RefreshBoard()
assert(not ForeverPlusBoard.playerLines[1].name.text:find('|',1,true),'unsafe WoW text markup')
ns.UI.SelectDungeon('shapers')
assert(ForeverPlusBoard.selectedRun==nil,'empty dungeon retained previous selection')
assert(not ForeverPlusBoard.playerLines[1].shown,'empty dungeon retained player rows')
print('PASS dungeon and run selection, participant stats, sync actions, empty state and safe text')
if not ForeverPlusBoard:IsShown() then ns.UI.ToggleBoard() end
ns.UI.HideNow()
syncStatus='Sync idle.'
ns.UI.Tick()
assert(ForeverPlusBoard.syncStatus.text=='Sync idle.','sync status does not refresh when timer is hidden')
print('PASS journal sync status updates while timer is hidden')
ns.UI.SelectDungeon('rfc')
assert(ForeverPlusBoard.sortButton,'dungeon sort toggle is missing')
assert(ForeverPlusBoard.sortButton.text=='Alphabetical')
assert(ForeverPlusBoard.dungeonLines[1].key=='*','All dungeons must stay pinned')
local count=0
for key,d in pairs(ns.DUNGEONS) do
 assert(type(d.levelMin)=='number' and type(d.levelMax)=='number' and d.levelMin<=d.levelMax,'missing or invalid level range: '..key)
 count=count+1
end
assert(count==35,'catalog level coverage changed unexpectedly')
assert(ns.DUNGEONS.rfc.levelMin==13 and ns.DUNGEONS.rfc.levelMax==18)
assert(ns.DUNGEONS.ubrs.levelMin==59 and ns.DUNGEONS.ubrs.levelMax==60)
ForeverPlusBoard.sortButton.scripts.OnClick()
assert(db.dungeonSort=='level' and ForeverPlusBoard.sortButton.text=='Level Range')
assert(ForeverPlusBoard.dungeonLines[2].key=='thanes','minimum+maximum tie must sort alphabetically')
assert(ForeverPlusBoard.dungeonLines[3].key=='rfc')
assert(ForeverPlusBoard.dungeonLines[4].key=='lordaeron')
assert(ForeverPlusBoard.dungeonLines[5].key=='wc' and ForeverPlusBoard.dungeonLines[6].key=='dm','same minimum must sort by maximum')
assert(ForeverPlusBoard.dungeonLines[3].count.text:find('13–18',1,true),'range not visible')
assert(ForeverPlusBoard.selectedDungeon=='rfc' and ForeverPlusBoard.selectedRun=='r1','sort lost run selection')
records[#records+1]={id='unknown',dungeonKey='name:annex',dungeonName='Aardvark Annex',sec=5,chest=3,status='completed',endUnix=2700,recordedBy='Tester-Realm',coverage='unavailable',players={}}
ns.UI.RefreshBoard()
local last
for _,row in ipairs(ForeverPlusBoard.dungeonLines) do if row.shown then last=row.key end end
assert(last=='name:annex','unknown level should sort last')
assert(loadfile('UI.lua'))('ForeverPlus',ns);ns.UI.Init();ns.UI.RefreshBoard()
assert(ForeverPlusBoard.sortButton.text=='Level Range','sort preference not restored on UI reload')
ForeverPlusBoard.sortButton.scripts.OnClick()
assert(db.dungeonSort=='alpha' and ForeverPlusBoard.sortButton.text=='Alphabetical')
assert(ForeverPlusBoard.dungeonLines[2].key=='name:annex','alphabetical mode not restored')
assert(loadfile('UI.lua'))('ForeverPlus',ns);ns.UI.Init();ns.UI.RefreshBoard()
assert(ForeverPlusBoard.sortButton.text=='Alphabetical')
db.dungeonSort='bad';ns.UI.RefreshBoard();assert(db.dungeonSort=='alpha')
print('PASS alphabetical/level toggle, all catalog ranges, ties, selection, unknowns and saved preference')
