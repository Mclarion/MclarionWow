-- Generate a synthetic schema-2 SavedVariables fixture from the actual addon
-- builders and the mock-game test suite. Never use a real game save as input.
local addonPath, destination = ...
assert(type(addonPath) == "string" and type(destination) == "string",
    "usage: lua tests/generate_schema2_fixture.lua MclarionWow.lua <output>")
assert(loadfile("tests/test_mclarion_wow.lua"))(addonPath)

local guid = UnitGUID("player")
assert(guid == "Player-1234-ABCDEF12", "only the fixed synthetic character is supported")
local character = assert(MclarionWow_BuildIdentityExport())
local bags = assert(MclarionWow_BuildBagExport())

-- Exercise the real bank builder's pagination with 129 synthetic IDs.
local getSlots, getItem = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
local getMetadata = C_Item.GetItemInfo
C_Container.GetContainerNumSlots = function(tab)
    if tab == 6 then return 120 end
    if tab == 7 then return 9 end
    return getSlots(tab)
end
C_Container.GetContainerItemInfo = function(tab, slot)
    if tab == 6 or tab == 7 then
        return { itemID = tab == 6 and slot or 120 + slot, stackCount = 1 }
    end
    return getItem(tab, slot)
end
C_Item.GetItemInfo = function(id)
    return "Synthetic " .. id, "link" .. id, 1, 1, 1, "Misc", "Other", 1,
        "", id, 0, 15, 0, 0, 0, nil, false, ""
end
local bank = assert(MclarionWow_BuildBankExport())
local bankItem, _, bankGuid, page, pages = MclarionWow_BuildBankItemExport(1)
local bankItem2, _, secondGuid, secondPage, secondPages = MclarionWow_BuildBankItemExport(2)
assert(bankItem and bankItem2 and bankGuid == guid and secondGuid == guid and
    page == 1 and secondPage == 2 and pages == 2 and secondPages == 2)
C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo = getSlots, getItem
C_Item.GetItemInfo = getMetadata

local details = assert(MclarionWowData.items[guid])
assert(type(details.bags) == "string" and details.bags:find("^MHWOWI1|forever|"))
assert(type(bankItem) == "string" and bankItem:find("^MHWOWI1|forever|"))
assert(type(bankItem2) == "string" and bankItem2:find("^MHWOWI1|forever|"))
local quote = function(s) return string.format("%q", s) end
local lines = {
    "MclarionWowData = {",
    "    [\"schema\"] = 2,",
    "    [\"settings\"] = {",
    "        [\"autoCombatLog\"] = false,",
    "        [\"autoCharacterCapture\"] = true,",
    "        [\"autoBagCapture\"] = true,",
    "        [\"autoBankCapture\"] = true,",
    "        [\"autoItemMetadataCapture\"] = true,",
    "    },",
    "    [\"characters\"] = { [" .. quote(guid) .. "] = { " .. quote(character) .. " } },",
    "    [\"bags\"] = { [" .. quote(guid) .. "] = { " .. quote(bags) .. " } },",
    "    [\"bank\"] = { [" .. quote(guid) .. "] = { " .. quote(bank) .. " } },",
    "    [\"items\"] = {",
    "        [" .. quote(guid) .. "] = {",
    "            [\"bags\"] = " .. quote(details.bags) .. ",",
    "            [\"bank\"] = { " .. quote(bankItem) .. ", " .. quote(bankItem2) .. " },",
    "        },",
    "    },",
    "}",
}
local text = table.concat(lines, "\n") .. "\n"
assert(#text < 4 * 1024 * 1024, "synthetic fixture exceeds the website file limit")
local file = assert(io.open(destination, "wb"))
assert(file:write(text))
assert(file:close())
print("synthetic schema-2 fixture bytes:", #text)
