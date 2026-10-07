-- Builder-only fake game for schema-2 fixture generation. No UI/event tests,
-- persistent character data or player saves are inputs to this mock.
local addonPath = assert(...)
_G = _G or _ENV
_G.issecretvalue = function() return false end
_G.issecrettable = function() return false end
_G.InCombatLockdown = function() return false end
_G.GetServerTime = function() return 1720000348 end
_G.UnitGUID = function(unit) assert(unit == "player"); return "Player-1234-ABCDEF12" end
_G.UnitName = function(unit) assert(unit == "player"); return "Name|Percent%" end
_G.GetRealmName = function() return "Realm|One%" end
_G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
_G.UnitLevel = function() return 80 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.UnitRace = function() return "Dwarf", "Dwarf" end
_G.UnitSex = function() return 2 end
_G.C_Map = { GetBestMapForUnit = function() return 2339 end }
_G.GetZoneText = function() return "Dornogal|Core" end
_G.GetInventoryItemID = function(unit, slot)
    assert(unit == "player" and slot >= 1 and slot <= 19)
    return slot == 1 and 9004 or 1000 + slot
end
_G.GetBuildInfo = function() return "1.60.1", "70170", "Oct 1 2026", 16001 end
_G.GetLocale = function() return "enUS" end
_G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 3 } end
    end,
}
_G.Enum = { BankType = { Character = 1 } }
_G.BankFrame = {
    IsShown = function() return true end,
    GetActiveBankType = function() return 1 end,
}
_G.C_Bank = {
    AreAnyBankTypesViewable = function() return true end,
    CanViewBank = function(bankType) assert(bankType == 1); return true end,
    FetchPurchasedBankTabData = function(bankType)
        assert(bankType == 1)
        return { { ID = 6 }, { ID = 7 } }
    end,
}
_G.C_Item = { GetItemInfo = function() return nil end }
_G.SlashCmdList = {}
_G.UIParent = {}
_G.Minimap = nil
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end
assert(loadfile(addonPath))("MclarionWow", {})
