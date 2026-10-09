local function load(path)
 local chunk=assert(loadfile(path)); if setfenv then setfenv(chunk,_G) end; chunk()
end
issecretvalue=function(v) return type(v)=="table" and v.protected==true end
issecrettable=function(v) return v.protected==true end
local owner="Player-1-ABCDEF12"
InCombatLockdown=function() return false end
UnitGUID=function() return owner end
GetLocale=function() return "enUS" end
C_Reputation={GetFactionDataByID=function(id) return {factionID=id,name="|cffff0000Guild",description="Description"} end}
C_CurrencyInfo={GetCurrencyInfo=function(id) return {currencyID=id,name="Badge",description="Earned",iconFileID=0,quality=0,quantity=42,isAccountWide=false} end}
MclarionWow_MetadataStorageBudget=function(root) return true end
load("../VaultkeeperMetadata/MetadataCapture.lua")
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
assert(MclarionWow_EnrichObserved("reputation",{17},owner,100,123))
assert(MclarionWow_EnrichObserved("currency",{18},owner,100,123))
local rep=VaultkeeperMetadataData.records["reputation:17:123:enUS"]
local cur=VaultkeeperMetadataData.records["currency:18:123:enUS"]
equal(rep.name,"|cffff0000Guild");equal(rep.description,"Description")
equal(rep.observedBy,owner);equal(rep.scope,"character")
equal(cur.iconFileID,0);equal(cur.quality,0)
equal(cur.scope,"character");assert(cur.quantity==nil)
local name,desc=MclarionWow_MetadataLabel("reputation",17,123,owner)
equal(name,"|cffff0000Guild");equal(desc,"Description")
C_Reputation.GetFactionDataByID=function() return nil end
assert(MclarionWow_EnrichObserved("reputation",{17},owner,101,123))
equal(VaultkeeperMetadataData.records["reputation:17:123:enUS"].name,rep.name)
C_Reputation.GetFactionDataByID=function(id) return {factionID=id,name="Updated"} end
assert(MclarionWow_EnrichObserved("reputation",{17},owner,102,123))
equal(VaultkeeperMetadataData.records["reputation:17:123:enUS"].name,"Updated")
equal(VaultkeeperMetadataData.records["reputation:17:123:enUS"].description,"Description")
C_Reputation.GetFactionDataByID=function() return {protected=true} end
assert(MclarionWow_EnrichObserved("reputation",{19},owner,102,123))
assert(VaultkeeperMetadataData.records["reputation:19:123:enUS"]==nil)
C_CurrencyInfo.GetCurrencyInfo=function() return {currencyID=18,name="Changed",description="",iconFileID=0,isAccountWide=false} end
MclarionWow_MetadataStorageBudget=function() return false end
assert(not MclarionWow_EnrichObserved("currency",{18},owner,103,123))
equal(VaultkeeperMetadataData.records["currency:18:123:enUS"].name,"Badge")
MclarionWow_MetadataStorageBudget=function() return true end
assert(MclarionWow_EnrichObserved("currency",{18},owner,103,123))
equal(VaultkeeperMetadataData.records["currency:18:123:enUS"].name,"Changed")
equal(VaultkeeperMetadataData.records["currency:18:123:enUS"].description,"Earned")
assert(not MclarionWow_EnrichObserved("currency",{18,18},owner,104,123))
-- A callback may not mutate either the proposed graph or previously stored records.
MclarionWow_MetadataStorageBudget=function(candidate)
 candidate.records["reputation:17:123:enUS"].name="tampered"
 return true
end
assert(not MclarionWow_EnrichObserved("currency",{18},owner,106,123))
equal(VaultkeeperMetadataData.records["reputation:17:123:enUS"].name,"Updated")
MclarionWow_MetadataStorageBudget=function() return true end
-- Build, locale, combat and source scopes remain separate; missing metadata is unknown.
assert(MclarionWow_MetadataLabel("reputation",17,124,owner)==nil)
GetLocale=function() return "frFR" end
assert(MclarionWow_MetadataLabel("reputation",17,123,owner)==nil)
GetLocale=function() return "enUS" end
InCombatLockdown=function() return true end
assert(not MclarionWow_EnrichObserved("currency",{18},owner,107,123))
InCombatLockdown=function() return false end
VaultkeeperMetadataData.extra=true
assert(not MclarionWow_EnrichObserved("currency",{18},owner,105,123))
assert(MclarionWow_MetadataLabel("currency",18,123,owner)==nil)
print("metadata capture contract ok")
