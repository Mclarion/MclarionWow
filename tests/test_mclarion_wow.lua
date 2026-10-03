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
    expectTrue(type(SlashCmdList.MCLARIONWOWBANKPROBE) == "function", "registers manual bank probe command")
    SlashCmdList.MCLARIONWOWBANKPROBE()
    local bankBox, bankWindow
    for _, frame in ipairs(frames) do
        if frame.frameType == "EditBox" then bankBox = frame end
        if frame.name == "MclarionWowExportFrame" then bankWindow = frame end
    end
    expectTrue(bankBox and bankWindow and bankWindow.shown and bankBox.focused and bankBox.highlighted,
        "bank count report opens a selectable popup")
    expectEqual(bankBox and bankBox:GetText(), report, "bank popup contains only the count report")
    expectTrue(bankWindow and bankWindow.fontStrings[1].text:find("Bank diagnostic", 1, true) ~= nil,
        "bank popup identifies the count-only diagnostic")
    expectTrue(sameData(MclarionWowData, expectedStorage), "bank popup leaves nested saved data unchanged")
    bankWindow:Hide()
    SlashCmdList.MCLARIONWOWBANKPROBE()
    expectTrue(bankWindow.shown, "a second manual bank probe reopens a hidden copy-data popup")
    inCombat = true
    report, problem = MclarionWow_ProbeBank()
    expectTrue(report == nil and problem:find("combat", 1, true) ~= nil, "bank probe refuses combat")
    SlashCmdList.MCLARIONWOWBANKPROBE()
    expectTrue(bankBox and bankBox:GetText():find("unavailable", 1, true) ~= nil,
        "bank popup shows a refusal rather than stale counts during combat")
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

    C_Container.GetContainerNumSlots = function() return 0 end
    C_Container.GetContainerItemInfo = function() error("empty tabs must not read item slots") end
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
    C_Container.GetContainerNumSlots = function() return 0 end
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

    expectEqual(SLASH_MCLARIONWOWBANKSEXPORT1, "/mhwowbanksexport",
        "registers the exact bank export slash command")
    expectTrue(type(SlashCmdList.MCLARIONWOWBANKSEXPORT) == "function",
        "registers the manual-only character-bank export command")
    C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 } } end
    C_Container.GetContainerNumSlots = function() return 1 end
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = 3 } end
    SlashCmdList.MCLARIONWOWBANKSEXPORT()
    local bankBox, bankWindow
    for _, frame in ipairs(frames) do
        if frame.frameType == "EditBox" then bankBox = frame end
        if frame.name == "MclarionWowExportFrame" then bankWindow = frame end
    end
    expectEqual(bankBox and bankBox:GetText(),
        "MHWOWK1|forever|1720000000|Player-1234-ABCDEF12|6:4242:3|70170",
        "manual bank command shows the exact selectable export")
    expectTrue(bankWindow and bankWindow.shown and bankBox.focused and bankBox.highlighted,
        "manual bank export opens and selects the copy box")
    expectTrue(bankWindow and bankWindow.fontStrings[1].text:find("Bank item export", 1, true) ~= nil,
        "bank item export is clearly distinguished from the count-only diagnostic")
    expectTrue(sameData(MclarionWowData, expectedStorage),
        "manual bank export never writes SavedVariables")
    inCombat = true
    SlashCmdList.MCLARIONWOWBANKSEXPORT()
    expectTrue(bankBox and bankBox:GetText():find("unavailable", 1, true) ~= nil and
        bankBox:GetText():find("MHWOWK1", 1, true) == nil,
        "manual bank command replaces stale export text with combat refusal")
    inCombat = false

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

    expectEqual(SLASH_MCLARIONWOWBANKITEMSEXPORT1, "/mhwowbankitemsexport",
        "registers the exact manual bank metadata command")
    expectTrue(type(SlashCmdList.MCLARIONWOWBANKITEMSEXPORT) == "function",
        "registers the manual-only bank metadata handler")
    C_Item.GetItemInfo = oldItemInfo
    C_Container.GetContainerNumSlots = function() return 1 end
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = 1 } end
    SlashCmdList.MCLARIONWOWBANKITEMSEXPORT("")
    local bankBox, bankWindow
    for _, frame in ipairs(frames) do
        if frame.frameType == "EditBox" then bankBox = frame end
        if frame.name == "MclarionWowExportFrame" then bankWindow = frame end
    end
    expectTrue(bankBox and bankBox:GetText():find("MHWOWI1|forever|", 1, true) == 1,
        "manual bank metadata command shows a selectable MHWOWI1 export")
    C_Bank.CanViewBank = function() return false end
    SlashCmdList.MCLARIONWOWBANKITEMSEXPORT("")
    expectTrue(bankBox and bankBox:GetText():find("unavailable", 1, true) ~= nil and
        bankBox:GetText():find("MHWOWI1", 1, true) == nil,
        "closed-bank refusal replaces stale bank metadata text")
    expectTrue(bankWindow and bankWindow.fontStrings[1].text:find("Bank item metadata", 1, true) ~= nil,
        "bank metadata popup is clearly identified")
    expectTrue(sameData(MclarionWowData, expectedStorage),
        "manual bank metadata handler leaves SavedVariables unchanged")

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

expectTrue(type(SLASH_MCLARIONWOW1) == "string", "registers a slash command")
expectTrue(type(SlashCmdList.MCLARIONWOW) == "function", "slash command handler exists")
SlashCmdList.MCLARIONWOW()
local editBox
for _, frame in ipairs(frames) do
    if frame.frameType == "EditBox" then editBox = frame end
end
local function latestExportText()
    for index = #frames, 1, -1 do
        if frames[index].frameType == "EditBox" then return frames[index]:GetText() or "" end
    end
    return ""
end
expectTrue(editBox ~= nil and editBox.shown, "slash command shows selectable edit box")
expectEqual(editBox:GetText(), expected, "slash command populates current export")
expectTrue(editBox.highlighted, "slash command selects export for manual copy")
editBox:SetText("corrupted by an accidental keypress")
expectTrue(type(editBox.scripts.OnTextChanged) == "function",
    "export popup guards against accidental edits")
if type(editBox.scripts.OnTextChanged) == "function" then
    editBox.scripts.OnTextChanged(editBox, true)
    expectEqual(editBox:GetText(), expected, "popup restores the original export when typing replaces selection")
    now = now + 1
    SlashCmdList.MCLARIONWOW()
    local refreshed = editBox:GetText()
    expectTrue(refreshed ~= expected, "manual re-export replaces the popup with a fresh snapshot")
    editBox:SetText("accidental edit after re-export")
    editBox.scripts.OnTextChanged(editBox, true)
    expectEqual(editBox:GetText(), refreshed, "popup restores the latest export rather than stale text")
    now = now - 1
    SlashCmdList.MCLARIONWOW()
end
for _, frame in ipairs(frames) do
    if frame.name == "MclarionWowExportFrame" then
        expectTrue(frame.fontStrings[1].text:find("manual snapshot export", 1, true) ~= nil,
            "character export restores the popup title after a bank diagnostic")
    end
end

local saved = MclarionWowData
expectTrue(type(saved) == "table" and saved.schema == 1 and
    type(saved.characters) == "table" and
    type(saved.characters["Player-1234-ABCDEF12"]) == "table", "slash command saves a character snapshot locally")
if type(saved) == "table" and type(saved.characters) == "table" and
    type(saved.characters["Player-1234-ABCDEF12"]) == "table" then
    local snapshots = saved.characters["Player-1234-ABCDEF12"]
    expectEqual(snapshots[1], expected, "stored snapshot is the reviewed export")
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 1, "repeating an unchanged snapshot does not grow local storage")
    for _ = 1, 22 do
        now = now + 1
        gear[1] = gear[1] + 1
        SlashCmdList.MCLARIONWOW()
    end
    expectEqual(#snapshots, 20, "each character retains at most twenty snapshots")
    expectTrue(snapshots[1]:find("|" .. tostring(now - 19) .. "|", 1, true) ~= nil,
        "oldest local snapshots are pruned")
    chunk("MclarionWow", {})
    expectTrue(MclarionWowData == saved, "saved data survives addon reload")
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 20, "reloaded addon deduplicates current snapshot")
    inCombat = true
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 20, "combat does not store data")
    inCombat = false
    MclarionWowData = { schema = 2, characters = {} }
    local unsupported = MclarionWowData
    SlashCmdList.MCLARIONWOW()
    expectTrue(MclarionWowData == unsupported, "unknown storage schema is not overwritten")
    local touchedCharacterStorage = false
    local protectedStorage = setmetatable({}, { __index = function()
        touchedCharacterStorage = true
        error("protected character storage was indexed")
    end })
    secretTables[protectedStorage] = true
    MclarionWowData = protectedStorage
    local clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture rejects protected saved data before indexing")
    expectEqual(MclarionWowData, protectedStorage, "character capture preserves protected storage")
    secretTables[protectedStorage] = nil
    MclarionWowData = saved
    local originalCharacters = saved.characters
    saved.characters = protectedStorage
    secretTables[protectedStorage] = true
    touchedCharacterStorage = false
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture rejects protected character map before indexing")
    saved.characters = originalCharacters
    secretTables[protectedStorage] = nil
    local previousHistory = originalCharacters["Player-1234-ABCDEF12"]
    local protectedHistory = setmetatable({}, { __len = function()
        touchedCharacterStorage = true
        error("protected character history length was read")
    end })
    originalCharacters["Player-1234-ABCDEF12"] = protectedHistory
    secretTables[protectedHistory] = true
    touchedCharacterStorage = false
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture refuses protected history before reading length")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
    secretTables[protectedHistory] = nil
    local malformedHistory = setmetatable({}, { __len = function()
        error("malformed character history")
    end })
    originalCharacters["Player-1234-ABCDEF12"] = malformedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "manual character export contains unexpected storage errors")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
    local previousEntry = previousHistory[#previousHistory]
    local protectedEntry = protectedSentinel()
    secretValues[protectedEntry] = true
    previousHistory[#previousHistory] = protectedEntry
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("protected", 1, true) ~= nil,
        "character capture refuses protected history entries")
    previousHistory[#previousHistory] = previousEntry
    secretValues[protectedEntry] = nil
    local previousSchema = saved.schema
    local protectedSchema = protectedSentinel()
    secretValues[protectedSchema] = true
    saved.schema = protectedSchema
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("protected", 1, true) ~= nil,
        "character capture checks protected storage schema before comparing")
    saved.schema = previousSchema
    secretValues[protectedSchema] = nil
    local oversizedHistory = {}
    for index = 1, 21 do oversizedHistory[index] = expected end
    originalCharacters["Player-1234-ABCDEF12"] = oversizedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and #oversizedHistory == 21 and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "oversized pre-existing character history is left unchanged")
    local extraKeyHistory = { expected, unexpected = expected }
    originalCharacters["Player-1234-ABCDEF12"] = extraKeyHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and #extraKeyHistory == 1 and extraKeyHistory[2] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "character history with an extra key is rejected unchanged")
    local sparseHistory = { [1] = expected, [3] = expected }
    originalCharacters["Player-1234-ABCDEF12"] = sparseHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and sparseHistory[2] == nil and sparseHistory[4] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "sparse character history is rejected unchanged")
    local interiorHole = { [1] = expected, [2] = expected, [4] = expected }
    originalCharacters["Player-1234-ABCDEF12"] = interiorHole
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and interiorHole[3] == nil and interiorHole[5] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "interior character-history hole is rejected unchanged")
    local extraProtectedValue = protectedSentinel()
    secretValues[extraProtectedValue] = true
    local protectedExtraHistory = { expected, unexpected = extraProtectedValue }
    originalCharacters["Player-1234-ABCDEF12"] = protectedExtraHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and protectedExtraHistory[2] == nil and
        latestExportText():find("protected", 1, true) ~= nil,
        "protected extra character-history entry is checked before use")
    secretValues[extraProtectedValue] = nil
    local cappedHistory = {}
    for index = 1, 20 do cappedHistory[index] = expected end
    cappedHistory.unexpected = expected
    originalCharacters["Player-1234-ABCDEF12"] = cappedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and cappedHistory[20] == expected and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "full character history with an extra key cannot rotate")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
end

expectTrue(type(SlashCmdList.MCLARIONWOWBAGSEXPORT) == "function",
    "registers a manual bag export command")
if type(SlashCmdList.MCLARIONWOWBAGSEXPORT) == "function" then
    local bagExport = MclarionWow_BuildBagExport()
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    local bagEditBox
    for _, frame in ipairs(frames) do
        if frame.frameType == "EditBox" then bagEditBox = frame end
    end
    expectEqual(bagEditBox:GetText(), bagExport, "manual bag export is selectable for player review")
    local bagHistory = MclarionWowData.bags["Player-1234-ABCDEF12"]
    expectEqual(bagHistory[1], bagExport, "reviewed bag export is saved locally")
    now = now + 1
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(#bagHistory, 1, "unchanged bag totals do not fill history")
    expectEqual(#MclarionWowData.characters["Player-1234-ABCDEF12"], 20,
        "bag capture does not change gear history")
    local originalBagInfo = C_Container.GetContainerItemInfo
    for index = 1, 22 do
        now = now + 1
        C_Container.GetContainerItemInfo = function(bag, slot)
            if bag == 0 and slot == 1 then
                return { itemID = 4242, stackCount = 3 + index }
            end
        end
        SlashCmdList.MCLARIONWOWBAGSEXPORT()
    end
    C_Container.GetContainerItemInfo = originalBagInfo
    expectEqual(#bagHistory, 20, "bag history retains at most twenty distinct states")
    expectTrue(bagHistory[1]:find("|4242:6|", 1, true) ~= nil,
        "bag history drops the oldest inventory states")
    local latestBag = bagHistory[#bagHistory]
    local secretItem = protectedSentinel()
    secretValues[secretItem] = true
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = secretItem, stackCount = 3 } end
    end
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(bagHistory[#bagHistory], latestBag, "secret bag item never enters local history")
    expectTrue(not bagEditBox:GetText():find("MHWOWB1", 1, true),
        "secret bag item never enters the copy window")
    C_Container.GetContainerItemInfo = originalBagInfo
    secretValues[secretItem] = nil
    inCombat = true
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(bagHistory[#bagHistory], latestBag, "combat cannot store a bag snapshot")
    inCombat = false
    local priorStorage = MclarionWowData
    local unknownStorage = { schema = 99, characters = {}, bags = {} }
    MclarionWowData = unknownStorage
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(MclarionWowData, unknownStorage, "unknown bag storage schema is not replaced")
    expectEqual(next(unknownStorage.bags), nil, "unknown bag storage schema is not written")
    MclarionWowData = priorStorage
    local touchedProtectedStorage = false
    local protectedStorage = setmetatable({}, { __index = function()
        touchedProtectedStorage = true
        error("protected storage was indexed")
    end })
    secretTables[protectedStorage] = true
    MclarionWowData = protectedStorage
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedStorage, false, "protected saved data is rejected before indexing")
    expectEqual(MclarionWowData, protectedStorage, "protected saved data is not overwritten")
    MclarionWowData = priorStorage
    secretTables[protectedStorage] = nil
    local previousBagMap = priorStorage.bags
    local touchedProtectedBags = false
    local protectedBags = setmetatable({}, { __index = function()
        touchedProtectedBags = true
        error("protected bag map was indexed")
    end })
    secretTables[protectedBags] = true
    priorStorage.bags = protectedBags
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedBags, false, "protected bag map is rejected before indexing")
    expectEqual(priorStorage.bags, protectedBags, "protected bag map is not overwritten")
    priorStorage.bags = previousBagMap
    secretTables[protectedBags] = nil
    local priorHistory = previousBagMap["Player-1234-ABCDEF12"]
    local touchedProtectedHistory = false
    local protectedHistory = setmetatable({}, { __len = function()
        touchedProtectedHistory = true
        error("protected bag history length was read")
    end })
    secretTables[protectedHistory] = true
    previousBagMap["Player-1234-ABCDEF12"] = protectedHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedHistory, false, "protected history is rejected before reading it")
    expectEqual(previousBagMap["Player-1234-ABCDEF12"], protectedHistory,
        "protected bag history is not overwritten")
    previousBagMap["Player-1234-ABCDEF12"] = priorHistory
    secretTables[protectedHistory] = nil
    local previousBagEntry = priorHistory[#priorHistory]
    local protectedBagEntry = protectedSentinel()
    secretValues[protectedBagEntry] = true
    priorHistory[#priorHistory] = protectedBagEntry
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(latestExportText():find("protected", 1, true) ~= nil,
        "bag capture checks protected history entries before use")
    priorHistory[#priorHistory] = previousBagEntry
    secretValues[protectedBagEntry] = nil
    local oversizedBagHistory = {}
    for index = 1, 21 do oversizedBagHistory[index] = previousBagEntry end
    previousBagMap["Player-1234-ABCDEF12"] = oversizedBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(#oversizedBagHistory == 21 and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "oversized pre-existing bag history is left unchanged")
    local extraKeyBagHistory = { previousBagEntry, unexpected = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = extraKeyBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(#extraKeyBagHistory == 1 and extraKeyBagHistory[2] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "bag history with an extra key is rejected unchanged")
    local sparseBagHistory = { [1] = previousBagEntry, [3] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = sparseBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(sparseBagHistory[2] == nil and sparseBagHistory[4] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "sparse bag history is rejected unchanged")
    local bagInteriorHole = { [1] = previousBagEntry, [2] = previousBagEntry,
        [4] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = bagInteriorHole
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(bagInteriorHole[3] == nil and bagInteriorHole[5] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "interior bag-history hole is rejected unchanged")
    local protectedBagKey = protectedSentinel()
    secretValues[protectedBagKey] = true
    local protectedKeyHistory = { [1] = previousBagEntry, [protectedBagKey] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = protectedKeyHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(protectedKeyHistory[2] == nil and
        latestExportText():find("protected", 1, true) ~= nil,
        "protected extra bag-history key is checked before comparing")
    secretValues[protectedBagKey] = nil
    previousBagMap["Player-1234-ABCDEF12"] = priorHistory
end

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
    C_Container.GetContainerNumSlots = function(tab) return tab == 6 and 1 or 0 end
    C_Container.GetContainerItemInfo = function(tab)
        if tab == 6 then return { itemID = 4242, stackCount = 3 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BANKFRAME_OPENED")
    local history = MclarionWowData.bank and MclarionWowData.bank["Player-1234-ABCDEF12"]
    expectTrue(history and #history == 1 and
        history[1]:find("|6:4242:3|", 1, true) ~= nil,
        "opening own bank stores bounded character-bank totals in memory")
    if history then
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
        "settings window reports export, bank, and combat-log status")
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
    expectEqual(#checkboxes, 4, "settings expose logging, character, bag and bank switches")
    if #checkboxes == 4 then
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
        SlashCmdList.MCLARIONWOWBAGSEXPORT()
        expectTrue(statusContains("Bags snapshot stored in memory"),
            "manual bag export status distinguishes SavedVariables from a TXT file")
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

if failures > 0 then
    io.stderr:write(string.format("\n%d/%d assertions failed\n", failures, tests))
    os.exit(1)
end
io.stdout:write(string.format("\nAll %d assertions passed\n", tests))
