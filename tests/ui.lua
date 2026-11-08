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
methods.SetEnabled=function(s,v) s.enabled=v end
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
local elapsed=10
ns.Elapsed=function() return elapsed end
assert(loadfile('Dungeons.lua'))('ForeverPlus',ns)
assert(loadfile('UI.lua'))('ForeverPlus',ns)
ns.UI.Init();ns.UI.Show();ns.UI.ToggleBoard();ns.UI.RefreshBoard()
run={key='rfc',name='Ragefire Chasm',active=true,deaths=7,kills=20,dungeon=ns.DUNGEONS.rfc,bossDown={}}
ns.UI.Tick()
assert(ForeverPlusFrame.deaths.text=='Deaths: 7')
local historyNS={};assert(loadfile('History.lua'))('ForeverPlus',historyNS)
ns.History=historyNS.History
run.history={players={{deaths=0},{deaths=1}}};run.deaths=0;ns.UI.Tick()
assert(ForeverPlusFrame.deaths.text=='Deaths: 1','HUD must show party total rather than legacy local deaths')
assert(run.deaths==0,'HUD must not mutate local counter')
ns.History=nil
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
-- Abandon is an explicit confirmed/voted action, never a direct UI reset.
local requests, casts, direct = 0, {}, 0
local vote
ns.AbandonRun=function() direct=direct+1 end
ns.Vote={Request=function() requests=requests+1;vote={id='local1',phase='confirm',text='Abandon this local run only?',canVote=true} end,
 Get=function() return vote end,
 Cast=function(yes) casts[#casts+1]=yes;vote={id='local1',phase=yes and 'passed' or 'cancelled',text=yes and 'Abandoned.' or 'Cancelled.',canVote=false} end}
run={key='rfc',name='Ragefire Chasm',active=true,deaths=0,kills=2,dungeon=ns.DUNGEONS.rfc,bossDown={}}
ns.UI.Show();ns.UI.Tick()
assert(ForeverPlusFrame.abandonButton,'HUD lacks abandon button')
assert(ForeverPlusFrame.height>=184,'abandon band overlaps old HUD rows')
ForeverPlusFrame.abandonButton.scripts.OnClick()
assert(requests==1 and direct==0,'abandon bypassed voting/confirmation')
assert(ForeverPlusAbandonVote:IsShown(),'local confirmation not shown')
assert(ForeverPlusAbandonVote.message.text:find('local',1,true))
ForeverPlusAbandonVote.noButton.scripts.OnClick()
assert(casts[1]==false and direct==0,'No must route to vote module')
ForeverPlusAbandonVote.closeButton.scripts.OnClick();ns.UI.Tick()
assert(not ForeverPlusAbandonVote:IsShown(),'dismissed terminal vote reopened')
ns.UI.HideNow();vote={id='remote2',phase='vote',text='Friend asks to abandon. Yes 1/2.',canVote=true,deadline=120}
ns.UI.Tick()
assert(ForeverPlusAbandonVote:IsShown(),'remote vote hidden with HUD')
assert(ForeverPlusAbandonVote.yesButton.shown and ForeverPlusAbandonVote.noButton.shown)
ForeverPlusAbandonVote.yesButton.scripts.OnClick()
assert(casts[2]==true and direct==0,'Yes must route to vote module')
run.complete=true;run.active=false
local beforeRequests=requests
ns.UI.Show();ns.UI.Tick();ForeverPlusFrame.abandonButton.scripts.OnClick()
assert(requests==beforeRequests,'completed run permitted abandon request')
run=nil;ns.UI.Tick()
assert(not ForeverPlusFrame.abandonButton.enabled,'idle abandon button enabled')
ns.UI.ToggleMinimapMenu(ForeverPlusMinimapButton)
assert(ForeverPlusMinimapMenu.abandonButton,'minimap lacks abandon action')
print('PASS explicit abandon routing, confirmation/No/Yes, hidden-HUD votes, terminal dismissal, inactive guards')
-- Public reports must be synchronous click actions, never OnUpdate/timer sends.
local pendingReport={id=1,text='ForeverPlus: Boss down - Forces 2%.',channel='PARTY',count=2,canSend=true,status='Ready'}
local hardware=false
local sends=0
ns.GetPendingBossReport=function() return pendingReport end
ns.SendPendingBossReport=function()
 assert(hardware,'send was deferred or run from a non-click UI path')
 sends=sends+1;pendingReport=nil
end
ns.UI.Show();ns.UI.Tick()
assert(ForeverPlusFrame.reportButton,'missing report button')
assert(ForeverPlusFrame.reportButton.enabled and ForeverPlusFrame.reportButton.text:find('2',1,true))
assert(sends==0,'tick automatically sent public chat')
hardware=true;ForeverPlusFrame.reportButton.scripts.OnClick();hardware=false
assert(sends==1,'HUD click did not synchronously send one report')
assert(not ForeverPlusFrame.reportButton.enabled,'consumed report left button enabled')
pendingReport={id=2,text='Another boss',channel='PARTY',count=1,canSend=false,status='Leave combat first'}
ns.UI.Tick();assert(not ForeverPlusFrame.reportButton.enabled)
ns.UI.RefreshBossReport();assert(sends==1,'refresh sent a report')
pendingReport.canSend=true
ns.UI.ToggleMinimapMenu(ForeverPlusMinimapButton)
assert(ForeverPlusMinimapMenu.reportButton,'missing minimap report action')
hardware=true;ForeverPlusMinimapMenu.reportButton.scripts.OnClick();hardware=false
assert(sends==2,'minimap click did not synchronously send one report')
ns.UI.Tick();assert(sends==2,'tick retried a report')
print('PASS report buttons send synchronously per click, never UI ticks; availability and pending counts refresh')
-- Optional UI failures cannot keep the forces counter/timer stale.
local refreshErrors={}
ns.SafeRefresh=function(stage,fn,...)
 local ok,err=pcall(fn,...);if not ok then refreshErrors[#refreshErrors+1]={stage=stage,error=err} end;return ok
end
local goodVote=ns.UI.RefreshVote
ns.UI.RefreshVote=function() error('injected vote panel failure') end
ns.GetBest=function() error('injected best lookup failure') end
run={key='rfc',name='Ragefire Chasm',active=true,kills=1,deaths=0,dungeon=ns.DUNGEONS.rfc,bossDown={}}
assert(ns.FORCE_PER_KILL==1.2,'uniform forces rate not 1.2%')
ns.UI.Show()
local ok=pcall(ns.UI.Tick)
assert(ok,'optional vote/history failure aborted HUD tick')
assert(ForeverPlusFrame.obj.text:find('Forces 1.2%',1,true),'fractional forces did not update after optional failure')
local display=assert(ns.UI.GetDisplayDiagnostics(),'display diagnostics unavailable')
assert(display.forces==1.2 and display.lastUpdated==GetTime(),'display diagnostics do not describe actual refresh')
assert(display.text==ForeverPlusFrame.obj.text,'debug display snapshot differs from rendered text')
assert(#refreshErrors>=2,'optional failures were silently swallowed instead of recorded')
run.kills=2;ns.UI.Tick()
assert(ForeverPlusFrame.obj.text:find('Forces 2.4%',1,true),'HUD did not continue refreshing after recurring failure')
assert(sends==2,'refresh recovery emitted public chat')
ns.UI.RefreshVote=goodVote;ns.GetBest=function() return nil end
run=nil;ns.UI.Tick();display=ns.UI.GetDisplayDiagnostics()
assert(display.forces==0 and display.text=='Bosses 0/0     Forces 0%','idle display snapshot stayed stale')
print('PASS optional UI failures do not freeze HUD; fractional forces and display diagnostics stay current')
-- Elapsed time and the next BETTER tier gap replace the countdown.
run={key='rfc',name='Ragefire Chasm',active=true,kills=1,deaths=0,dungeon=ns.DUNGEONS.rfc,bossDown={}}
elapsed=2316
ns.UI.Show();ns.UI.Tick()
assert(ForeverPlusFrame.clock.text=='Elapsed 38:36','HUD still shows countdown instead of elapsed time')
assert(ForeverPlusFrame.tierGap,'missing separate next-tier line')
assert(ForeverPlusFrame.tierGap.text=='2:36 faster for +3','incorrect next-better-tier gap')
assert(ForeverPlusFrame.height>=204,'next-tier line was squeezed into old HUD bands')
elapsed=2940;ns.UI.Tick()
assert(ForeverPlusFrame.clock.text=='Elapsed 49:00')
assert(ForeverPlusFrame.tierGap.text=='1:00 faster for +2')
elapsed=3660;ns.UI.Tick()
assert(ForeverPlusFrame.clock.text=='Elapsed 1:01:00','overtime elapsed time was prefixed or reset')
assert(ForeverPlusFrame.tierGap.text=='1:00 faster for +1')
run.complete=true;run.active=false;run.sec=2316;elapsed=8000;ns.UI.Tick()
assert(ForeverPlusFrame.clock.text=='Elapsed 38:36','completed elapsed did not freeze')
assert(ForeverPlusFrame.tierGap.text=='2:36 faster for +3','completed gap did not freeze')
run.complete=false;run.active=true;run.sec=nil;elapsed=100;ns.UI.Tick()
assert(ForeverPlusFrame.tierGap.text=='+3 is the highest tier','top tier falsely promises a higher chest')
records[1].sec=2316;records[1].chest=2
ns.UI.SelectDungeon('rfc');ns.UI.SelectRun('r1')
assert(ForeverPlusBoard.detailSummary.text:find('2:36 faster for +3',1,true),'completed journal lacks next-tier comparison')
run=nil;ns.UI.Tick()
assert(ForeverPlusFrame.clock.text=='Elapsed 0:00' and ForeverPlusFrame.tierGap.text=='Next tier: —','idle elapsed/gap remains stale')
print('PASS elapsed HUD, next-better chest gaps, top tier, overtime, frozen completion and journal comparison')
records[1].coverage='unavailable';records[1].players[1].damage=0;records[1].players[1].healing=0;records[1].players[1].deaths=3
ns.UI.SelectDungeon('rfc');ns.UI.SelectRun('r1')
assert(ForeverPlusBoard.playerLines[1].damage.text=='—' and ForeverPlusBoard.playerLines[1].healing.text=='—','unavailable combat totals appeared as fabricated zero')
assert(ForeverPlusBoard.playerLines[1].deaths.text=='3','independent saved deaths were hidden with unavailable combat stats')
assert(ForeverPlusBoard.totals.text:find('— dmg / — heal',1,true),'unavailable group totals displayed as zero')
print('PASS unavailable combat totals render as dashes while independent saved deaths remain visible')
records[1].coverage='partial';records[1].players[1].damageKnown=true;records[1].players[1].healingKnown=nil
ns.UI.RefreshBoard()
assert(ForeverPlusBoard.playerLines[1].damage.text=='0','readable measured-zero damage was hidden')
assert(ForeverPlusBoard.playerLines[1].healing.text=='—','unknown healing displayed as measured zero')
assert(ForeverPlusBoard.totals.text:find('— heal',1,true),'group healing availability was incorrectly inferred from damage')
records[1].players[1].healingKnown=true;ns.UI.RefreshBoard()
assert(ForeverPlusBoard.playerLines[1].healing.text=='0','measured-zero healing not distinguished from unavailable')
print('PASS per-metric availability distinguishes unknown from measured zero and preserves independent group totals')
for _,p in ipairs(records[1].players) do p.deaths=0;p.deathsKnown=nil end
ns.UI.RefreshBoard()
assert(ForeverPlusBoard.playerLines[1].deaths.text=='—','unknown legacy zero deaths displayed as measured zero')
assert(ForeverPlusBoard.totals.text:find('— deaths',1,true))
records[1].players[1].deathsKnown=true;ns.UI.RefreshBoard()
assert(ForeverPlusBoard.playerLines[1].deaths.text=='0','verified zero deaths were hidden')
print('PASS unknown zero deaths differ from a verified living/death baseline')
-- Reuse the real menu callbacks; OFF never removes the way back in.
local enabled=true
ns.IsEnabled=function() return enabled end
ns.ToggleEnabled=function() enabled=not enabled;return enabled end
ns.UI.ToggleMinimapMenu(ForeverPlusMinimapButton)
if not ForeverPlusMinimapMenu:IsShown() then ns.UI.ToggleMinimapMenu(ForeverPlusMinimapButton) end
assert(ForeverPlusMinimapMenu.trackingButton,'missing tracking toggle')
assert(ForeverPlusMinimapMenu.trackingButton.text=='Tracking: ON')
assert(ForeverPlusMinimapMenu.height>=232,'tracking row overlaps menu actions')
ForeverPlusMinimapMenu.trackingButton.scripts.OnClick()
assert(not enabled and ForeverPlusMinimapMenu.trackingButton.text=='Tracking: OFF')
ForeverPlusMinimapButton.scripts.OnClick(nil,'LeftButton')
assert(not ForeverPlusFrame:IsShown(),'OFF left click exposed stale timer')
assert(ForeverPlusMinimapButton:IsShown(),'OFF hid minimap reenable action')
ns.UI.Show();ns.UI.Tick();assert(not ForeverPlusFrame:IsShown(),'OFF Show/Tick resurrected HUD')
ForeverPlusBoard:Hide();ns.UI.ToggleBoard();assert(ForeverPlusBoard:IsShown(),'OFF journal unavailable')
ns.UI.Tick();assert(ForeverPlusBoard.syncStatus.text==syncStatus,'OFF stopped history status refresh')
local tips={};methods.AddLine=function(_,text) tips[#tips+1]=text end
ForeverPlusMinimapButton.scripts.OnEnter(ForeverPlusMinimapButton)
assert(table.concat(tips,' '):find('no automatic runs',1,true),'OFF tooltip does not explain tracking')
ForeverPlusMinimapButton.scripts.OnClick(nil,'RightButton')
assert(ForeverPlusMinimapMenu.trackingButton.text=='Tracking: OFF')
ForeverPlusMinimapMenu.trackingButton.scripts.OnClick()
assert(enabled and ForeverPlusMinimapMenu.trackingButton.text=='Tracking: ON')
print('PASS saved tracking menu refresh, OFF HUD guards, journal/minimap availability and tooltip')
