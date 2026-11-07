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
    frame:SetSize(300, 184)
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
    barBack:SetPoint("BOTTOMLEFT", 10, 44)
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

    local abandon = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    abandon:SetSize(106, 24)
    abandon:SetPoint("BOTTOMLEFT", 10, 10)
    abandon:SetText("Abandon")
    abandon:SetScript("OnClick", function() UI.RequestAbandon() end)
    abandon:SetEnabled(false)
    frame.abandonButton = abandon
    local persistence = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    persistence:SetPoint("LEFT", abandon, "RIGHT", 10, 0)
    persistence:SetWidth(164)
    persistence:SetText("Continues through death\nand zone changes")

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("ForeverPlus", 1, 0.82, 0.2)
        GameTooltip:AddLine("Gag Mythic+ timer. All standard bosses + 50 mobs (2% each).", 1, 1, 1, true)
        GameTooltip:AddLine("Drag to move. Right-click for dungeon history.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("/fplus complete to force-end if a kill isn't seen.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UI.BuildBoard()
    UI.BuildMinimap()
end

local function SafeText(value)
    if (ns.IsSecret and ns.IsSecret(value)) or type(value) ~= "string" then return "" end
    return value:gsub("|", ""):gsub("[%z\1-\31\127]", " ")
end
local function ShortNumber(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return "—" end
    if value >= 1000000000 then return string.format("%.2fb", value / 1000000000) end
    if value >= 1000000 then return string.format("%.2fm", value / 1000000) end
    if value >= 1000 then return string.format("%.1fk", value / 1000) end
    return string.format("%.0f", value)
end
local function Stamp(value)
    if date and type(value) == "number" then
        local ok, result = pcall(date, "%m/%d/%y %H:%M", value)
        if ok then return SafeText(result) end
    end
    return type(value) == "number" and tostring(value) or "Unknown date"
end
local function Text(parent, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    return label
end
local function PanelScroll(parent, name, x, y, width, height)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", x, y)
    scroll:SetSize(width, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, height)
    scroll:SetScrollChild(child)
    return child, scroll
end
local function Selectable(parent, width, height, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * height)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(0.85, 0.65, 0.18, 0.16)
    row.selected:Hide()
    return row
end
local function SyncRuns()
    if ns.Sync and ns.Sync.Request then ns.Sync.Request("manual") end
    UI.RefreshBoard()
end

-- This panel is independent of HUD visibility, so incoming votes remain visible.
local dismissedVote
function UI.RequestAbandon()
    local r = ns.GetRun()
    if not r or not r.active or r.complete or r.practice then return end
    dismissedVote = nil
    if ns.Vote and ns.Vote.Request then ns.Vote.Request()
    elseif ns.Print then ns.Print("Abandon voting is unavailable. Reload the updated addon.") end
    UI.RefreshVote()
end

function UI.RefreshVote()
    local state = ns.Vote and ns.Vote.Get and ns.Vote.Get()
    local panel = UI.votePanel
    if not state then if panel then panel:Hide() end; return end
    local terminal = state.phase == "passed" or state.phase == "failed" or state.phase == "cancelled"
    local key = tostring(state.phase) .. ":" .. tostring(state.id or state.deadline or state.text)
    if terminal and dismissedVote == key then if panel then panel:Hide() end; return end
    if not terminal then dismissedVote = nil end
    if not panel then
        panel = CreateFrame("Frame", "ForeverPlusAbandonVote", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        panel:SetSize(340, 194)
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, -130)
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        MakeBackdrop(panel, 0.04, 0.03, 0.07, 0.98)
        panel.title = Text(panel, 12, -12, 316, "GameFontNormal")
        panel.title:SetText("Abandon run?")
        panel.message = Text(panel, 12, -38, 316)
        panel.message:SetHeight(100)
        panel.message:SetJustifyV("TOP")
        local function button(text, x, fn)
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(146, 26); b:SetPoint("BOTTOMLEFT", x, 12)
            b:SetText(text); b:SetScript("OnClick", fn)
            return b
        end
        panel.yesButton = button("Yes, abandon", 12, function()
            if ns.Vote and ns.Vote.Cast then ns.Vote.Cast(true) end
            UI.RefreshVote()
        end)
        panel.noButton = button("No, continue", 182, function()
            if ns.Vote and ns.Vote.Cast then ns.Vote.Cast(false) end
            UI.RefreshVote()
        end)
        panel.closeButton = button("Close", 98, function()
            dismissedVote = panel.stateKey; panel:Hide()
        end)
        UI.votePanel = panel
    end
    panel.stateKey = key
    local text = SafeText(state.text)
    if type(state.deadline) == "number" and not terminal then
        text = text .. "\n" .. math.max(0, math.ceil(state.deadline - GetTime())) .. "s remaining"
    end
    panel.message:SetText(text)
    if state.canVote then
        panel.yesButton:Show(); panel.noButton:Show()
        panel.yesButton:SetEnabled(true); panel.noButton:SetEnabled(true)
    else panel.yesButton:Hide(); panel.noButton:Hide() end
    if terminal then panel.closeButton:Show() else panel.closeButton:Hide() end
    panel:Show()
end

function UI.BuildBoard()
    board = CreateFrame("Frame", "ForeverPlusBoard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    board:SetSize(940, 560)
    board:SetPoint("CENTER", UIParent, "CENTER", 0, -20)
    board:SetMovable(true)
    board:EnableMouse(true)
    board:SetClampedToScreen(true)
    board:RegisterForDrag("LeftButton")
    board:SetScript("OnDragStart", function(self) self:StartMoving() end)
    board:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    board:SetFrameStrata("DIALOG")
    local width = UIParent.GetWidth and UIParent:GetWidth()
    local height = UIParent.GetHeight and UIParent:GetHeight()
    if type(width) == "number" and type(height) == "number" then
        board:SetScale(math.min(1, math.max(0.4, (width - 30) / 940), math.max(0.4, (height - 30) / 560)))
    end
    board:Hide()
    MakeBackdrop(board, 0.03, 0.03, 0.06, 0.98)
    Text(board, 16, -14, 850, "GameFontNormalLarge"):SetText("ForeverPlus  ·  Dungeon Journal")
    Text(board, 16, -38, 880):SetText("Choose a dungeon, then a run. Recorded group stats · participant-only sync outside instances.")
    local close = CreateFrame("Button", nil, board, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    Text(board, 16, -68, 76, "GameFontNormal"):SetText("DUNGEONS")
    local sort = CreateFrame("Button", nil, board, "UIPanelButtonTemplate")
    sort:SetSize(132, 22)
    sort:SetPoint("TOPLEFT", 95, -62)
    sort:SetScript("OnClick", function() UI.ToggleDungeonSort() end)
    sort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Dungeon order", 1, 0.82, 0.2)
        GameTooltip:AddLine("Click to toggle Alphabetical / Level Range.", 1, 1, 1)
        GameTooltip:AddLine("Level Range: lowest level, upper level, then name.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
    board.sortButton = sort
    Text(board, 240, -68, 210, "GameFontNormal"):SetText("RUN HISTORY")
    Text(board, 480, -68, 420, "GameFontNormal"):SetText("RUN DETAILS")
    board.dungeonChild, board.dungeonScroll = PanelScroll(board, "ForeverPlusDungeonScroll", 16, -94, 192, 410)
    board.runChild, board.runScroll = PanelScroll(board, "ForeverPlusRunScroll", 240, -94, 206, 410)
    board.dungeonLines, board.runLines, board.playerLines = {}, {}, {}
    board.detailTitle = Text(board, 480, -96, 430, "GameFontNormalLarge")
    board.detailSummary = Text(board, 480, -122, 430)
    board.detailSummary:SetHeight(46)
    board.coverage = Text(board, 480, -174, 430)
    board.coverage:SetHeight(34)
    board.source = Text(board, 480, -212, 430, "GameFontDisableSmall")
    board.source:SetHeight(32)
    local headers = {{"Player / realm", 0, 158}, {"Damage", 163, 83}, {"Healing", 252, 83}, {"Deaths", 342, 70}}
    for _, col in ipairs(headers) do Text(board, 480 + col[2], -252, col[3], "GameFontNormal"):SetText(col[1]) end
    for i = 1, 10 do
        local row = CreateFrame("Frame", nil, board)
        row:SetPoint("TOPLEFT", 480, -278 - (i - 1) * 21)
        row:SetSize(430, 21)
        row.name = Text(row, 0, 0, 158)
        row.damage = Text(row, 163, 0, 83)
        row.healing = Text(row, 252, 0, 83)
        row.deaths = Text(row, 342, 0, 70)
        row:Hide()
        board.playerLines[i] = row
    end
    board.totals = Text(board, 480, -494, 430, "GameFontNormal")
    local sync = CreateFrame("Button", nil, board, "UIPanelButtonTemplate")
    sync:SetSize(130, 24)
    sync:SetPoint("BOTTOMLEFT", 16, 14)
    sync:SetText("Sync runs")
    sync:SetScript("OnClick", SyncRuns)
    board.syncButton = sync
    board.syncStatus = Text(board, 158, -526, 750, "GameFontDisableSmall")
end

local function SortMode()
    local mode = DB().dungeonSort
    if (ns.IsSecret and ns.IsSecret(mode)) or mode ~= "level" then mode = "alpha" end
    DB().dungeonSort = mode
    return mode
end

function UI.ToggleDungeonSort()
    DB().dungeonSort = SortMode() == "alpha" and "level" or "alpha"
    if board then board.dungeonScroll:SetVerticalScroll(0) end
    UI.RefreshBoard()
end

local function AllDungeons()
    local byKey, counts = {}, {}
    for key, d in pairs(ns.DUNGEONS) do byKey[key] = d.name end
    local history = ns.History and ns.History.List and ns.History.List() or {}
    for _, r in ipairs(history) do
        byKey[r.dungeonKey] = byKey[r.dungeonKey] or r.dungeonName
        counts[r.dungeonKey] = (counts[r.dungeonKey] or 0) + 1
    end
    for key, b in pairs(DB().best) do byKey[key] = byKey[key] or b.name or key end
    local list = {}
    for key, name in pairs(byKey) do
        local dungeon = ns.DUNGEONS[key]
        list[#list + 1] = {key=key, name=name, count=counts[key] or 0,
            levelMin=dungeon and dungeon.levelMin, levelMax=dungeon and dungeon.levelMax}
    end
    local mode = SortMode()
    table.sort(list, function(a, b)
        if mode == "level" then
            local lowA, lowB = a.levelMin or math.huge, b.levelMin or math.huge
            if lowA ~= lowB then return lowA < lowB end
            local highA, highB = a.levelMax or math.huge, b.levelMax or math.huge
            if highA ~= highB then return highA < highB end
        end
        local nameA, nameB = SafeText(a.name):lower(), SafeText(b.name):lower()
        if nameA ~= nameB then return nameA < nameB end
        return a.key < b.key
    end)
    table.insert(list, 1, {key="*", name="All dungeons", count=#history})
    return list
end

function UI.SelectDungeon(key)
    if not board then UI.Init() end
    board.selectedDungeon = key
    board.selectedRun = nil
    board.runScroll:SetVerticalScroll(0)
    UI.RefreshBoard()
end
function UI.SelectRun(id)
    if not board then return end
    for _, r in ipairs(board.visibleRuns or {}) do
        if r.id == id then board.selectedRun = id; UI.RefreshBoard(); return end
    end
end

function UI.RefreshBoard()
    if not board then return end
    local dungeons = AllDungeons()
    board.sortButton:SetText(SortMode() == "level" and "Level Range" or "Alphabetical")
    board.selectedDungeon = board.selectedDungeon or "*"
    local dungeonExists = false
    for i, d in ipairs(dungeons) do
        if d.key == board.selectedDungeon then dungeonExists = true end
        local row = board.dungeonLines[i]
        if not row then
            row = Selectable(board.dungeonChild, 192, 36, i)
            row.title = Text(row, 3, -2, 185)
            row.title:SetHeight(18)
            row.count = Text(row, 3, -20, 185, "GameFontDisableSmall")
            row:SetScript("OnClick", function(self) UI.SelectDungeon(self.key) end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(SafeText(self.fullName), 1, 0.82, 0.2)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            board.dungeonLines[i] = row
        end
        row.key, row.fullName = d.key, d.name
        row.title:SetText(SafeText(d.name))
        local range = d.levelMin and string.format("Lv %d–%d · ", d.levelMin, d.levelMax)
            or (d.key ~= "*" and "Lv ? · " or "")
        row.count:SetText(range .. string.format("%d run%s", d.count, d.count == 1 and "" or "s"))
        if d.key == board.selectedDungeon then row.selected:Show() else row.selected:Hide() end
        row:Show()
    end
    for i = #dungeons + 1, #board.dungeonLines do board.dungeonLines[i]:Hide() end
    board.dungeonChild:SetHeight(math.max(410, #dungeons * 36))
    if not dungeonExists then board.selectedDungeon = "*"; board.selectedRun = nil end
    local key = board.selectedDungeon ~= "*" and board.selectedDungeon or nil
    local runs = ns.History and ns.History.List and ns.History.List(key) or {}
    board.visibleRuns = runs
    local selected
    for i, r in ipairs(runs) do
        local row = board.runLines[i]
        if not row then
            row = Selectable(board.runChild, 206, 48, i)
            row.title = Text(row, 3, -3, 200)
            row.title:SetHeight(20)
            row.sub = Text(row, 3, -26, 200, "GameFontDisableSmall")
            row:SetScript("OnClick", function(self) UI.SelectRun(self.id) end)
            board.runLines[i] = row
        end
        row.id = r.id
        local state = r.status == "completed" and ((r.chest or 0) > 0 and ("+" .. r.chest) or "Depleted") or SafeText(r.status)
        row.title:SetText(ns.FormatTime(r.sec) .. "   " .. state .. (r.manual and " · manual" or ""))
        row.sub:SetText(Stamp(r.endUnix))
        row:Show()
        if r.id == board.selectedRun then selected = r end
    end
    for i = #runs + 1, #board.runLines do board.runLines[i]:Hide() end
    board.runChild:SetHeight(math.max(410, #runs * 48))
    if not selected then selected = runs[1]; board.selectedRun = selected and selected.id or nil end
    for _, row in ipairs(board.runLines) do
        if row.id == board.selectedRun then row.selected:Show() else row.selected:Hide() end
    end
    if #runs == 0 then
        if not board.empty then
            board.empty = Text(board.runChild, 4, -8, 194, "GameFontDisableSmall")
            board.empty:SetHeight(160)
        end
        board.empty:SetText("No recorded runs yet.\n\nNew runs record the group and observed combat stats.\n\nOlder best times do not contain recoverable run details.")
        board.empty:Show()
    elseif board.empty then board.empty:Hide() end
    for _, row in ipairs(board.playerLines) do row:Hide() end
    if selected then
        board.detailTitle:SetText(SafeText(selected.dungeonName))
        local state = selected.status == "completed" and "Completed" or SafeText(selected.status)
        board.detailSummary:SetText(Stamp(selected.endUnix) .. "\n" .. ns.FormatTime(selected.sec) .. " · " .. state .. (selected.manual and " · manual finish" or ""))
        local coverage = {observed="Observed combat stats (client-visible events)", partial="Partial stats — some events were unavailable", unavailable="Damage / healing unavailable — no usable combat events"}
        board.coverage:SetText(coverage[selected.coverage] or coverage.unavailable)
        board.source:SetText("Recorded by " .. SafeText(selected.recordedBy) .. " · shared stats are unverified")
        local damage, healing, deaths = 0, 0, 0
        for i, p in ipairs(selected.players or {}) do
            local row = board.playerLines[i]
            if not row then break end
            row.name:SetText(SafeText(p.name))
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            row.damage:SetText(selected.coverage == "unavailable" and "—" or ShortNumber(p.damage))
            row.healing:SetText(selected.coverage == "unavailable" and "—" or ShortNumber(p.healing))
            row.deaths:SetText(tostring(p.deaths or 0))
            row:Show()
            damage, healing, deaths = damage + (p.damage or 0), healing + (p.healing or 0), deaths + (p.deaths or 0)
        end
        board.totals:SetText("Group: " .. (selected.coverage == "unavailable" and "— dmg / — heal" or (ShortNumber(damage) .. " dmg / " .. ShortNumber(healing) .. " heal")) .. " / " .. deaths .. " deaths")
    else
        board.detailTitle:SetText("Select a run")
        local best = key and ns.GetBest(key)
        board.detailSummary:SetText(best and ("Existing personal best: " .. ns.FormatTime(best.sec) .. "\nNo historic roster or combat stats available.") or "Select a dungeon to browse its recorded runs.")
        board.coverage:SetText("")
        board.source:SetText("")
        board.totals:SetText("")
    end
    board.syncStatus:SetText(SafeText(ns.Sync and ns.Sync.Status and ns.Sync.Status() or "Sync available outside instances · /fplus sync"))
end

function UI.ToggleBoard()
    if not board then UI.Init() end
    if board:IsShown() then board:Hide()
    else UI.RefreshBoard(); board:Show() end
end

function UI.ToggleMinimapMenu(anchor)
    local menu = UI.minimapMenu
    if not menu then
        menu = CreateFrame("Frame", "ForeverPlusMinimapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        menu:SetSize(190, 172)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetClampedToScreen(true)
        MakeBackdrop(menu, 0.03, 0.03, 0.06, 0.99)
        local function item(text, index, fn)
            local button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            button:SetSize(170, 24)
            button:SetPoint("TOPLEFT", 10, -10 - (index - 1) * 30)
            button:SetText(text)
            button:SetScript("OnClick", function() menu:Hide(); fn() end)
            return button
        end
        item("Dungeon history", 1, function() if not board:IsShown() then UI.ToggleBoard() end end)
        menu.syncButton = item("Sync runs", 2, SyncRuns)
        menu.lockButton = item("Lock / unlock timer", 3, function() DB().locked = not DB().locked end)
        menu.abandonButton = item("Abandon run...", 4, function() UI.RequestAbandon() end)
        item("Close", 5, function() end)
        menu:Hide()
        UI.minimapMenu = menu
    end
    if menu:IsShown() then menu:Hide(); return end
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor or minimap or UIParent, "BOTTOMRIGHT", 0, -2)
    menu:Show()
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
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            UI.ToggleMinimapMenu(self)
        else
            if frame:IsShown() then frame:Hide() else UI.Show() end
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ForeverPlus", 1, 0.82, 0.2)
        GameTooltip:AddLine("Left-click: timer  Right-click: history / sync menu", 1, 1, 1)
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
    UI.RefreshVote()
    if frame then
        local current = ns.GetRun()
        frame.abandonButton:SetEnabled(current ~= nil and current.active == true and not current.complete and not current.practice)
    end
    if board and board:IsShown() and ns.Sync and ns.Sync.Status then
        board.syncStatus:SetText(SafeText(ns.Sync.Status()))
    end
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
        frame.chest:SetTextColor(1, 1, 1)
        frame.title:SetText("FOREVER +1")
        frame.best:SetText("Best: —")
        frame.deaths:SetText("Deaths: 0")
        frame.obj:SetText("Bosses 0/0     Forces 0%")
        frame.fill:SetWidth(1)
        frame.fill:SetVertexColor(0.7, 0.7, 0.7)
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
    local deaths = ns.History and run.history and ns.History.TotalDeaths(run) or run.deaths or 0
    frame.deaths:SetText("Deaths: " .. tostring(deaths))
    if frame.obj then
        local down, total = ns.CountBossesDown(run)
        local fp = ns.ForcesPercent(run)
        local manual = total == 0 or (run.dungeon and (run.dungeon.manual or run.dungeon.unknown))
        local bcol = (not manual and down >= total) and "|cff00ff96" or "|cffffffff"
        local fcol = (fp >= 100) and "|cff00ff96" or "|cffffffff"
        if manual then
            frame.obj:SetText(string.format("|cffffd200Bosses: manual|r     %sForces %d%%|r", fcol, fp))
        else
            frame.obj:SetText(string.format("%sBosses %d/%d|r     %sForces %d%%|r", bcol, down, total, fcol, fp))
        end
    end

    local frac = math.min(1, sec / ns.LIMIT)
    local w = 280 * frac
    if w < 1 then w = 1 end
    frame.fill:SetWidth(w)
    frame.fill:SetVertexColor(cr, cg, cb)
end
