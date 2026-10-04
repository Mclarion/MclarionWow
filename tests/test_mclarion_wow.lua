local addonPath = ... or "../MclarionWow.lua"

local failures = 0
local tests = 0

local function expectEqual(actual, expected, message)
    tests = tests + 1
    if actual ~= expected then
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s\n  expected: %s\n  actual:   %s\n", message, tostring(expected), tostring(actual)))
    else
        io.stdout:write("PASS: " .. message .. "\n")
    end
end

local function expectTrue(value, message)
    expectEqual(value == true, true, message)
end

local function protectedSentinel()
    local function accessed() error("mock protected value was inspected") end
    return setmetatable({}, {
        __index = accessed,
        __tostring = accessed,
        __lt = accessed,
        __le = accessed,
        __add = accessed,
        __concat = accessed,
    })
end

local function sameData(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not sameData(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local now = 1720000000
local inCombat = false
local secretValues = setmetatable({}, { __mode = "k" })
local secretTables = setmetatable({}, { __mode = "k" })
local gear = {}
for slot = 1, 19 do gear[slot] = 1000 + slot end

_G = _G or _ENV
_G.GetServerTime = function() return now end
_G.UnitGUID = function(unit) assert(unit == "player"); return "Player-1234-ABCDEF12" end
_G.UnitName = function(unit) assert(unit == "player"); return "Name|Percent%" end
_G.GetRealmName = function() return "Realm|One%" end
_G.UnitClass = function(unit) assert(unit == "player"); return "Warrior", "WARRIOR", 1 end
_G.UnitLevel = function(unit) assert(unit == "player"); return 80 end
_G.UnitFactionGroup = function(unit) assert(unit == "player"); return "Alliance" end
_G.UnitRace = function(unit) assert(unit == "player"); return "Dwarf", "Dwarf" end
_G.UnitSex = function(unit) assert(unit == "player"); return 2 end
_G.C_Map = { GetBestMapForUnit = function(unit) assert(unit == "player"); return 2339 end }
_G.GetZoneText = function() return "Dornogal|Core" end
_G.GetInventoryItemID = function(unit, slot) assert(unit == "player"); return gear[slot] end
_G.GetBuildInfo = function() return "1.60.1", "70170", "Oct 1 2026", 16001 end
_G.GetLocale = function() return "enUS" end
_G.InCombatLockdown = function() return inCombat end
local combatLogging = false
local loggingCalls = 0
_G.LoggingCombat = function(enabled)
    if enabled ~= nil then loggingCalls = loggingCalls + 1; combatLogging = enabled end
    return combatLogging
end
_G.issecretvalue = function(value) return secretValues[value] == true end
_G.issecrettable = function(value) return secretTables[value] == true end
_G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 3 } end
    end,
}
_G.Enum = { BankType = { Character = 1 } }
_G.BankFrame = {
    shown = true, bankType = 1,
    IsShown = function(self) return self.shown end,
    GetActiveBankType = function(self) return self.bankType end,
}
_G.C_Bank = {
    AreAnyBankTypesViewable = function() return true end,
    CanViewBank = function(bankType) assert(bankType == Enum.BankType.Character); return true end,
    FetchPurchasedBankTabData = function(bankType)
        assert(bankType == Enum.BankType.Character)
        return { { ID = 6 }, { ID = 7 } }
    end,
}

local frames = {}
_G.UIParent = {}
_G.Minimap = {}
_G.SlashCmdList = {}
_G.CreateFrame = function(frameType, name, parent, template)
    local frame = {
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        shown = false,
        scripts = {},
    }
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:SetFrameStrata() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event)
        self.events = self.events or {}
        self.events[event] = true
    end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetAutoFocus() end
    function frame:SetMultiLine() end
    function frame:SetFontObject() end
    function frame:SetTextInsets() end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text end
    function frame:SetChecked(checked) self.checked = checked end
    function frame:GetChecked() return self.checked end
    function frame:HighlightText() self.highlighted = true end
    function frame:SetFocus() self.focused = true end
    function frame:ClearFocus() self.focused = false end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetNormalFontObject() end
    function frame:SetHighlightFontObject() end
    function frame:SetPushedTextOffset() end
    function frame:SetNormalTexture(texture) self.normalTexture = texture end
    function frame:SetHighlightTexture(texture) self.highlightTexture = texture end
    function frame:CreateFontString()
        local fontString = {}
        function fontString:SetPoint() end
        function fontString:SetText(text) self.text = text end
        self.fontStrings = self.fontStrings or {}
        self.fontStrings[#self.fontStrings + 1] = fontString
        return fontString
    end
    frames[#frames + 1] = frame
    return frame
end
_G.ChatFontNormal = {}
_G.GameFontNormal = {}
_G.GameFontNormalLarge = {}
_G.GameFontHighlight = {}
_G.GameFontDisable = {}

local chunk, loadError = loadfile(addonPath)
if not chunk then
    io.stderr:write("FAIL: addon loads: " .. tostring(loadError) .. "\n")
    os.exit(1)
end
chunk("MclarionWow", {})

local minimapButton
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowMinimapButton" then minimapButton = frame end
end
expectTrue(minimapButton and minimapButton.parent == Minimap and
    minimapButton.frameType == "Button" and type(minimapButton.scripts.OnClick) == "function",
    "a clickable icon is attached to the minimap")
for _, command in ipairs({ "MCLARIONWOW", "MCLARIONWOWIDENTITY", "MCLARIONWOWBAGSEXPORT",
    "MCLARIONWOWITEMSEXPORT", "MCLARIONWOWBANKSEXPORT", "MCLARIONWOWBANKITEMSEXPORT" }) do
    expectEqual(SlashCmdList[command], nil, "manual copy command " .. command .. " is retired")
end
expectEqual(_G.MclarionWowExportFrame, nil, "manual export window is not created")

expectTrue(type(MclarionWow_BuildExport) == "function", "exports a testable snapshot builder")

_G.C_Item = { GetItemInfo = function(itemId)
    if itemId == 4242 then
        return "Épée|Bright", "|Hitem:4242:0|h[Épée]|h", 4, 70, 60, "Weapon", "Sword", 1,
            "INVTYPE_WEAPON", 135274, 12345, 2, 7, 1, 11, nil, false, "A brave blade."
    end
end }
expectTrue(type(MclarionWow_BuildItemExport) == "function", "provides an item metadata export")
if type(MclarionWow_BuildItemExport) == "function" then
    local export, exportError = MclarionWow_BuildItemExport()
    expectEqual(exportError, nil, "item metadata export resolves own bag items")
    expectTrue(type(export) == "string" and export:find("MHWOWI1|forever|", 1, true) == 1 and
        export:find("|enUS|", 1, true) ~= nil and
        export:find("4242:C38970C3A9657C427269676874:", 1, true) ~= nil and
        export:find("|Hitem:", 1, true) == nil,
        "metadata export carries encoded name and all fields without raw markup")
    local originalInfo = C_Item.GetItemInfo
    local rootBefore = MclarionWowData
    inCombat = true
    export, exportError = MclarionWow_BuildItemExport()
    expectTrue(export == nil and exportError:find("combat", 1, true) ~= nil,
        "item export refuses combat")
    inCombat = false
    C_Item.GetItemInfo = function() return nil end
    export, exportError = MclarionWow_BuildItemExport()
    expectTrue(export == nil and exportError:find("cache", 1, true) ~= nil,
        "uncached item names are not invented")
    local protected = protectedSentinel()
    secretValues[protected] = true
    C_Item.GetItemInfo = function(id)
        if id == 4242 then
            return "Blade", "link", 1, 4, 1, "Weapon", "Sword", 1,
                "INVTYPE_WEAPON", 42, 1, 2, 7, 1, 0, nil, false, protected
        end
    end
    local safe
    safe, export, exportError = pcall(MclarionWow_BuildItemExport)
    expectTrue(safe and export == nil and exportError:find("protected", 1, true) ~= nil,
        "protected item metadata is refused before string conversion")
    C_Item.GetItemInfo = function(id)
        if id == 4242 then
            return "Blade", "link", nil, 4, 1, "Weapon", "Sword", 1,
                "INVTYPE_WEAPON", 42, 1, 2, 7, 1, 0, nil, false, "Description"
        end
    end
    export, exportError = MclarionWow_BuildItemExport()
    expectTrue(export == nil and exportError:find("number", 1, true) ~= nil,
        "missing numeric metadata cannot silently pass validation")
    C_Item.GetItemInfo = originalInfo
    local originalGearAPI = GetInventoryItemID
    local guardedGearAPI = function() error("protected gear API was invoked") end
    secretValues[guardedGearAPI] = true
    _G.GetInventoryItemID = guardedGearAPI
    safe, export, exportError = pcall(MclarionWow_BuildItemExport)
    expectTrue(safe and export == nil and exportError:find("protected", 1, true) ~= nil,
        "protected equipment API is refused before invocation")
    _G.GetInventoryItemID = originalGearAPI
    local originalLocaleAPI = GetLocale
    local guardedLocaleAPI = function() error("protected locale API was invoked") end
    secretValues[guardedLocaleAPI] = true
    _G.GetLocale = guardedLocaleAPI
    safe, export, exportError = pcall(MclarionWow_BuildItemExport)
    expectTrue(safe and export == nil and exportError:find("protected", 1, true) ~= nil,
        "protected locale API is refused before invocation")
    _G.GetLocale = originalLocaleAPI
    expectEqual(MclarionWowData, rootBefore, "manual item export leaves local persistence unchanged")
end

expectTrue(type(MclarionWow_ProbeBags) == "function", "provides an out-of-combat read-only bag probe")
if type(MclarionWow_ProbeBags) == "function" then
    local report, bagError = MclarionWow_ProbeBags()
    expectEqual(bagError, nil, "bag probe has no error with plain own-bag values")
    expectTrue(type(report) == "string" and report:find("2 slots", 1, true) ~= nil and
        report:find("1 occupied", 1, true) ~= nil and report:find("1 distinct", 1, true) ~= nil,
        "bag probe reports counts only")
    expectTrue(report:find("4242", 1, true) == nil, "bag probe does not expose item IDs")
    inCombat = true
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "bag probe refuses combat")
    inCombat = false
    local originalSlots = C_Container.GetContainerNumSlots
    local protectedSlots = protectedSentinel()
    secretValues[protectedSlots] = true
    C_Container.GetContainerNumSlots = function() return protectedSlots end
    local ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret slot count is rejected before arithmetic")
    expectEqual(protectedError, "Bag slot count is protected by the client.", "protected slot error is explicit")
    C_Container.GetContainerNumSlots = originalSlots
    secretValues[protectedSlots] = nil
    local originalInfo = C_Container.GetContainerItemInfo
    local protectedInfo = protectedSentinel()
    secretTables[protectedInfo] = true
    C_Container.GetContainerItemInfo = function() return protectedInfo end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret item table is rejected before indexing")
    expectEqual(protectedError, "Bag item is protected by the client.", "protected table error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretTables[protectedInfo] = nil
    local protectedId = protectedSentinel()
    secretValues[protectedId] = true
    C_Container.GetContainerItemInfo = function() return { itemID = protectedId, stackCount = 3 } end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret item ID is rejected before conversion")
    expectEqual(protectedError, "Bag item value is protected by the client.", "protected ID error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretValues[protectedId] = nil
    local protectedCount = protectedSentinel()
    secretValues[protectedCount] = true
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = protectedCount } end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret stack count is rejected before arithmetic")
    expectEqual(protectedError, "Bag item value is protected by the client.", "protected count error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretValues[protectedCount] = nil
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = 0 } end
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "invalid item count is rejected")
    C_Container.GetContainerItemInfo = originalInfo
    C_Container.GetContainerNumSlots = nil
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "missing bag API does not fall back to unsafe calls")
    C_Container.GetContainerNumSlots = originalSlots
    expectTrue(type(SlashCmdList.MCLARIONWOWBAGS) == "function", "registers explicit bag probe command")
    local storedBeforeProbe = MclarionWowData
    MclarionWowData = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    local expectedStorage = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    SlashCmdList.MCLARIONWOWBAGS()
    expectTrue(sameData(MclarionWowData, expectedStorage), "bag probe leaves nested saved data unchanged")
    MclarionWowData = storedBeforeProbe
end

expectTrue(type(MclarionWow_ProbeBank) == "function", "provides a manual count-only character bank probe")
if type(MclarionWow_ProbeBank) == "function" then
    local oldSlots, oldInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 2 or tab == 7 and 1 or 0 end
    C_Container.GetContainerItemInfo = function(tab, slot)
        if tab == 6 and slot == 1 then return { itemID = 4242, stackCount = 3 } end
        if tab == 7 and slot == 1 then return { itemID = 4242, stackCount = 1 } end
    end
    local rootBefore = MclarionWowData
    MclarionWowData = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    local expectedStorage = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    local report, problem = MclarionWow_ProbeBank()
    expectEqual(problem, nil, "viewable own character bank can be counted")
    local slotReads = 0
    C_Container.GetContainerNumSlots = function(...)
        slotReads = slotReads + 1
        return oldSlots(...)
    end
    BankFrame.bankType = 2
    local otherProbe, otherProblem = MclarionWow_ProbeBank()
    local otherExport = MclarionWow_BuildBankExport()
    local otherMetadata = MclarionWow_BuildBankItemExport()
    expectTrue(otherProbe == nil and otherExport == nil and otherMetadata == nil and
        type(otherProblem) == "string" and otherProblem:find("view", 1, true) ~= nil and
        slotReads == 0, "manual bank paths cannot scan while an account-bank page is active")
    BankFrame.bankType = Enum.BankType.Character
    BankFrame.shown = false
    local hiddenProbe, hiddenProblem = MclarionWow_ProbeBank()
    expectTrue(hiddenProbe == nil and type(hiddenProblem) == "string" and
        hiddenProblem:find("view", 1, true) ~= nil and slotReads == 0,
        "manual bank probe cannot scan a hidden character-bank frame")
    BankFrame.shown = true
    local previousFrame = BankFrame
    _G.BankFrame = 42
    local safeFrame, invalidProbe, invalidProblem = pcall(MclarionWow_ProbeBank)
    expectTrue(safeFrame and invalidProbe == nil and type(invalidProblem) == "string" and
        invalidProblem:find("view", 1, true) ~= nil and slotReads == 0,
        "malformed bank frame is refused without a Lua error or slot read")
    _G.BankFrame = previousFrame
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 2 or tab == 7 and 1 or 0 end
    expectTrue(report and report:find("2 tabs", 1, true) and
        report:find("3 slots", 1, true) and report:find("2 occupied", 1, true) and
        report:find("1 distinct", 1, true) and not report:find("4242", 1, true),
        "bank probe reports bounded counts without any item IDs")
    expectTrue(sameData(MclarionWowData, expectedStorage), "bank probe leaves nested saved data unchanged")
    expectTrue(type(SlashCmdList.MCLARIONWOWBANKPROBE) == "function", "bank count diagnostic remains available")
    SlashCmdList.MCLARIONWOWBANKPROBE()
    expectTrue(sameData(MclarionWowData, expectedStorage), "bank diagnostic never writes data")
    inCombat = true
    report, problem = MclarionWow_ProbeBank()
    expectTrue(report == nil and problem:find("combat", 1, true) ~= nil, "bank probe refuses combat")
    inCombat = false
    local oldCombat = InCombatLockdown
    _G.InCombatLockdown = nil
    local ok, missingReport, missingError = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and missingReport == nil and type(missingError) == "string" and
        missingError:find("unavailable", 1, true) ~= nil,
        "missing combat API fails closed without throwing")
    local protectedCombatMethod = protectedSentinel()
    secretValues[protectedCombatMethod] = true
    _G.InCombatLockdown = protectedCombatMethod
    ok, missingReport, missingError = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and missingReport == nil and type(missingError) == "string" and
        missingError:find("protected", 1, true) ~= nil,
        "protected combat API fails closed before invocation")
    _G.InCombatLockdown = oldCombat
    secretValues[protectedCombatMethod] = nil
    local oldView = C_Bank.CanViewBank
    C_Bank.CanViewBank = function() return false end
    report, problem = MclarionWow_ProbeBank()
    expectTrue(report == nil and problem:find("viewable", 1, true) ~= nil, "bank probe refuses closed bank")
    C_Bank.CanViewBank = oldView
    C_Bank.CanViewBank = nil
    ok, missingReport, missingError = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and missingReport == nil and type(missingError) == "string" and
        missingError:find("unavailable", 1, true) ~= nil,
        "missing bank-view method fails closed without throwing")
    C_Bank.CanViewBank = oldView
    local oldTabs = C_Bank.FetchPurchasedBankTabData
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 15 } } end
    report, problem = MclarionWow_ProbeBank()
    expectTrue(report == nil and problem:find("tab", 1, true) ~= nil, "account-bank tab ID is never scanned")
    local scannedTabs = 0
    C_Container.GetContainerNumSlots = function()
        scannedTabs = scannedTabs + 1
        return 0
    end
    C_Bank.FetchPurchasedBankTabData = function() return { [1] = { ID = 6 }, [3] = { ID = 15 } } end
    ok, report, problem = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and report == nil and type(problem) == "string" and
        problem:find("tab", 1, true) ~= nil, "sparse bank tabs fail closed")
    expectEqual(scannedTabs, 0, "malformed tabs are rejected before scanning")
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 2 or tab == 7 and 1 or 0 end
    local protected = protectedSentinel()
    secretValues[protected] = true
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = protected } } end
    ok, report, problem = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and report == nil and problem:find("protected", 1, true) ~= nil,
        "protected bank-tab ID is refused before comparison")
    secretValues[protected] = nil
    C_Bank.FetchPurchasedBankTabData = oldTabs
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = protected } end
    secretValues[protected] = true
    ok, report, problem = pcall(MclarionWow_ProbeBank)
    expectTrue(ok and report == nil and problem:find("protected", 1, true) ~= nil,
        "protected bank-item values fail closed")
    secretValues[protected] = nil
    C_Container.GetContainerItemInfo = oldInfo
    C_Container.GetContainerNumSlots = oldSlots
    expectTrue(sameData(MclarionWowData, expectedStorage), "bank probe failure leaves nested storage unchanged")
    MclarionWowData = rootBefore
end

expectTrue(type(MclarionWow_BuildBankExport) == "function",
    "provides a manual character-bank item export builder")
if type(MclarionWow_BuildBankExport) == "function" then
    local oldSlots, oldInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    local oldTabs = C_Bank.FetchPurchasedBankTabData
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 7 }, { ID = 6 } } end
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 3 or tab == 7 and 2 or 0 end
    C_Container.GetContainerItemInfo = function(tab, slot)
        if tab == 6 and slot == 1 then return { itemID = 4242, stackCount = 3 } end
        if tab == 6 and slot == 2 then return { itemID = 100, stackCount = 5 } end
        if tab == 6 and slot == 3 then return { itemID = 4242, stackCount = 2 } end
        if tab == 7 and slot == 1 then return { itemID = 100, stackCount = 4 } end
    end
    local savedBefore = MclarionWowData
    MclarionWowData = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing" } } }
    local expectedStorage = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing" } } }
    local bankExport, bankError, bankGuid = MclarionWow_BuildBankExport()
    expectEqual(bankError, nil, "viewable own character bank exports without error")
    expectEqual(bankGuid, "Player-1234-ABCDEF12", "bank export returns the validated player GUID")
    expectEqual(bankExport,
        "MHWOWK1|forever|1720000000|Player-1234-ABCDEF12|6:100:5,6:4242:5,7:100:4|70170",
        "bank export sorts by tab then item ID and aggregates only within each tab")
    expectTrue(sameData(MclarionWowData, expectedStorage),
        "building a bank export leaves nested saved data unchanged")

    C_Container.GetContainerNumSlots = function() return 1 end
    C_Container.GetContainerItemInfo = function() return nil end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectEqual(bankError, nil, "empty purchased character bank exports without error")
    expectEqual(bankExport, "MHWOWK1|forever|1720000000|Player-1234-ABCDEF12||70170",
        "empty bank keeps an empty fifth field")

    inCombat = true
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("combat", 1, true) ~= nil,
        "bank export refuses combat")
    inCombat = false
    local oldView = C_Bank.CanViewBank
    C_Bank.CanViewBank = function() return false end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("viewable", 1, true) ~= nil,
        "bank export refuses a closed character bank")
    C_Bank.CanViewBank = oldView

    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 15 } } end
    local scanCalls = 0
    C_Container.GetContainerNumSlots = function() scanCalls = scanCalls + 1; return 0 end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("tab", 1, true) ~= nil,
        "bank export rejects account-bank tab IDs")
    expectEqual(scanCalls, 0, "bank export validates all tab IDs before scanning any slots")

    local protected = protectedSentinel()
    secretValues[protected] = true
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = protected } } end
    local safe
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("protected", 1, true) ~= nil,
        "bank export rejects protected tab IDs before comparison")
    secretValues[protected] = nil

    scanCalls = 0
    C_Bank.FetchPurchasedBankTabData = function() return { [1] = { ID = 6 }, [3] = { ID = 7 } } end
    C_Container.GetContainerNumSlots = function() scanCalls = scanCalls + 1; return 0 end
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("tab", 1, true) ~= nil,
        "bank export rejects sparse tab metadata")
    expectEqual(scanCalls, 0, "sparse tab metadata is rejected before slot reads")

    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 } } end
    C_Container.GetContainerNumSlots = function() return 1 end
    secretValues[protected] = true
    C_Container.GetContainerItemInfo = function() return { itemID = protected, stackCount = 1 } end
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("protected", 1, true) ~= nil,
        "bank export rejects protected item IDs before table indexing or conversion")
    C_Container.GetContainerItemInfo = function() return { itemID = 1, stackCount = protected } end
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("protected", 1, true) ~= nil,
        "bank export rejects protected stack counts before arithmetic")
    local protectedItem = protectedSentinel()
    secretTables[protectedItem] = true
    C_Container.GetContainerItemInfo = function() return protectedItem end
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("protected", 1, true) ~= nil,
        "bank export rejects a protected item table before indexing")
    secretTables[protectedItem] = nil
    secretValues[protected] = nil

    C_Container.GetContainerItemInfo = function() return { itemID = 1, stackCount = 2147483647 } end
    C_Container.GetContainerNumSlots = function() return 2 end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("total", 1, true) ~= nil,
        "bank export refuses per-tab item total overflow")

    local tabs = {}
    for tabId = 6, 14 do tabs[#tabs + 1] = { ID = tabId } end
    C_Bank.FetchPurchasedBankTabData = function() return tabs end
    C_Container.GetContainerNumSlots = function() return 120 end
    C_Container.GetContainerItemInfo = function(tab, slot)
        return { itemID = (tab - 6) * 120 + slot, stackCount = 1 }
    end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport ~= nil and bankError == nil and #bankExport <= 32768,
        "bank export permits exactly 1080 bounded sorted entries")
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 120 or 0 end
    C_Container.GetContainerItemInfo = function(tab, slot)
        return { itemID = slot, stackCount = 1 }
    end
    local extraTabs = {}
    for index = 1, 10 do extraTabs[index] = { ID = 5 + index } end
    C_Bank.FetchPurchasedBankTabData = function() return extraTabs end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("tab", 1, true) ~= nil,
        "more than the nine supported character-bank tabs fails closed")

    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 } } end
    C_Container.GetContainerNumSlots = function() return 1 end
    local oldTime, oldGuid, oldBuild = GetServerTime, UnitGUID, GetBuildInfo
    _G.GetServerTime = function() return 253402300800 end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("metadata", 1, true) ~= nil,
        "bank export rejects timestamps beyond the parser range")
    _G.GetServerTime = oldTime
    _G.UnitGUID = function() return "Player-|bad" end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("metadata", 1, true) ~= nil,
        "bank export rejects malformed player GUID metadata")
    _G.UnitGUID = oldGuid
    _G.GetBuildInfo = function() return "1.60.1", "0", "Oct 1 2026", 16001 end
    bankExport, bankError = MclarionWow_BuildBankExport()
    expectTrue(bankExport == nil and bankError:find("build", 1, true) ~= nil,
        "bank export rejects invalid build metadata")
    _G.GetBuildInfo = oldBuild
    local protectedTimeApi = function() error("protected time API was invoked") end
    secretValues[protectedTimeApi] = true
    _G.GetServerTime = protectedTimeApi
    safe, bankExport, bankError = pcall(MclarionWow_BuildBankExport)
    expectTrue(safe and bankExport == nil and bankError:find("protected", 1, true) ~= nil,
        "bank export rejects a protected metadata API before invocation")
    _G.GetServerTime = oldTime
    secretValues[protectedTimeApi] = nil

    C_Bank.FetchPurchasedBankTabData = oldTabs
    C_Container.GetContainerNumSlots = oldSlots
    C_Container.GetContainerItemInfo = oldInfo
    MclarionWowData = savedBefore
end

expectTrue(type(MclarionWow_BuildBankItemExport) == "function",
    "provides a manual character-bank metadata export builder")
if type(MclarionWow_BuildBankItemExport) == "function" then
    local oldSlots, oldInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    local oldTabs, oldView = C_Bank.FetchPurchasedBankTabData, C_Bank.CanViewBank
    local oldItemInfo = C_Item.GetItemInfo
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 } } end
    C_Container.GetContainerNumSlots = function() return 2 end
    C_Container.GetContainerItemInfo = function(_, slot)
        if slot == 1 then return { itemID = 9001, stackCount = 1 } end
        if slot == 2 then return { itemID = 9001, stackCount = 2 } end
    end
    C_Item.GetItemInfo = function(itemId)
        if itemId == 9001 then
            return "Bank-only Relic", "|Hitem:9001:0|h[Bank-only Relic]|h", 3, 70, 60,
                "Armor", "Miscellaneous", 20, "", 987654, 2500, 4, 0, 1, 11,
                nil, false, "Found only in the character bank."
        end
    end
    local savedBefore = MclarionWowData
    MclarionWowData = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing" } } }
    local expectedStorage = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing" } } }
    local export, exportError, exportGuid, page, pages = MclarionWow_BuildBankItemExport()
    expectEqual(exportError, nil, "bank-only metadata exports from a viewable own character bank")
    expectEqual(exportGuid, "Player-1234-ABCDEF12", "bank metadata export returns the player GUID")
    expectEqual(page, 1, "bank metadata export defaults to the first page")
    expectEqual(pages, 1, "one bank-only item fits on one metadata page")
    expectTrue(type(export) == "string" and export:find("MHWOWI1|forever|", 1, true) == 1 and
        export:find("9001:42616E6B2D6F6E6C792052656C6963:", 1, true) ~= nil and
        export:find("4242:", 1, true) == nil,
        "bank metadata contains the bank-only name and excludes bag-only IDs")
    expectTrue(sameData(MclarionWowData, expectedStorage),
        "bank metadata export never writes SavedVariables")

    local ids = {}
    for id = 1, 129 do ids[id] = id end
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, { ID = 7 } } end
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 120 or 9 end
    C_Container.GetContainerItemInfo = function(tab, slot)
        local index = tab == 6 and slot or 120 + slot
        return { itemID = ids[index], stackCount = 1 }
    end
    C_Item.GetItemInfo = function(itemId)
        return "Item " .. itemId, "link" .. itemId, 1, 1, 1, "Misc", "Other", 1,
            "", itemId, 0, 15, 0, 0, 0, nil, false, ""
    end
    export, exportError, _, page, pages = MclarionWow_BuildBankItemExport(2)
    expectEqual(exportError, nil, "bank metadata supports a second bounded page")
    expectEqual(page, 2, "bank metadata reports the selected page")
    expectEqual(pages, 2, "129 bank IDs require two metadata pages")
    expectTrue(export and export:find("129:4974656D20313239:", 1, true) ~= nil and
        export:find("128:4974656D20313238:", 1, true) == nil,
        "second bank metadata page contains only IDs after the first 128")
    export, exportError = MclarionWow_BuildBankItemExport(3)
    expectTrue(export == nil and exportError:find("page", 1, true) ~= nil,
        "bank metadata refuses a page beyond the bounded result set")

    local protected = protectedSentinel()
    secretValues[protected] = true
    C_Container.GetContainerNumSlots = function() return 1 end
    C_Container.GetContainerItemInfo = function() return { itemID = protected, stackCount = 1 } end
    local safe
    safe, export, exportError = pcall(MclarionWow_BuildBankItemExport)
    expectTrue(safe and export == nil and exportError:find("protected", 1, true) ~= nil,
        "bank metadata refuses protected bank item IDs before indexing")
    secretValues[protected] = nil
    C_Container.GetContainerItemInfo = function() return { itemID = 9001, stackCount = 1 } end
    C_Item.GetItemInfo = function()
        return "Bank-only Relic", "link", 3, 70, 60, "Armor", "Miscellaneous", 20,
            "", 987654, 2500, 4, 0, 1, 11, nil, false, protected
    end
    secretValues[protected] = true
    safe, export, exportError = pcall(MclarionWow_BuildBankItemExport)
    expectTrue(safe and export == nil and exportError:find("protected", 1, true) ~= nil,
        "bank metadata refuses protected item metadata")
    secretValues[protected] = nil

    C_Bank.FetchPurchasedBankTabData = oldTabs
    C_Bank.CanViewBank = oldView
    C_Container.GetContainerNumSlots = oldSlots
    C_Container.GetContainerItemInfo = oldInfo
    C_Item.GetItemInfo = oldItemInfo
    MclarionWowData = savedBefore
end

local originalCombatCheck = InCombatLockdown
local protectedCombat = protectedSentinel()
secretValues[protectedCombat] = true
_G.InCombatLockdown = function() return protectedCombat end
local safeProbe, blockedProbe, probeError = pcall(MclarionWow_ProbeBags)
expectTrue(safeProbe and blockedProbe == nil and type(probeError) == "string" and
    probeError:find("protected", 1, true) ~= nil, "protected combat status blocks bag reads")
local safeCharacter, blockedCharacter, characterError = pcall(MclarionWow_BuildExport)
expectTrue(safeCharacter and blockedCharacter == nil and type(characterError) == "string" and
    characterError:find("protected", 1, true) ~= nil, "protected combat status blocks character reads")
_G.InCombatLockdown = originalCombatCheck
secretValues[protectedCombat] = nil

expectTrue(type(MclarionWow_BuildBagExport) == "function", "builds a manual bag export")
if type(MclarionWow_BuildBagExport) == "function" then
    local bagExport, bagError = MclarionWow_BuildBagExport()
    expectEqual(bagError, nil, "plain bag data exports without error")
    expectEqual(bagExport, "MHWOWB1|forever|1720000000|Player-1234-ABCDEF12|4242:3|70170",
        "bag export contains only sorted own item totals and metadata")
    expectEqual(MclarionWowData, nil, "building a bag export does not save it")
    local originalSlots = C_Container.GetContainerNumSlots
    local originalInfo = C_Container.GetContainerItemInfo
    C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag ~= 0 then return nil end
        if slot == 1 then return { itemID = 4242, stackCount = 3 } end
        if slot == 2 then return { itemID = 100, stackCount = 5 } end
        if slot == 3 then return { itemID = 4242, stackCount = 2 } end
    end
    bagExport = MclarionWow_BuildBagExport()
    expectEqual(bagExport, "MHWOWB1|forever|1720000000|Player-1234-ABCDEF12|100:5,4242:5|70170",
        "bag export sorts item IDs and sums stacks across slots")
    C_Container.GetContainerNumSlots = originalSlots
    C_Container.GetContainerItemInfo = originalInfo
end

local expectedGear = {}
for slot = 1, 19 do expectedGear[#expectedGear + 1] = tostring(1000 + slot) end
local expected = table.concat({
    "MHWOW1",
    "forever",
    tostring(now),
    "Player-1234-ABCDEF12",
    "Name%7CPercent%25",
    "Realm%7COne%25",
    "WARRIOR",
    "80",
    "2339",
    "Dornogal%7CCore",
    table.concat(expectedGear, ","),
    "70170",
}, "|")

local export, err = MclarionWow_BuildExport()
expectEqual(err, nil, "valid snapshot has no error")
expectEqual(export, expected, "builds exactly twelve escaped pipe-separated fields")
expectEqual(select(2, export:gsub("|", "")), 11, "export has exactly twelve fields")
local identity, identityError, identityGuid = MclarionWow_BuildIdentityExport()
expectEqual(identityError, nil, "own-character identity APIs permit a valid export")
expectEqual(identity, expected:gsub("^MHWOW1|", "MHWOW2|", 1) .. "|Alliance|Dwarf|Male",
    "identity export appends a versioned faction, race and gender")
expectEqual(identityGuid, "Player-1234-ABCDEF12", "identity export retains own player GUID")
for _, apiName in ipairs({ "UnitFactionGroup", "UnitRace", "UnitSex" }) do
    local original = _G[apiName]
    secretValues[original] = true
    local safe, blocked, reason = pcall(MclarionWow_BuildIdentityExport)
    expectTrue(safe and blocked == nil and type(reason) == "string" and
        reason:find("protected", 1, true) ~= nil,
        "identity export refuses protected " .. apiName .. " before invocation")
    secretValues[original] = nil
end
local originalFaction, originalRace, originalSex = UnitFactionGroup, UnitRace, UnitSex
local protectedIdentity = protectedSentinel()
secretValues[protectedIdentity] = true
_G.UnitFactionGroup = function() return protectedIdentity end
local safe, blocked, reason = pcall(MclarionWow_BuildIdentityExport)
expectTrue(safe and blocked == nil and reason:find("protected", 1, true) ~= nil,
    "protected faction value is never converted")
_G.UnitFactionGroup = originalFaction
_G.UnitRace = function() return "Dwarf", protectedIdentity end
safe, blocked, reason = pcall(MclarionWow_BuildIdentityExport)
expectTrue(safe and blocked == nil and reason:find("protected", 1, true) ~= nil,
    "protected race value is never converted")
_G.UnitRace = originalRace
_G.UnitSex = function() return protectedIdentity end
safe, blocked, reason = pcall(MclarionWow_BuildIdentityExport)
expectTrue(safe and blocked == nil and reason:find("protected", 1, true) ~= nil,
    "protected gender value is never compared")
secretValues[protectedIdentity] = nil
_G.UnitSex = function() return 3 end
expectTrue(MclarionWow_BuildIdentityExport():find("|Alliance|Dwarf|Female$") ~= nil,
    "female identity is preserved as a fixed enum")
_G.UnitSex = function() return 1 end
expectTrue(MclarionWow_BuildIdentityExport():find("|Alliance|Dwarf|Unknown$") ~= nil,
    "unspecified gender is represented as unknown")
_G.UnitSex = function() return 7 end
expectEqual(MclarionWow_BuildIdentityExport(), nil, "invalid gender is refused")
_G.UnitSex = originalSex
_G.UnitRace = function() return "Dwarf", "Dwarf|forged" end
expectEqual(MclarionWow_BuildIdentityExport(), nil, "race cannot inject export separators")
_G.UnitRace = originalRace
_G.UnitFactionGroup = function() return "Other" end
expectEqual(MclarionWow_BuildIdentityExport(), nil, "unknown faction is refused")
_G.UnitFactionGroup = originalFaction
for _, apiName in ipairs({ "GetServerTime", "UnitGUID", "UnitName", "GetRealmName",
    "UnitClass", "UnitLevel", "GetZoneText", "GetBuildInfo", "GetInventoryItemID" }) do
    local original = _G[apiName]
    secretValues[original] = true
    local safe, blocked, reason = pcall(MclarionWow_BuildExport)
    expectTrue(safe and blocked == nil and type(reason) == "string" and
        reason:find("protected", 1, true) ~= nil,
        "character export rejects protected " .. apiName .. " before invocation")
    secretValues[original] = nil
end
for _, apiName in ipairs({ "GetServerTime", "UnitGUID", "GetBuildInfo" }) do
    local original = _G[apiName]
    secretValues[original] = true
    local safe, blocked, reason = pcall(MclarionWow_BuildBagExport)
    expectTrue(safe and blocked == nil and type(reason) == "string" and
        reason:find("protected", 1, true) ~= nil,
        "bag export rejects protected " .. apiName .. " before scanning")
    secretValues[original] = nil
end
local originalClass, originalRealm = UnitClass, GetRealmName
_G.UnitClass = function() return "Rogue", "ROGUE", 4 end
_G.GetRealmName = function() return "Classic Beta PvP 2" end
local rogueExport = MclarionWow_BuildExport()
expectTrue(rogueExport:find("|Classic Beta PvP 2|ROGUE|", 1, true) ~= nil and
    select(2, rogueExport:gsub("|", "")) == 11,
    "rogue class stays distinct from a realm ending in a number")
_G.UnitClass, _G.GetRealmName = originalClass, originalRealm

local originalMap = C_Map
local protectedMap = protectedSentinel()
secretTables[protectedMap] = true
_G.C_Map = protectedMap
local safeMap, blockedMap, mapError = pcall(MclarionWow_BuildExport)
expectTrue(safeMap and blockedMap == nil and type(mapError) == "string" and
    mapError:find("protected", 1, true) ~= nil, "protected map API is not indexed")
_G.C_Map = originalMap
secretTables[protectedMap] = nil
local originalName = UnitName
_G.UnitName = function() return string.rep("n", 81) end
local oversizedName, nameError = MclarionWow_BuildExport()
expectTrue(oversizedName == nil and nameError ~= nil,
    "character export refuses text larger than the website parser accepts")
_G.UnitName = originalName
local normalTime = now
now = 253402300800
local futureExport = MclarionWow_BuildExport()
expectEqual(futureExport, nil, "timestamp outside website parser range is refused")
now = normalTime

gear[5] = nil
export, err = MclarionWow_BuildExport()
local parts = {}
for part in export:gmatch("([^|]+)") do parts[#parts + 1] = part end
local gearParts = {}
for id in parts[11]:gmatch("([^,]+)") do gearParts[#gearParts + 1] = id end
expectEqual(#gearParts, 19, "gear CSV always has nineteen entries")
expectEqual(gearParts[5], "0", "empty inventory slot exports as zero")
gear[5] = 1005

inCombat = true
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "combat blocks export")
expectTrue(type(err) == "string" and #err > 0, "combat returns a user-facing error")
inCombat = false

local originalName = _G.UnitName
_G.UnitName = function() local value = {}; secretValues[value] = true; return value end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "secret text blocks export")
_G.UnitName = originalName

_G.UnitName = function() return "Invalid\nName" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "control characters block export")
_G.UnitName = originalName

local originalItem = gear[7]
secretValues[originalItem] = true
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "secret gear ID blocks export")
secretValues[originalItem] = nil
gear[7] = 2147483648
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "gear IDs beyond the website parser range are refused")
gear[7] = originalItem

local originalBuildInfo = _G.GetBuildInfo
local protectedBuild = {}
secretValues[protectedBuild] = true
_G.GetBuildInfo = function() return "1.60.1", protectedBuild, "Oct 1 2026", 16001 end
local buildOk, buildExport, buildError = pcall(MclarionWow_BuildExport)
expectTrue(buildOk and buildExport == nil and
    type(buildError) == "string" and buildError:find("protected", 1, true) ~= nil,
    "protected build refuses export without throwing")
_G.GetBuildInfo = originalBuildInfo
secretValues[protectedBuild] = nil

local originalMap = _G.C_Map.GetBestMapForUnit
local protectedMap = {}
secretValues[protectedMap] = true
_G.C_Map.GetBestMapForUnit = function() return protectedMap end
local mapOk, mapExport, mapError = pcall(MclarionWow_BuildExport)
expectTrue(mapOk and mapExport == nil and
    type(mapError) == "string" and mapError:find("protected", 1, true) ~= nil,
    "protected map refuses export without throwing")
_G.C_Map.GetBestMapForUnit = originalMap
secretValues[protectedMap] = nil

_G.UnitLevel = function() return 0 end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-positive level blocks export")
_G.UnitLevel = function() return 80 end

_G.UnitGUID = function() return "Creature-0-0-0-0-1-0" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-player GUID blocks export")
_G.UnitGUID = function() return "Player-|bad" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "malformed player GUID does not add export fields")
_G.UnitGUID = function() return "Player-" .. string.rep("a", 71) end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "character GUID exceeding website bound is refused")
_G.UnitGUID = function() return "Player-1234-ABCDEF12" end

if minimapButton and minimapButton.scripts.OnClick then
    minimapButton.scripts.OnClick(minimapButton)
    local panel
    for _, frame in ipairs(frames) do
        if frame.name == "MclarionWowSettingsFrame" then panel = frame end
    end
    expectTrue(panel and panel:IsShown(), "minimap icon opens the addon settings")
    minimapButton.scripts.OnClick(minimapButton)
    expectTrue(panel and not panel:IsShown(), "minimap icon closes the addon settings")
    local actionButtons = {}
    for _, frame in ipairs(frames) do
        if frame.parent == panel and frame.frameType == "Button" then
            actionButtons[frame.text] = frame
        end
    end
    for _, label in ipairs({ "Character now", "Bags now", "Bank now", "Items now" }) do
        expectTrue(actionButtons[label] and type(actionButtons[label].scripts.OnClick) == "function",
            label .. " provides an explicit capture without a copy window")
    end
    expectEqual(actionButtons["Character"], nil, "old copy-export button remains retired")
    expectEqual(actionButtons["Bank (manual)"], nil, "old manual bank export button remains retired")
end

-- Verify that removing clipboard commands does not remove the bounded histories.
MclarionWowData = { schema = 1, characters = {}, settings = {
    autoCombatLog = false, autoCharacterCapture = true,
    autoBagCapture = true, autoBankCapture = false } }
chunk("MclarionWow", {})
local historyFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_ENTERING_WORLD then historyFrame = frame end
end
historyFrame.scripts.OnEvent(historyFrame, "PLAYER_ENTERING_WORLD")
local history = MclarionWowData.characters["Player-1234-ABCDEF12"]
local bagHistory = MclarionWowData.bags["Player-1234-ABCDEF12"]
expectTrue(history and #history == 1 and history[1]:find("^MHWOW2|forever|") ~= nil,
    "automatic character snapshot remains available without manual commands")
expectTrue(bagHistory and #bagHistory == 1 and bagHistory[1]:find("^MHWOWB1|forever|") ~= nil,
    "automatic bag snapshot remains available without manual commands")
expectTrue(historyFrame.events.PLAYER_LEVEL_UP and historyFrame.events.ZONE_CHANGED and
    historyFrame.events.ZONE_CHANGED_INDOORS,
    "level and zone notifications trigger the opted-in character observation")
local originalLevel, originalZone = UnitLevel, GetZoneText
_G.UnitLevel = function(unit) assert(unit == "player"); return 81 end
now = now + 1
historyFrame.scripts.OnEvent(historyFrame, "PLAYER_LEVEL_UP", 81)
expectEqual(#history, 2, "level-up appends a versioned own-character observation")
expectTrue(history[2] and history[2]:find("|81|2339|", 1, true) ~= nil,
    "level observation uses the validated UnitLevel result")
historyFrame.scripts.OnEvent(historyFrame, "PLAYER_LEVEL_UP", 81)
expectEqual(#history, 2, "unchanged level-up event does not append a duplicate")
_G.GetZoneText = function() return "Another Zone" end
now = now + 1
historyFrame.scripts.OnEvent(historyFrame, "ZONE_CHANGED")
expectEqual(#history, 3, "zone transition appends a versioned own-character observation")
expectTrue(history[3] and history[3]:find("|Another Zone|", 1, true) ~= nil,
    "zone observation uses the validated zone text")
_G.GetZoneText = function() return "" end
historyFrame.scripts.OnEvent(historyFrame, "ZONE_CHANGED_INDOORS")
expectEqual(#history, 3, "unavailable zone text cannot append a transient empty observation")
_G.UnitLevel, _G.GetZoneText = originalLevel, originalZone
now = now + 1
historyFrame.scripts.OnEvent(historyFrame, "BAG_UPDATE_DELAYED")
expectEqual(#bagHistory, 1, "unchanged bag totals still deduplicate")
for index = 1, 22 do
    now = now + 1
    gear[1] = gear[1] + 1
    historyFrame.scripts.OnEvent(historyFrame, "PLAYER_EQUIPMENT_CHANGED")
end
expectEqual(#history, 20, "automatic character history still caps at twenty states")
local originalBagInfo = C_Container.GetContainerItemInfo
for index = 1, 22 do
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = index + 3 } end
    end
    historyFrame.scripts.OnEvent(historyFrame, "BAG_UPDATE_DELAYED")
end
C_Container.GetContainerItemInfo = originalBagInfo
expectEqual(#bagHistory, 20, "automatic bag history still caps at twenty states")
local previous = history[#history]
inCombat = true
gear[1] = gear[1] + 1
historyFrame.scripts.OnEvent(historyFrame, "PLAYER_EQUIPMENT_CHANGED")
expectEqual(history[#history], previous, "combat still blocks automatic character capture")
inCombat = false

-- Automatic capture remains local to WoW; it never transfers data to the site.
MclarionWowData = { schema = 1, characters = {} }
_G.EventRegistry = { callbacks = {}, RegisterCallback = function(self, event, callback)
    self.callbacks[event] = callback
end }
chunk("MclarionWow", {})
local captureFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_ENTERING_WORLD then captureFrame = frame end
end
expectTrue(captureFrame ~= nil, "registers an automatic capture frame")
if captureFrame then
    local automaticBankReads = 0
    local originalBankApis = {}
    for name, api in pairs(C_Bank) do
        if type(api) == "function" then
            originalBankApis[name] = api
            C_Bank[name] = function(...)
                automaticBankReads = automaticBankReads + 1
                return api(...)
            end
        end
    end
    local originalNumSlots, originalItemInfo =
        C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    C_Container.GetContainerNumSlots = function(bag, ...)
        if type(bag) == "number" and bag >= 6 then automaticBankReads = automaticBankReads + 1 end
        return originalNumSlots(bag, ...)
    end
    C_Container.GetContainerItemInfo = function(bag, ...)
        if type(bag) == "number" and bag >= 6 then automaticBankReads = automaticBankReads + 1 end
        return originalItemInfo(bag, ...)
    end
    now = now + 1
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
    local settings = MclarionWowData.settings
    expectTrue(settings and settings.autoCombatLog == false and
        settings.autoCharacterCapture == false and settings.autoBagCapture == false and
        settings.autoBankCapture == false, "first login requires consent for every automatic capture")
    expectEqual(loggingCalls, 0, "first login does not write a combat-log file without opt-in")
    expectTrue(not MclarionWowData.characters["Player-1234-ABCDEF12"] and
        MclarionWowData.bags == nil, "first login does not capture identity or bags without opt-in")
    settings.autoCombatLog = true
    settings.autoCharacterCapture = true
    settings.autoBagCapture = true
    settings.autoBankCapture = true
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
    expectTrue(combatLogging and loggingCalls == 1,
        "entering the world enables WoW's own combat-log file once")
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
    expectEqual(loggingCalls, 1, "an already-enabled combat log is not restarted")
    local snapshots = MclarionWowData.characters["Player-1234-ABCDEF12"]
    expectEqual(snapshots and #snapshots, 1, "entering the world stores a local snapshot")
    expectTrue(captureFrame.events.BAG_UPDATE_DELAYED,
        "registers the coalesced own-bag update event")
    expectTrue(captureFrame.events.BAG_OPEN, "registers the player bag-open event")
    local bagSnapshots = MclarionWowData.bags and MclarionWowData.bags["Player-1234-ABCDEF12"]
    expectEqual(bagSnapshots and #bagSnapshots, 1, "entering the world stores a bag snapshot")
    local filledSnapshot = bagSnapshots and bagSnapshots[1]
    local availableSlots = C_Container.GetContainerNumSlots
    C_Container.GetContainerNumSlots = function() return 0 end
    local missingExport, missingReason = MclarionWow_BuildBagExport()
    expectTrue(missingExport == nil and type(missingReason) == "string" and
        missingReason:find("slots", 1, true) ~= nil,
        "zero reported backpack slots refuse an uninitialized bag snapshot")
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 1, "zero-slot bag scan preserves populated history")
    C_Container.GetContainerNumSlots = availableSlots
    local occupiedItem = C_Container.GetContainerItemInfo
    C_Container.GetContainerItemInfo = function() return nil end
    local validEmpty, validEmptyError = MclarionWow_BuildBagExport()
    expectTrue(type(validEmpty) == "string" and validEmptyError == nil and
        validEmpty:find("||70170", 1, true) ~= nil,
        "initialized empty backpack still produces a valid candidate export")
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 1, "automatic all-nil item scan cannot erase populated bags")
    expectEqual(bagSnapshots[1], filledSnapshot, "earlier populated bag snapshot remains current")
    C_Container.GetContainerItemInfo = occupiedItem
    local originalBagInfo = C_Container.GetContainerItemInfo
    now = now + 1
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 4 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "bag update stores a changed inventory total")
    expectTrue(bagSnapshots[2]:find("|4242:4|", 1, true) ~= nil,
        "bag update stores aggregate counts, not inferred loot")
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "repeating an unchanged bag event does not grow history")
    inCombat = true
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 5 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "bag capture refuses combat")
    inCombat = false
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_REGEN_ENABLED")
    expectEqual(#bagSnapshots, 3, "after combat, pending bag change can be captured")
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 6 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_OPEN", 0)
    expectEqual(#bagSnapshots, 4, "opening own backpack checks and stores changed totals")
    local protectedBagID = protectedSentinel()
    secretValues[protectedBagID] = true
    captureFrame.scripts.OnEvent(captureFrame, "BAG_OPEN", protectedBagID)
    expectEqual(#bagSnapshots, 4, "protected bag-open argument is not inspected")
    secretValues[protectedBagID] = nil
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 7 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_OPEN", 6)
    expectEqual(#bagSnapshots, 4, "opening a non-player bag cannot trigger a capture")
    C_Container.GetContainerItemInfo = originalBagInfo
    now = now + 300
    captureFrame.scripts.OnUpdate(captureFrame, 300)
    expectEqual(#snapshots, 1, "unchanged periodic capture does not fill history")
    gear[1] = 9001
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_EQUIPMENT_CHANGED")
    expectEqual(#snapshots, 2, "equipment change stores a new snapshot")
    expectTrue(snapshots[2]:find("|9001,", 1, true) ~= nil,
        "new snapshot carries changed equipment")
    inCombat = true
    gear[1] = 9002
    captureFrame.scripts.OnUpdate(captureFrame, 300)
    expectEqual(#snapshots, 2, "periodic capture skips combat")
    inCombat = false
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_REGEN_ENABLED")
    expectEqual(#snapshots, 3, "after combat, pending equipment can be captured")
    local characterCount, bagCount = #snapshots, #bagSnapshots
    local originalCombat = InCombatLockdown
    _G.InCombatLockdown = function() error("combat API unavailable") end
    local eventSafe = pcall(captureFrame.scripts.OnEvent, captureFrame, "PLAYER_REGEN_ENABLED")
    local updateSafe = pcall(captureFrame.scripts.OnUpdate, captureFrame, 300)
    expectTrue(eventSafe and updateSafe and #snapshots == characterCount and
        #bagSnapshots == bagCount,
        "automatic events contain combat API failures without writing")
    _G.InCombatLockdown = originalCombat
    expectEqual(automaticBankReads, 0,
        "ordinary bag, character and timer events never scan the character bank")
    for name, api in pairs(originalBankApis) do C_Bank[name] = api end
    C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo =
        originalNumSlots, originalItemInfo
end

if captureFrame then
    expectTrue(captureFrame.events.BANKFRAME_OPENED,
        "own-bank opening is observed without automated page switching")
    local originalSlots, originalInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    local originalTabs, originalBankFrame = C_Bank.FetchPurchasedBankTabData, BankFrame
    _G.BankFrame = {
        IsShown = function() return true end,
        GetActiveBankType = function() return Enum.BankType.Character end,
    }
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, { ID = 7 } } end
    C_Container.GetContainerNumSlots = function(tab) return (tab == 6 or tab == 7) and 1 or 0 end
    C_Container.GetContainerItemInfo = function(tab)
        if tab == 6 then return { itemID = 4242, stackCount = 3 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
    local history = MclarionWowData.bank and MclarionWowData.bank["Player-1234-ABCDEF12"]
    expectTrue(history and #history == 1 and
        history[1]:find("|6:4242:3|", 1, true) ~= nil,
        "opening own bank stores bounded character-bank totals in memory")
    if history then
        C_Bank.FetchPurchasedBankTabData = function() return {} end
        local noTabs, noTabsError = MclarionWow_BuildBankExport()
        expectTrue(noTabs == nil and type(noTabsError) == "string" and
            noTabsError:find("tabs", 1, true) ~= nil,
            "uninitialized bank tabs cannot make an empty bank history")
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 1, "uninitialized bank tabs preserve populated bank history")
        C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, { ID = 7 } } end
        C_Container.GetContainerNumSlots = function() return 0 end
        local noSlots, noSlotsError = MclarionWow_BuildBankExport()
        expectTrue(noSlots == nil and type(noSlotsError) == "string" and
            noSlotsError:find("slots", 1, true) ~= nil,
            "uninitialized bank slots cannot make an empty bank history")
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 1, "uninitialized bank slots preserve populated bank history")
        C_Container.GetContainerNumSlots = function(tab) return (tab == 6 or tab == 7) and 1 or 0 end
        local occupiedBankItem = C_Container.GetContainerItemInfo
        C_Container.GetContainerItemInfo = function() return nil end
        local emptyBank, emptyBankError = MclarionWow_BuildBankExport()
        expectTrue(type(emptyBank) == "string" and emptyBankError == nil and
            emptyBank:find("||70170", 1, true) ~= nil,
            "initialized empty bank tabs still produce a valid candidate export")
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 1, "automatic all-nil bank scan cannot erase populated bank history")
        C_Container.GetContainerItemInfo = occupiedBankItem
        C_Container.GetContainerItemInfo = function(tab)
            if tab == 6 then return { itemID = 4242, stackCount = 4 } end
        end
        local pageSelected = EventRegistry.callbacks["BankPanelMixin.PageSelected"]
        expectTrue(type(pageSelected) == "function", "observes player-selected bank pages")
        if pageSelected then pageSelected() end
        expectEqual(#history, 2, "selecting a bank page stores changed character-bank totals")
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 2, "unchanged open-bank state is deduplicated")
        BankFrame.GetActiveBankType = function() return 2 end
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 2, "account-bank view never stores character-bank data")
        BankFrame.GetActiveBankType = function() return Enum.BankType.Character end
        inCombat = true
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 2, "automatic bank capture refuses combat")
        inCombat = false
        MclarionWowData.settings.autoBankCapture = false
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(#history, 2, "disabled automatic bank capture leaves history unchanged")
        MclarionWowData.settings.autoBankCapture = true
        secretValues[BankFrame] = true
        expectTrue(pcall(captureFrame.scripts.OnEvent, captureFrame, "BANKFRAME_OPENED"),
            "protected bank frame does not crash the addon")
        expectEqual(#history, 2, "protected bank frame is never read")
        secretValues[BankFrame] = nil
        local oldEnum = Enum
        local protectedReads = 0
        local protectedEnum = setmetatable({}, { __index = function()
            protectedReads = protectedReads + 1
            error("protected Enum was inspected")
        end })
        secretTables[protectedEnum] = true
        _G.Enum = protectedEnum
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(protectedReads, 0, "automatic bank capture rejects a secret Enum table before indexing")
        expectEqual(#history, 2, "a secret Enum table does not update bank history")
        _G.Enum = oldEnum
        secretTables[protectedEnum] = nil
        local oldBankTypes = Enum.BankType
        secretTables[protectedEnum] = true
        Enum.BankType = protectedEnum
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(protectedReads, 0, "automatic bank capture rejects a secret BankType table before indexing")
        Enum.BankType = oldBankTypes
        secretTables[protectedEnum] = nil
        local savedBank = MclarionWowData.bank
        MclarionWowData.bank = "unsupported"
        captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
        expectEqual(MclarionWowData.bank, "unsupported", "invalid bank storage is preserved")
        SlashCmdList.MCLARIONWOWUI()
        local panel
        for _, frame in ipairs(frames) do
            if frame.name == "MclarionWowSettingsFrame" then panel = frame end
        end
        local refused = false
        for _, label in ipairs(panel.fontStrings) do
            if label.text and label.text:find("Bank: Capture unavailable", 1, true) then refused = true end
        end
        expectTrue(refused, "settings report a refused automatic bank snapshot")
        MclarionWowData.bank = savedBank
    end
    C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo = originalSlots, originalInfo
    C_Bank.FetchPurchasedBankTabData, _G.BankFrame = originalTabs, originalBankFrame
end

expectTrue(type(SlashCmdList.MCLARIONWOWUI) == "function", "provides an addon settings window")
if type(SlashCmdList.MCLARIONWOWUI) == "function" then
    SlashCmdList.MCLARIONWOWUI()
    local panel
    for _, frame in ipairs(frames) do
        if frame.name == "MclarionWowSettingsFrame" then panel = frame end
    end
    expectTrue(panel ~= nil and panel:IsShown(), "settings window can be opened in game")
    expectTrue(panel and panel.fontStrings and #panel.fontStrings >= 4,
        "settings window reports bank, item, bag and combat-log status")
    local settings = MclarionWowData.settings
    expectTrue(settings and settings.autoCombatLog and settings.autoCharacterCapture and
        settings.autoBagCapture and settings.autoBankCapture,
        "opted-in automatic capture settings stay enabled")
    local checkboxes = {}
    for _, frame in ipairs(frames) do
        if frame.parent == panel and frame.frameType == "CheckButton" then
            checkboxes[#checkboxes + 1] = frame
        end
    end
    expectEqual(#checkboxes, 5, "settings expose logging, character, bag, bank and item switches")
    if #checkboxes == 5 then
        checkboxes[1]:SetChecked(false)
        checkboxes[1].scripts.OnClick(checkboxes[1])
        expectEqual(settings.autoCombatLog, false, "logging preference persists in saved variables")
        expectEqual(combatLogging, true, "auto-start switch does not silently stop active logging")
        captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
        expectEqual(combatLogging, true, "disabled auto-start leaves running logging unchanged")
        combatLogging = true -- A different addon or the player enabled logging.
        checkboxes[1]:SetChecked(true)
        checkboxes[1].scripts.OnClick(checkboxes[1])
        checkboxes[1]:SetChecked(false)
        checkboxes[1].scripts.OnClick(checkboxes[1])
        expectEqual(combatLogging, true, "disabling auto-start never stops another source's logging")
        local function statusContains(message)
            for _, label in ipairs(panel.fontStrings) do
                if label.text and label.text:find(message, 1, true) then return true end
            end
            return false
        end
        expectTrue(statusContains("still on"), "logging switch reports when another source stays on")
        combatLogging = false
        checkboxes[1]:SetChecked(true)
        checkboxes[1].scripts.OnClick(checkboxes[1])
        checkboxes[2]:SetChecked(false)
        checkboxes[2].scripts.OnClick(checkboxes[2])
        local priorSnapshots = #MclarionWowData.characters["Player-1234-ABCDEF12"]
        captureFrame.scripts.OnEvent(captureFrame, "PLAYER_EQUIPMENT_CHANGED")
        expectEqual(#MclarionWowData.characters["Player-1234-ABCDEF12"], priorSnapshots,
            "disabling character capture suppresses automatic identity snapshots")
        checkboxes[2]:SetChecked(true)
        checkboxes[2].scripts.OnClick(checkboxes[2])
        checkboxes[3]:SetChecked(false)
        checkboxes[3].scripts.OnClick(checkboxes[3])
        local originalBagInfo = C_Container.GetContainerItemInfo
        C_Container.GetContainerItemInfo = function(bag, slot)
            if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 6 } end
        end
        local bagSnapshots = MclarionWowData.bags["Player-1234-ABCDEF12"]
        local count = #bagSnapshots
        captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
        expectEqual(#bagSnapshots, count, "disabled bag capture does not read/store bag changes")
        C_Container.GetContainerItemInfo = originalBagInfo
        checkboxes[3]:SetChecked(true)
        checkboxes[3].scripts.OnClick(checkboxes[3])
        local bagMap = MclarionWowData.bags
        MclarionWowData.bags = "unsupported"
        captureFrame.scripts.OnEvent(captureFrame, "BAG_OPEN", 0)
        expectTrue(statusContains("Bags: Capture unavailable"),
            "settings report rejected automatic bag storage")
        MclarionWowData.bags = bagMap
        local protectedItem = protectedSentinel()
        secretValues[protectedItem] = true
        C_Container.GetContainerItemInfo = function(bag)
            if bag == 0 then return protectedItem end
        end
        captureFrame.scripts.OnEvent(captureFrame, "BAG_OPEN", 0)
        expectTrue(statusContains("Bags: Capture unavailable"),
            "settings report a protected bag scan without exposing item details")
        C_Container.GetContainerItemInfo = originalBagInfo
        secretValues[protectedItem] = nil
        checkboxes[4]:SetChecked(false)
        checkboxes[4].scripts.OnClick(checkboxes[4])
        expectEqual(settings.autoBankCapture, false, "automatic bank preference persists in saved variables")
        checkboxes[4]:SetChecked(true)
        checkboxes[4].scripts.OnClick(checkboxes[4])
    end
    local originalLogging = LoggingCombat
    local guardedLogging = function() error("protected logging API was invoked") end
    secretValues[guardedLogging] = true
    _G.LoggingCombat = guardedLogging
    local safe = pcall(captureFrame.scripts.OnEvent, captureFrame, "PLAYER_ENTERING_WORLD")
    expectTrue(safe, "protected combat-log API is never invoked by the automatic handler")
    _G.LoggingCombat = originalLogging
    secretValues[guardedLogging] = nil
    combatLogging = false
    MclarionWowData.settings.autoCombatLog = true
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
    expectTrue(combatLogging, "opted-in logging starts before a UI reload")
    chunk("MclarionWow", {}) -- Simulate a UI reload while WoW leaves combat logging active.
    local reloadedCapture
    for _, frame in ipairs(frames) do
        if frame.events and frame.events.PLAYER_ENTERING_WORLD then reloadedCapture = frame end
    end
    reloadedCapture.scripts.OnEvent(reloadedCapture, "PLAYER_ENTERING_WORLD")
    SlashCmdList.MCLARIONWOWUI()
    local reloadedPanel
    for _, frame in ipairs(frames) do
        if frame.name == "MclarionWowSettingsFrame" then reloadedPanel = frame end
    end
    local autoStart, stopNow
    for _, frame in ipairs(frames) do
        if frame.parent == reloadedPanel and frame.frameType == "CheckButton" and not autoStart then
            autoStart = frame
        elseif frame.parent == reloadedPanel and frame.frameType == "Button" and
            frame.text == "Stop logging now" then
            stopNow = frame
        end
    end
    autoStart:SetChecked(false)
    autoStart.scripts.OnClick(autoStart)
    expectEqual(combatLogging, true, "switch-off after reload never guesses who started active logging")
    local attributedElsewhere = false
    for _, label in ipairs(reloadedPanel.fontStrings) do
        if label.text and label.text:find("other source", 1, true) then attributedElsewhere = true end
    end
    expectEqual(attributedElsewhere, false, "status never misattributes the logging source after reload")
    expectTrue(stopNow ~= nil, "explicit Stop logging now control survives a UI reload")
    if stopNow then stopNow.scripts.OnClick(stopNow) end
    expectEqual(combatLogging, false, "explicit player action can stop logging after a UI reload")
    expectEqual(MclarionWowData.settings.autoCombatLog, false,
        "explicit stop also disables automatic restart on the next world entry")
end

MclarionWowData = { schema = 1, characters = {}, settings = {
    autoCombatLog = false, autoCharacterCapture = true,
    autoBagCapture = false, autoBankCapture = false } }
local identityFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_EQUIPMENT_CHANGED then identityFrame = frame end
end
identityFrame.scripts.OnEvent(identityFrame, "PLAYER_ENTERING_WORLD")
local identityHistory = MclarionWowData.characters["Player-1234-ABCDEF12"]
expectTrue(type(identityHistory) == "table" and #identityHistory == 1 and
    identityHistory[1]:find("^MHWOW2|forever|") ~= nil,
    "automatic identity snapshot replaces the manual copy command")
identityFrame.scripts.OnEvent(identityFrame, "PLAYER_EQUIPMENT_CHANGED")
expectEqual(#identityHistory, 1, "unchanged automatic identity snapshots deduplicate")
local latestCapture
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_EQUIPMENT_CHANGED then latestCapture = frame end
end
local savedFaction = UnitFactionGroup
_G.UnitFactionGroup = nil
gear[1] = gear[1] + 1
latestCapture.scripts.OnEvent(latestCapture, "PLAYER_EQUIPMENT_CHANGED")
expectTrue(#identityHistory == 2 and identityHistory[2]:find("^MHWOW1|forever|") ~= nil,
    "automatic capture falls back to gear-only format when identity APIs are absent")
_G.UnitFactionGroup = savedFaction
gear[1] = gear[1] + 1
latestCapture.scripts.OnEvent(latestCapture, "PLAYER_EQUIPMENT_CHANGED")
expectTrue(#identityHistory == 3 and identityHistory[3]:find("^MHWOW2|forever|") ~= nil,
    "automatic opt-in capture resumes MHWOW2 when identity APIs are available")

-- Candidate schema-2 SavedVariables flow (not installed until the website reads both schemas).
local itemGuid = "Player-1234-ABCDEF12"
local originalMetadataInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if id == 4242 then return originalMetadataInfo(id) end
    return "Cached " .. id, "link" .. id, 1, 1, 1, "Misc", "Other", 1,
        "", id, 0, 15, 0, 0, 0, nil, false, ""
end
MclarionWowData = { schema = 1, characters = {}, settings = {
    autoCombatLog = false, autoCharacterCapture = false,
    autoBagCapture = false, autoBankCapture = false } }
chunk("MclarionWow", {})
local itemFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.BANKFRAME_OPENED then itemFrame = frame end
end
itemFrame.scripts.OnEvent(itemFrame, "PLAYER_ENTERING_WORLD")
expectEqual(MclarionWowData.schema, 1, "new item metadata capture defaults off without migrating schema")
expectEqual(MclarionWowData.items, nil, "no item metadata is saved without explicit opt-in")
SlashCmdList.MCLARIONWOWUI()
local itemPanel, itemToggle
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowSettingsFrame" then itemPanel = frame end
end
local itemCheckboxes = {}
for _, frame in ipairs(frames) do
    if frame.parent == itemPanel and frame.frameType == "CheckButton" then
        itemCheckboxes[#itemCheckboxes + 1] = frame
    end
end
itemToggle = itemCheckboxes[5]
expectTrue(itemToggle ~= nil and itemToggle:GetChecked() == false,
    "separate item-details consent is exposed and defaults off")
if itemToggle then
    itemToggle:SetChecked(true)
    itemToggle.scripts.OnClick(itemToggle)
end
expectEqual(MclarionWowData.settings.autoItemMetadataCapture, true,
    "item-details opt-in persists in SavedVariables")
itemFrame.scripts.OnEvent(itemFrame, "BAG_UPDATE_DELAYED")
local itemRecord = MclarionWowData.items and MclarionWowData.items[itemGuid]
expectTrue(MclarionWowData.schema == 2 and itemRecord and
    itemRecord.bags and
    itemRecord.bags:find("4242:C38970C3A9657C427269676874:", 1, true) ~= nil,
    "opted-in bag/equipment details migrate schema and save encoded MHWOWI1")
local bagPayload = itemRecord and itemRecord.bags
now = now + 1
itemFrame.scripts.OnEvent(itemFrame, "BAG_UPDATE_DELAYED")
expectEqual(itemRecord and itemRecord.bags, bagPayload,
    "unchanged item details deduplicate despite a new timestamp")
local oldItemSlots, oldItemContainer = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
C_Container.GetContainerNumSlots = function(bag)
    if bag == 6 or bag == 7 then return 1 end
    return oldItemSlots(bag)
end
C_Container.GetContainerItemInfo = function(bag, slot)
    if bag == 6 and slot == 1 then return { itemID = 4242, stackCount = 1 } end
    return oldItemContainer(bag, slot)
end
itemFrame.scripts.OnEvent(itemFrame, "BANKFRAME_OPENED")
itemRecord = MclarionWowData.items[itemGuid]
expectTrue(itemRecord and type(itemRecord.bank) == "table" and
    type(itemRecord.bank[1]) == "string" and itemRecord.bank[1]:find("4242:", 1, true) ~= nil,
    "visible own-bank metadata is stored as bounded bank pages")
local beforeFailedBank = itemRecord and itemRecord.bank
local oldBankView = C_Bank.CanViewBank
C_Bank.CanViewBank = function() return false end
itemFrame.scripts.OnEvent(itemFrame, "BANKFRAME_OPENED")
expectEqual(itemRecord and itemRecord.bank, beforeFailedBank,
    "refused own-bank view leaves previous metadata unchanged")
C_Bank.CanViewBank = oldBankView
local oldPurchasedTabs = C_Bank.FetchPurchasedBankTabData
C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, { ID = 7 } } end
C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 120 or 9 end
C_Container.GetContainerItemInfo = function(tab, slot)
    return { itemID = tab == 6 and slot or 120 + slot, stackCount = 1 }
end
itemFrame.scripts.OnEvent(itemFrame, "BANKFRAME_OPENED")
local twoPages = MclarionWowData.items[itemGuid].bank
expectTrue(#twoPages == 2 and twoPages[2]:find("129:", 1, true) ~= nil,
    "all observed own-bank IDs are stored in two bounded metadata pages")
local cachedForPages = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if id == 129 then return nil end
    return cachedForPages(id)
end
itemFrame.scripts.OnEvent(itemFrame, "BANKFRAME_OPENED")
expectEqual(MclarionWowData.items[itemGuid].bank, twoPages,
    "a partially uncached later bank page does not replace the complete set")
C_Item.GetItemInfo = cachedForPages
C_Container.GetContainerNumSlots = function(tab) return (tab == 6 or tab == 7) and 1 or 0 end
C_Container.GetContainerItemInfo = function(tab, slot)
    if tab == 6 and slot == 1 then return { itemID = 4242, stackCount = 1 } end
end
itemFrame.scripts.OnEvent(itemFrame, "BANKFRAME_OPENED")
expectTrue(#MclarionWowData.items[itemGuid].bank == 1 and
    MclarionWowData.items[itemGuid].bank[2] == nil,
    "successful smaller own-bank scan removes stale metadata pages")
C_Bank.FetchPurchasedBankTabData = oldPurchasedTabs
C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo = oldItemSlots, oldItemContainer
local oldItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if id == 4242 then return nil end
    return oldItemInfo(id)
end
itemFrame.scripts.OnEvent(itemFrame, "BAG_UPDATE_DELAYED")
expectEqual(MclarionWowData.items[itemGuid].bags, bagPayload,
    "partially uncached names do not erase previously saved item details")
C_Item.GetItemInfo = oldItemInfo
chunk("MclarionWow", {})
local reloadedItems
for _, frame in ipairs(frames) do
    if frame.events and frame.events.BANKFRAME_OPENED then reloadedItems = frame end
end
reloadedItems.scripts.OnEvent(reloadedItems, "PLAYER_ENTERING_WORLD")
expectTrue(MclarionWowData.schema == 2 and MclarionWowData.items[itemGuid].bags == bagPayload and
    MclarionWowData.settings.autoItemMetadataCapture == true,
    "schema-2 item records and consent survive a simulated UI reload")
local intact = MclarionWowData.items[itemGuid]
local badWire = { bags = "MHWOWI1|forever|1720000000|" .. itemGuid ..
    "|70170|enUS|not-an-item", bank = intact.bank }
MclarionWowData.items[itemGuid] = badWire
reloadedItems.scripts.OnEvent(reloadedItems, "BAG_UPDATE_DELAYED")
expectEqual(MclarionWowData.items[itemGuid], badWire,
    "malformed existing item wire records refuse replacement")
MclarionWowData.items[itemGuid] = intact
MclarionWowData.items[itemGuid] = { bags = intact.bags, bank = intact.bank,
    unsupported = "must not silently disappear" }
local malformed = MclarionWowData.items[itemGuid]
reloadedItems.scripts.OnEvent(reloadedItems, "BAG_UPDATE_DELAYED")
expectEqual(MclarionWowData.items[itemGuid], malformed,
    "unknown existing item fields fail closed without overwriting the saved record")
MclarionWowData.items[itemGuid] = intact
local protectedItemRecord = protectedSentinel()
secretValues[protectedItemRecord] = true
MclarionWowData.items[itemGuid] = protectedItemRecord
reloadedItems.scripts.OnEvent(reloadedItems, "BAG_UPDATE_DELAYED")
expectEqual(MclarionWowData.items[itemGuid], protectedItemRecord,
    "protected item records are never overwritten")
secretValues[protectedItemRecord] = nil
MclarionWowData.items[itemGuid] = intact
C_Item.GetItemInfo = function() return nil end
reloadedItems.scripts.OnEvent(reloadedItems, "BAG_UPDATE_DELAYED")
expectEqual(MclarionWowData.items[itemGuid], intact,
    "uncached item metadata leaves a valid schema-2 record untouched")

local previousMinimap = Minimap
Minimap = nil
local buttonCount = 0
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowMinimapButton" then buttonCount = buttonCount + 1 end
end
chunk("MclarionWow", {})
local afterCount = 0
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowMinimapButton" then afterCount = afterCount + 1 end
end
expectEqual(afterCount, buttonCount, "missing minimap does not prevent addon loading")
expectTrue(type(SlashCmdList.MCLARIONWOWUI) == "function", "slash UI works without a minimap")
Minimap = previousMinimap
C_Item.GetItemInfo = originalMetadataInfo

-- Capture-now buttons reuse the opted-in, bounded event paths without copy UI.
MclarionWowData = { schema = 1, characters = {}, settings = {
    autoCombatLog = false, autoCharacterCapture = true, autoBagCapture = true,
    autoBankCapture = true, autoItemMetadataCapture = true,
} }
chunk("MclarionWow", {})
local actionFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_ENTERING_WORLD then actionFrame = frame end
end
actionFrame.scripts.OnEvent(actionFrame, "PLAYER_ENTERING_WORLD")
SlashCmdList.MCLARIONWOWUI()
local actionPanel, actions
actions = {}
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowSettingsFrame" then actionPanel = frame end
end
for _, frame in ipairs(frames) do
    if frame.parent == actionPanel and frame.frameType == "Button" then actions[frame.text] = frame end
end
local function visibleStatus(text)
    for _, label in ipairs(actionPanel.fontStrings) do
        if label.text and label.text:find(text, 1, true) then return true end
    end
    return false
end
expectTrue(visibleStatus("Items now: bags + gear; Bank now: bank items if enabled."),
    "settings explain which capture-now button updates each item source")
expectTrue(visibleStatus("Auto-capture works with this window closed"),
    "settings explain that the addon window need not remain open")
local actionGuid = "Player-1234-ABCDEF12"
local bagInfoBeforeAction = C_Container.GetContainerItemInfo
local oldBagCount = #MclarionWowData.bags[actionGuid]
C_Container.GetContainerItemInfo = function(bag, slot)
    if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 12 } end
end
actions["Bags now"].scripts.OnClick(actions["Bags now"])
expectEqual(#MclarionWowData.bags[actionGuid], oldBagCount + 1,
    "Bags now captures changed totals without a bag event")
expectTrue(visibleStatus("Bags: Scanned"), "Bags now reports a completed scan")
actionPanel:Hide()
C_Container.GetContainerItemInfo = bagInfoBeforeAction
local countWithoutMenu = #MclarionWowData.bags[actionGuid]
actionFrame.scripts.OnEvent(actionFrame, "BAG_UPDATE_DELAYED")
expectEqual(#MclarionWowData.bags[actionGuid], countWithoutMenu + 1,
    "bag changes capture automatically while the addon window is closed")
actionFrame.scripts.OnEvent(actionFrame, "BAG_UPDATE_DELAYED")
expectEqual(#MclarionWowData.bags[actionGuid], countWithoutMenu + 1,
    "sorting unchanged bag totals adds no duplicate history")
local beforeEmptyBag = #MclarionWowData.bags[actionGuid]
C_Container.GetContainerItemInfo = function() return nil end
actionFrame.scripts.OnEvent(actionFrame, "BAG_UPDATE_DELAYED")
expectEqual(#MclarionWowData.bags[actionGuid], beforeEmptyBag,
    "transient all-nil bag results cannot replace a populated snapshot automatically")
actionPanel:Show()
expectTrue(visibleStatus("Bags: Empty result refused"),
    "bag status explains an automatic empty-result refusal")
actions["Bags now"].scripts.OnClick(actions["Bags now"])
expectEqual(#MclarionWowData.bags[actionGuid], beforeEmptyBag + 1,
    "explicit Bags now can confirm a genuinely empty inventory")
C_Container.GetContainerItemInfo = bagInfoBeforeAction
MclarionWowData.settings.autoBagCapture = false
local countWhileDisabled = #MclarionWowData.bags[actionGuid]
actions["Bags now"].scripts.OnClick(actions["Bags now"])
expectEqual(#MclarionWowData.bags[actionGuid], countWhileDisabled,
    "Bags now respects the disabled bag capture setting")
expectTrue(visibleStatus("Bags: Enable the matching checkbox"),
    "manual capture explains the required opt-in")
MclarionWowData.settings.autoBagCapture = true
local oldCharacterCount = #MclarionWowData.characters[actionGuid]
gear[1] = gear[1] + 1
actions["Character now"].scripts.OnClick(actions["Character now"])
expectEqual(#MclarionWowData.characters[actionGuid], oldCharacterCount + 1,
    "Character now captures a changed equipment state without an equipment event")
expectTrue(visibleStatus("Character: Scanned"), "Character now reports a completed scan")
local bankTypeBeforeAction = BankFrame.bankType
BankFrame.bankType = 2
local bankBeforeAction = MclarionWowData.bank and MclarionWowData.bank[actionGuid]
actions["Bank now"].scripts.OnClick(actions["Bank now"])
expectEqual(MclarionWowData.bank and MclarionWowData.bank[actionGuid], bankBeforeAction,
    "Bank now never scans the account-bank view")
expectTrue(visibleStatus("Bank: Select your character-bank tab"),
    "Bank now explains the required active character-bank view")
BankFrame.bankType = bankTypeBeforeAction
local slotsBeforeBankAction = C_Container.GetContainerNumSlots
local infoBeforeBankAction = C_Container.GetContainerItemInfo
C_Container.GetContainerNumSlots = function(tab)
    if tab == 6 or tab == 7 then return 1 end
    return slotsBeforeBankAction(tab)
end
C_Container.GetContainerItemInfo = function(tab, slot)
    if tab == 6 and slot == 1 then return { itemID = 4242, stackCount = 1 } end
    return infoBeforeBankAction(tab, slot)
end
actions["Bank now"].scripts.OnClick(actions["Bank now"])
local capturedBank = MclarionWowData.bank and MclarionWowData.bank[actionGuid]
expectTrue(capturedBank and #capturedBank == 1 and visibleStatus("Bank: Scanned"),
    "Bank now captures own-bank totals once the character-bank view is active")
local beforeEmptyBank = #capturedBank
C_Container.GetContainerItemInfo = function() return nil end
actionFrame.scripts.OnEvent(actionFrame, "BANKFRAME_OPENED")
expectEqual(#capturedBank, beforeEmptyBank,
    "transient all-nil bank results cannot replace a populated snapshot automatically")
expectTrue(visibleStatus("Bank: Empty result refused"),
    "bank status explains an automatic empty-result refusal")
actions["Bank now"].scripts.OnClick(actions["Bank now"])
expectEqual(#capturedBank, beforeEmptyBank + 1,
    "explicit Bank now can confirm a genuinely empty character bank")
C_Container.GetContainerItemInfo = function(tab, slot)
    if tab == 6 and slot == 1 then return { itemID = 4242, stackCount = 1 } end
    return infoBeforeBankAction(tab, slot)
end
MclarionWowData.settings.autoBankCapture = false
MclarionWowData.items[actionGuid] = nil
actions["Bank now"].scripts.OnClick(actions["Bank now"])
local refreshedItemRecord = MclarionWowData.items and MclarionWowData.items[actionGuid]
expectTrue(refreshedItemRecord and refreshedItemRecord.bank and #refreshedItemRecord.bank == 1,
    "Bank now can update separately opted-in bank item details without bank totals opt-in")
expectTrue(visibleStatus("Bank: Bank totals off; item details only."),
    "Bank now explains why numeric bank totals were not captured")
MclarionWowData.settings.autoBankCapture = true
C_Container.GetContainerNumSlots = slotsBeforeBankAction
C_Container.GetContainerItemInfo = infoBeforeBankAction
local itemInfoBeforeAction = C_Item.GetItemInfo
C_Item.GetItemInfo = function() return nil end
actions["Items now"].scripts.OnClick(actions["Items now"])
expectTrue(visibleStatus("Items: Cache incomplete"),
    "Items now explains why uncached items did not replace previous metadata")
C_Item.GetItemInfo = itemInfoBeforeAction
local combatBeforeAction = InCombatLockdown
_G.InCombatLockdown = function() error("client refused combat status") end
local safeButton = pcall(actions["Bags now"].scripts.OnClick, actions["Bags now"])
expectTrue(safeButton and visibleStatus("Bags: Capture unavailable: client refused requested scan"),
    "capture-now button contains a client API refusal and reports it without a Lua error")
_G.InCombatLockdown = combatBeforeAction

if failures > 0 then
    io.stderr:write(string.format("\n%d/%d assertions failed\n", failures, tests))
    os.exit(1)
end
io.stdout:write(string.format("\nAll %d assertions passed\n", tests))
