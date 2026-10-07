-- Native, paged offline dashboard. No scanners are called by construction, refresh or navigation.
local keys = {"character", "bags", "bank", "items", "combat", "quest", "reputation",
    "gold", "currency", "honor", "title"}
local names = {"Character", "Bags", "Character bank", "Item details", "Combat log",
    "Quests", "Reputation", "Gold", "Currencies", "Honor", "Titles"}
local scopes = {
    "Own identity, gear, level and location. Does not track every past state.",
    "Own carried-bag item totals, not account or guild storage.",
    "Own character-bank tabs only while the character-bank view is open; no account bank.",
    "Cached item names/details from own bags, gear and open character bank. Incomplete cache is refused.",
    "WoW writes its combat-log file. This addon does not keep combat events or a record count.",
    "Active quest-log view only; not completed quest history.",
    "Visible faction list only; collapsed or unavailable rows are not inferred.",
    "Current own money balance, not transaction history.",
    "Visible currency list only; hidden currencies and acquisition history are not inferred.",
    "Supported visible PvP counters only; not a full match history.",
    "Selected/known title observation, not a title acquisition history.",
}
local triggers = {
    "World entry; equipment, level, zone and post-combat events; every 5 minutes. Manual: Character now. Out of combat.",
    "World entry, delayed bag update, own bag opening, post-combat; every 5 minutes. Manual: Bags now. Out of combat.",
    "Bank frame open, bank slots/tabs changed, character bank page selection. Manual: Bank now. Only while own bank is open, out of combat.",
    "World entry, equipment, bag updates/opening, post-combat; bank events/page selection for bank items; every 5 minutes for bags/gear. Manual: Items now (bags/gear), Bank now (bank details). Out of combat.",
    "Auto-start at world entry if opted in. Manual: Stop logging now disables auto-start and requests WoW to stop; no file capture here.",
    "World entry, quest-log update, post-combat; every 5 minutes and bounded retry. Manual: Quests now. Out of combat.",
    "World entry, faction update, post-combat; every 5 minutes and bounded retry. Manual: Reputation now. Out of combat.",
    "World entry, post-combat, PLAYER_MONEY notification; every 5 minutes and bounded retry. Manual: Gold now. Out of combat.",
    "World entry, post-combat, CURRENCY_DISPLAY_UPDATE notification; every 5 minutes and bounded retry. Manual: Currencies now. Out of combat.",
    "World entry, post-combat, PLAYER_PVP_RANK_CHANGED notification; every 5 minutes and bounded retry. Manual: Honor now. Out of combat.",
    "World entry and post-combat; every 5 minutes and bounded retry. Manual: Titles now. No unverified title event. Out of combat.",
}
local function safeSummary(key)
    local fn = _G.MclarionWow_DashboardSummary
    if type(fn) ~= "function" then return "Stored data: summary unavailable." end
    if type(issecretvalue) ~= "function" then return "Stored data: summary unavailable." end
    local protected, hidden = pcall(issecretvalue, fn)
    if not protected or hidden then return "Stored data: summary unavailable." end
    local ok, value = pcall(fn, key)
    if not ok then return "Stored data: summary unavailable." end
    protected, hidden = pcall(issecretvalue, value)
    if not protected or hidden then return "Stored data: summary unavailable." end
    if type(value) ~= "string" or #value > 240 then
        return "Stored data: summary unavailable."
    end
    return "Stored data: " .. value
end

-- model: status(key), auto(key), toggle(key, value), action(key); all actions explicit.
function MclarionWow_CreateDashboard(model)
    local window = CreateFrame("Frame", "MclarionWowSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    local width, height = 520, 515
    if UIParent and type(UIParent.GetWidth) == "function" and type(UIParent.GetHeight) == "function" then
        local okW, w = pcall(UIParent.GetWidth, UIParent)
        local okH, h = pcall(UIParent.GetHeight, UIParent)
        if okW and type(w) == "number" and w > 0 then width = math.min(width, math.max(1, w - 28)) end
        if okH and type(h) == "number" and h > 0 then height = math.min(height, math.max(1, h - 28)) end
    end
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    local contentWidth = math.max(80, width - 44)
    local function measure(label, value)
        label:SetText(value)
        local h = label:GetStringHeight()
        label:SetHeight(math.max(14, h))
        return math.max(14, h)
    end
    local function text(font, y, value, maxWidth)
        local label = window:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", 18, y)
        label:SetWidth(maxWidth or contentWidth)
        label:SetJustifyH("LEFT")
        measure(label, value)
        return label
    end
    text("GameFontNormalLarge", -32, "Vaultkeeper | offline dashboard", contentWidth - 38)
    text("GameFontNormal", -57, "Auto-capture runs with window closed; no upload.")
    local indexHeight = math.min(140, math.max(30, height - 230))
    local indexWidth = math.max(55, contentWidth - 30)
    local index = CreateFrame("ScrollFrame", nil, window)
    index:SetSize(indexWidth, indexHeight)
    index:SetPoint("TOPLEFT", 18, -77)
    local indexContent = CreateFrame("Frame", nil, index)
    indexContent:SetSize(indexWidth, indexHeight)
    index:SetScrollChild(indexContent)
    local linkWidth = math.min(116, indexWidth * 0.36)
    local links, statusLabels, rowOffsets = {}, {}, {}
    for i, key in ipairs(keys) do
        local link = CreateFrame("Button", nil, indexContent, "UIPanelButtonTemplate")
        link:SetSize(linkWidth, 25)
        link:SetText(names[i])
        links[i] = link
        local label = indexContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetWidth(math.max(18, indexWidth - linkWidth - 9))
        label:SetJustifyH("LEFT")
        statusLabels[i] = label
    end
    local controlTop = 80 + indexHeight
    local compact = height <= 280
    local actionWidth = compact and math.min(115, contentWidth / 2) or math.min(190, contentWidth / 2)
    local position = text("GameFontNormalLarge", -controlTop, "",
        compact and contentWidth - actionWidth - 8 or contentWidth - 5)
    local checks, actions = {}, {}
    for _, i in ipairs({5, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11}) do
        local key = keys[i]
        local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 18, -(controlTop + 22))
        checks[i] = check
        local action = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        action:SetSize(actionWidth, 25)
        action:SetPoint("TOPLEFT", compact and (18 + contentWidth - actionWidth) or 18,
            -(controlTop + (compact and 0 or 53)))
        action:SetText(key == "combat" and "Stop logging now" or
            ({character="Character now",bags="Bags now",bank="Bank now",items="Items now",
            quest="Quests now",reputation="Reputation now",gold="Gold now",
            currency="Currencies now",honor="Honor now",title="Titles now"})[key])
        actions[i] = action
    end
    local optLabel = text("GameFontNormal", -(controlTop + 26), "Automatic capture / logging", math.max(35, contentWidth - 45))
    optLabel:ClearAllPoints()
    optLabel:SetPoint("TOPLEFT", 58, -(controlTop + 26))
    local footer = text("GameFontNormal", -height + 36, "Saves at /reload or exit; memory != disk.", contentWidth)
    footer:ClearAllPoints(); footer:SetPoint("BOTTOMLEFT", 18, 36)
    local detailTop = controlTop + (compact and 52 or 80)
    local detailHeight = math.max(1, height - detailTop - 36 - footer.height - 6)
    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetSize(contentWidth, detailHeight)
    scroll:SetPoint("TOPLEFT", 18, -detailTop)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth, detailHeight)
    scroll:SetScrollChild(content)
    local function body(font)
        local label = content:CreateFontString(nil, "OVERLAY", font)
        label:SetWidth(contentWidth - 8)
        label:SetJustifyH("LEFT")
        return label
    end
    local scope, trigger, result, timing, summary = body("GameFontHighlight"), body("GameFontHighlight"),
        body("GameFontHighlight"), body("GameFontHighlight"), body("GameFontHighlight")
    local function wheel(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(),
            self:GetVerticalScroll() - delta * 35)))
    end
    scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel", wheel)
    index:EnableMouseWheel(true); index:SetScript("OnMouseWheel", wheel)
    local up, down = CreateFrame("Button", nil, window, "UIPanelButtonTemplate"),
        CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    local arrowHeight = math.min(22, indexHeight / 2)
    up:SetSize(25, arrowHeight); up:SetPoint("TOPLEFT", 19 + indexWidth, -77); up:SetText("^")
    down:SetSize(25, arrowHeight); down:SetPoint("TOPLEFT", 19 + indexWidth, -(77 + indexHeight - arrowHeight)); down:SetText("v")
    up:SetScript("OnClick", function() wheel(index, 1) end)
    down:SetScript("OnClick", function() wheel(index, -1) end)
    local previous = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    previous:SetSize(math.min(95, contentWidth / 3), 23)
    previous:SetPoint("BOTTOMLEFT", 18, 10)
    previous:SetText("Previous")
    local nextButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    nextButton:SetSize(math.min(95, contentWidth / 3), 23)
    nextButton:SetPoint("BOTTOMRIGHT", -18, 10)
    nextButton:SetText("Next")
    local detailUp, detailDown = CreateFrame("Button", nil, window, "UIPanelButtonTemplate"),
        CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    detailUp:SetSize(27, 23); detailUp:SetPoint("BOTTOM", window, "BOTTOM", -17, 10); detailUp:SetText("^")
    detailDown:SetSize(27, 23); detailDown:SetPoint("BOTTOM", window, "BOTTOM", 17, 10); detailDown:SetText("v")
    detailUp:SetScript("OnClick", function() wheel(scroll, 1) end)
    detailDown:SetScript("OnClick", function() wheel(scroll, -1) end)
    local current = 1
    local function refresh()
        local key = keys[current]
        local state = model.status(key)
        measure(position, names[current] .. "  (" .. current .. "/11)")
        local y = 0
        local function place(label, value)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 0, -y)
            y = y + measure(label, value) + 8
        end
        place(scope, "Auto-capture works with this window closed; no upload.\nCaptured: " .. scopes[current])
        place(trigger, "Triggers: " .. triggers[current])
        place(result, "Result: " .. state.message)
        place(timing, "Last request (memory): " .. (state.attempt or "none this session") ..
            "\nLast changed capture (memory): " .. (state.success or "none this session"))
        place(summary, safeSummary(key))
        content:SetSize(contentWidth, math.max(detailHeight, y))
        local row = 0
        for i = 1, #keys do
            checks[i]:SetChecked(model.auto(keys[i]) == true)
            local observation = model.status(keys[i])
            local label = statusLabels[i]
            local value = ((keys[i] == "bank" and "Bank") or (keys[i] == "items" and "Items") or names[i]) .. ": " .. observation.message ..
                " | Auto: " .. (checks[i]:GetChecked() and "on" or "off") ..
                " | Last success (memory, this session): " .. (observation.success or "none")
            local labelHeight = measure(label, value)
            rowOffsets[i] = row
            links[i]:ClearAllPoints(); links[i]:SetPoint("TOPLEFT", 0, -row)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", linkWidth + 7, -row)
            row = row + math.max(25, labelHeight) + 8
            if i == current then checks[i]:Show(); actions[i]:Show()
            else checks[i]:Hide(); actions[i]:Hide() end
        end
        indexContent:SetSize(indexWidth, math.max(indexHeight, row))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
        index:SetVerticalScroll(math.min(index:GetVerticalScroll(), index:GetVerticalScrollRange()))
    end
    for i, key in ipairs(keys) do
        checks[i]:SetScript("OnClick", function(self)
            model.toggle(key, self:GetChecked() == true)
            refresh()
        end)
        actions[i]:SetScript("OnClick", function()
            model.action(key); refresh()
        end)
    end
    local categoryScroll = index
    local function navigate(index)
        if type(index) == "string" then
            for i, key in ipairs(keys) do if key == index then index = i; break end end
        end
        if type(index) == "number" and index == math.floor(index) and index >= 1 and index <= #keys then
            current = index; scroll:SetVerticalScroll(0); refresh()
            if rowOffsets[index] < categoryScroll:GetVerticalScroll() or
                rowOffsets[index] + 25 > categoryScroll:GetVerticalScroll() + indexHeight then
                categoryScroll:SetVerticalScroll(math.min(categoryScroll:GetVerticalScrollRange(), rowOffsets[index]))
            end
            return true
        end
        return false
    end
    for i = 1, #keys do
        links[i]:SetScript("OnClick", function() navigate(i) end)
    end
    previous:SetScript("OnClick", function()
        navigate(current == 1 and #keys or current - 1)
    end)
    nextButton:SetScript("OnClick", function()
        navigate(current == #keys and 1 or current + 1)
    end)
    -- Wheel is optional, buttons remain a complete keyboard/mouse navigation route.
    if type(window.EnableMouseWheel) == "function" then
        window:EnableMouseWheel(true)
        window:SetScript("OnMouseWheel", function(_, delta)
            navigate(delta > 0 and (current == 1 and #keys or current - 1) or
                (current == #keys and 1 or current + 1))
        end)
    end
    MclarionWow_DashboardNavigate = navigate
    MclarionWow_DashboardRefresh = refresh
    refresh()
    window:Hide()
    return window
end
