local ADDON, ns = ...

local UI = {}
ns.UI = UI

local media = "Interface\\AddOns\\ForeverPlus\\Media\\"
local BAR = media .. "bar"
local ICON = media .. "icon"
local CHEST = media .. "chest"

local frame, board, minimap
local hideAt = 0

local function DB()
    return ns.DB()
end

local function ColorFor(sec)
    if sec <= ns.PLUS3 then
        return 0.15, 0.95, 0.62
    elseif sec <= ns.PLUS2 then
        return 1.0, 0.82, 0.12
    elseif sec <= ns.PLUS1 then
        return 1.0, 0.49, 0.04
    end
    return 1.0, 0.18, 0.18
end

local function MakeBackdrop(f, r, g, b, a)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(r or 0.05, g or 0.04, b or 0.08, a or 0.92)
        f:SetBackdropBorderColor(0.85, 0.68, 0.28, 0.95)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(r or 0.05, g or 0.04, b or 0.08, a or 0.92)
        f.bg = bg
    end
end

function UI.Init()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverPlusFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(300, 150)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not DB().locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        DB().pos = { p = p, rp = rp, x = x, y = y }
    end)
    frame:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then
            UI.ToggleBoard()
        end
    end)
    frame:Hide()
    MakeBackdrop(frame, 0.04, 0.03, 0.07, 0.94)

    if DB().pos and DB().pos.p then
        frame:ClearAllPoints()
        frame:SetPoint(DB().pos.p, UIParent, DB().pos.rp or DB().pos.p, DB().pos.x or 0, DB().pos.y or 0)
    end

    local keystone = frame:CreateTexture(nil, "ARTWORK")
    keystone:SetSize(28, 28)
    keystone:SetPoint("TOPLEFT", 8, -8)
    keystone:SetTexture(ICON)
    frame.icon = keystone

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", keystone, "TOPRIGHT", 8, 2)
    title:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    title:SetJustifyH("LEFT")
    title:SetText("FOREVER +1")
    frame.title = title

    local dungeon = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeon:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    dungeon:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    dungeon:SetJustifyH("LEFT")
    dungeon:SetText("Waiting for a dungeon")
    frame.dungeon = dungeon

    local clock = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    clock:SetPoint("TOPLEFT", 10, -44)
    do
        local font = clock:GetFont()
        if font then clock:SetFont(font, 22, "OUTLINE") end
    end
    clock:SetText("60:00")
    frame.clock = clock

    local chest = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chest:SetPoint("LEFT", clock, "RIGHT", 14, 1)
    chest:SetText("+3")
    frame.chest = chest

    local best = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    best:SetPoint("TOPLEFT", clock, "BOTTOMLEFT", 0, -8)
    best:SetWidth(170)
    best:SetJustifyH("LEFT")
    best:SetText("Best: —")
    frame.best = best

    local deaths = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    deaths:SetPoint("TOP", best, "TOP", 0, 0)
    deaths:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    deaths:SetJustifyH("RIGHT")
    deaths:SetText("Deaths: 0")
    frame.deaths = deaths

    local obj = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    obj:SetPoint("TOPLEFT", best, "BOTTOMLEFT", 0, -6)
    obj:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    obj:SetJustifyH("LEFT")
    obj:SetText("Bosses 0/0     Forces 0%")
    frame.obj = obj

    -- Three-segment deplete bar (36 / 48 / 60)
    local barW, barH = 280, 8
    local barBack = frame:CreateTexture(nil, "ARTWORK")
    barBack:SetColorTexture(0.12, 0.10, 0.14, 1)
    barBack:SetPoint("BOTTOMLEFT", 10, 10)
    barBack:SetSize(barW, barH)
    frame.barBack = barBack

    local fill = frame:CreateTexture(nil, "OVERLAY")
    fill:SetTexture(BAR)
    fill:SetPoint("LEFT", barBack, "LEFT", 0, 0)
    fill:SetSize(1, barH)
    frame.fill = fill

    -- Tick marks at +3 and +2
    local function tick(frac)
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 0.55)
        t:SetSize(1, barH + 4)
        t:SetPoint("LEFT", barBack, "LEFT", barW * frac, 0)
        return t
    end
    tick(ns.PLUS3 / ns.LIMIT)
    tick(ns.PLUS2 / ns.LIMIT)

    local ticks = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ticks:SetPoint("BOTTOMLEFT", barBack, "TOPLEFT", 0, 5)
    ticks:SetPoint("BOTTOMRIGHT", barBack, "TOPRIGHT", 0, 5)
    ticks:SetJustifyH("LEFT")
    ticks:SetText("|cff00ff96+3 36:00|r     |cffffd200+2 48:00|r     |cffff7d0a+1 60:00|r")
    do
        local font = ticks:GetFont()
        if font then ticks:SetFont(font, 10) end
    end

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("ForeverPlus", 1, 0.82, 0.2)
        GameTooltip:AddLine("Gag Mythic+ timer. All standard bosses + 50 mobs (2% each).", 1, 1, 1, true)
        GameTooltip:AddLine("Drag to move. Right-click for best times.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("/fplus complete to force-end if a kill isn't seen.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UI.BuildBoard()
    UI.BuildMinimap()
end

function UI.BuildBoard()
    board = CreateFrame("Frame", "ForeverPlusBoard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    board:SetSize(420, 460)
    board:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    board:SetMovable(true)
    board:EnableMouse(true)
    board:RegisterForDrag("LeftButton")
    board:SetScript("OnDragStart", function(self) self:StartMoving() end)
    board:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    board:SetFrameStrata("DIALOG")
    board:Hide()
    MakeBackdrop(board, 0.03, 0.03, 0.06, 0.96)

    local t = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOP", 0, -12)
    t:SetText("ForeverPlus  ·  Best Clears")

    local sub = board:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOP", t, "BOTTOM", 0, -4)
    sub:SetText("Your times vs anyone else with the addon (party/guild)")
    board.sub = sub

    local close = CreateFrame("Button", nil, board, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local scroll = CreateFrame("ScrollFrame", "ForeverPlusBoardScroll", board, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -48)
    scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(360, 800)
    scroll:SetScrollChild(child)
    board.child = child
    board.lines = {}

    local share = CreateFrame("Button", nil, board, "UIPanelButtonTemplate")
    share:SetSize(120, 22)
    share:SetPoint("BOTTOMLEFT", 16, 12)
    share:SetText("Share times")
    share:SetScript("OnClick", function()
        if ns.Comm then ns.Comm.ShareNow("button") end
    end)

    local hint = board:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", share, "RIGHT", 10, 0)
    hint:SetText("Shares when you are not inside a dungeon")
end

local function EnsureLine(i)
    local child = board.child
    local line = board.lines[i]
    if line then return line end
    line = CreateFrame("Frame", nil, child)
    line:SetSize(360, 18)
    line:SetPoint("TOPLEFT", 0, -((i - 1) * 18))
    line.left = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.left:SetPoint("LEFT", 0, 0)
    line.left:SetWidth(190)
    line.left:SetJustifyH("LEFT")
    line.mid = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.mid:SetPoint("LEFT", 194, 0)
    line.mid:SetWidth(70)
    line.right = line:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line.right:SetPoint("LEFT", 266, 0)
    line.right:SetWidth(90)
    board.lines[i] = line
    return line
end

local function OrderedKeys()
    local list = {}
    for key, d in pairs(ns.DUNGEONS) do
        list[#list + 1] = { key = key, name = d.name }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function UI.RefreshBoard()
    if not board then return end
    local i = 0
    local function add(name, you, peer)
        i = i + 1
        local line = EnsureLine(i)
        line:Show()
        line.left:SetText(name)
        line.mid:SetText(you or "—")
        line.right:SetText(peer or "")
    end

    -- Peer summary: best time among known peers for that key
    local function peerBest(key)
        local bestSec, bestWho
        local peers = DB().peers
        for who, times in pairs(peers) do
            local e = times[key]
            if e and e.sec and (not bestSec or e.sec < bestSec) then
                bestSec = e.sec
                bestWho = who
            end
        end
        if not bestSec then return nil end
        local short = bestWho:match("([^%-]+)") or bestWho
        return string.format("%s %s", ns.FormatTime(bestSec), short)
    end

    local keys = OrderedKeys()
    for n = 1, #keys do
        local key = keys[n].key
        local d = ns.DUNGEONS[key]
        local b = ns.GetBest(key)
        local you = b and (ns.FormatTime(b.sec) .. " +" .. tostring(b.chest or 0)) or nil
        add(d.name, you, peerBest(key))
    end
    -- also unknown keys stored in best
    for key, b in pairs(DB().best) do
        if not ns.DUNGEONS[key] then
            add(b.name or key, ns.FormatTime(b.sec) .. " +" .. tostring(b.chest or 0), peerBest(key))
        end
    end
    for j = i + 1, #(board.lines) do
        board.lines[j]:Hide()
    end
    board.child:SetHeight(math.max(400, i * 18 + 8))
end

function UI.ToggleBoard()
    if not board then UI.Init() end
    if board:IsShown() then
        board:Hide()
    else
        UI.RefreshBoard()
        board:Show()
    end
end

function UI.BuildMinimap()
    local btn = CreateFrame("Button", "ForeverPlusMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ICON)
    tex:SetAllPoints()
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(me)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = me:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            DB().minimap.angle = angle
            UI.PlaceMinimap()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            UI.ToggleBoard()
        else
            if frame:IsShown() then frame:Hide() else UI.Show() end
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ForeverPlus", 1, 0.82, 0.2)
        GameTooltip:AddLine("Left-click: timer  Right-click: times", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    minimap = btn
    UI.PlaceMinimap()
    if not DB().showMinimap then btn:Hide() end
end

function UI.PlaceMinimap()
    if not minimap then return end
    local angle = math.rad(DB().minimap.angle or 198)
    local r = (Minimap:GetWidth() / 2) + 5
    minimap:ClearAllPoints()
    minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function UI.Show()
    if not frame then UI.Init() end
    hideAt = 0
    frame:Show()
end

function UI.HideSoon()
    hideAt = GetTime() + 45
end

function UI.HideNow()
    hideAt = 0
    if frame then frame:Hide() end
end

function UI.OnComplete(run)
    UI.Show()
    hideAt = GetTime() + 90
    UI.RefreshBoard()
end

function UI.Tick()
    if not frame then return end
    if hideAt > 0 and GetTime() > hideAt and (not ns.GetRun() or not ns.GetRun().active) then
        frame:Hide()
        hideAt = 0
    end
    if not frame:IsShown() then return end

    local run = ns.GetRun()
    if not run then
        frame.dungeon:SetText("No active key")
        frame.clock:SetText("60:00")
        frame.clock:SetTextColor(0.7, 0.7, 0.7)
        frame.chest:SetText("")
        return
    end

    local sec = run.sec or ns.Elapsed(run)
    local clock, over = ns.FormatClock(sec, ns.LIMIT)
    local cr, cg, cb = ColorFor(sec)
    frame.clock:SetText(clock)
    frame.clock:SetTextColor(cr, cg, cb)
    frame.dungeon:SetText(run.name or "")
    frame.title:SetText("FOREVER +1")

    local chest = ns.ChestForTime(sec)
    if run.complete then
        if chest > 0 then
            frame.chest:SetText(string.format("|cff00ff96Timed  +%d|r", chest))
        else
            frame.chest:SetText("|cffff2020Depleted|r")
        end
    else
        if chest > 0 then
            frame.chest:SetText(string.format("+%d", chest))
        else
            frame.chest:SetText("|cffff2020DEPLETED|r")
        end
        frame.chest:SetTextColor(cr, cg, cb)
    end

    local b = ns.GetBest(run.key)
    if b then
        local delta = sec - b.sec
        local sign = delta >= 0 and "+" or "-"
        frame.best:SetText(string.format("Best %s  (%s%s)", ns.FormatTime(b.sec), sign, ns.FormatTime(math.abs(delta))))
    else
        frame.best:SetText("Best: —")
    end
    frame.deaths:SetText("Deaths: " .. tostring(run.deaths or 0))
    if frame.obj then
        local down, total = ns.CountBossesDown(run)
        local fp = ns.ForcesPercent(run)
        local bcol = (total == 0 or down >= total) and "|cff00ff96" or "|cffffffff"
        local fcol = (fp >= 100) and "|cff00ff96" or "|cffffffff"
        frame.obj:SetText(string.format("%sBosses %d/%d|r     %sForces %d%%|r", bcol, down, total, fcol, fp))
    end

    local frac = math.min(1, sec / ns.LIMIT)
    local w = 280 * frac
    if w < 1 then w = 1 end
    frame.fill:SetWidth(w)
    frame.fill:SetVertexColor(cr, cg, cb)
end
