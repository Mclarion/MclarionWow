local function load(path) local f=assert(loadfile(path));if setfenv then setfenv(f,_G) end;f() end
local owner="Player-1-ABCDEF12"
issecretvalue=function(v) return type(v)=="table" and v.protected==true end
issecrettable=function(v) return v.protected==true end
InCombatLockdown=function() return false end
UnitGUID=function() return owner end
GetLocale=function() return "enUS" end
GetBuildInfo=function() return "1.60.1","70205","date",16001 end
GetServerTime=function() return 100 end
MclarionWow_MetadataStorageBudget=function() return true end
local listeners={}
CreateFrame=function() local f={events={}};function f:RegisterEvent(e) self.events[e]=true end;function f:SetScript(_,cb) self.cb=cb end;listeners[#listeners+1]=f;return f end
local timers={}
C_Timer={After=function(delay,callback) assert(delay>=1);timers[#timers+1]=callback end}
local seen={}
local description=""
C_Spell={GetSpellInfo=function(id) seen[#seen+1]=id;return {spellID=id,name="Frostbolt",iconID=1234,castTime=3000} end,
 GetSpellDescription=function() return description end}
load("../VaultkeeperMetadata/MetadataCapture.lua")
load("../VaultkeeperMetadata/SpellEvents.lua")
assert(listeners[1].events.UNIT_SPELLCAST_SUCCEEDED)
local function event(e,...) for _,f in ipairs(listeners) do if f.events[e] then f.cb(f,e,...) end end end
-- Consent defaults off. No raw cast GUID retained and combat only queues IDs.
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",116)
assert(#seen==0 and VaultkeeperMetadataData==nil)
assert(MclarionWow_SetSpellMetadataConsent(true))
-- The public setter, not only the slash handler, must discard queued combat work.
InCombatLockdown=function() return true end
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",117)
assert(MclarionWow_SetSpellMetadataConsent(false)==false,"combat opt-out is refused")
InCombatLockdown=function() return false end
assert(MclarionWow_SetSpellMetadataConsent(false))
assert(MclarionWow_SetSpellMetadataConsent(true))
event("PLAYER_REGEN_ENABLED")
assert(#seen==0 and VaultkeeperMetadataData.records["spell:117:70205:enUS:"..owner]==nil,"stale queued ID after public off/on")
InCombatLockdown=function() return true end
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",116)
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",116)
event("UNIT_SPELLCAST_SUCCEEDED","target","castGUID",118)
assert(#seen==0)
InCombatLockdown=function() return false end
event("PLAYER_REGEN_ENABLED")
assert(#seen==1 and seen[1]==116)
local key="spell:116:70205:enUS:"..owner
local record=assert(VaultkeeperMetadataData.records[key]);assert(record.name=="Frostbolt" and record.iconFileID==1234 and record.description==nil)
assert(record.descriptionContext==nil and record.castTime==nil and record.observedBy==owner)
description="Slows target."
event("SPELL_TEXT_UPDATE",116)
assert(VaultkeeperMetadataData.records[key].description=="Slows target.")
local name,text,icon=MclarionWow_MetadataLabel("spell",116,70205,owner)
assert(name=="Frostbolt" and text=="Slows target." and icon==1234)
-- The same ID/build/locale has independent observer variants and optional fields.
local other="Player-2-BB334455"
owner=other;description=""
assert(MclarionWow_EnrichObserved("spell",{116},other,101,70205))
local otherKey="spell:116:70205:enUS:"..other
assert(VaultkeeperMetadataData.records[otherKey] and VaultkeeperMetadataData.records[otherKey].description==nil)
assert(VaultkeeperMetadataData.records[key].description=="Slows target.")
assert(MclarionWow_MetadataLabel("spell",116,70205,other)=="Frostbolt")
assert(select(2,MclarionWow_MetadataLabel("spell",116,70205,other))==nil)
assert(MclarionWow_MetadataLabel("spell",116,70205,"Player-3-C3")==nil)
local otherRows=MclarionWow_MetadataSpellRows(70205,other)
assert(#otherRows==1 and otherRows[1].description==nil)
owner="Player-1-ABCDEF12"
assert(select(2,MclarionWow_MetadataLabel("spell",116,70205,owner))=="Slows target.")
-- Unavailable text cannot erase already known fields.
description=""
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",116)
assert(VaultkeeperMetadataData.records[key].description=="Slows target.")
assert(MclarionWow_SetSpellMetadataConsent(false))
local before=#seen
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",117)
event("SPELL_TEXT_UPDATE",117)
assert(#seen==before and VaultkeeperMetadataData.records["spell:117:70205:enUS:"..owner]==nil)
assert(MclarionWow_SetSpellMetadataConsent(true))
-- A timer scheduled before opt-out cannot wake work queued after re-enable.
assert(#timers>0)
InCombatLockdown=function() return true end
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",119)
InCombatLockdown=function() return false end
local staleWake=table.remove(timers,1);staleWake()
assert(#seen==before,"pre-opt-out timer processed a new session's queue")
description="Ready"
event("PLAYER_REGEN_ENABLED")
assert(#seen==before+1 and VaultkeeperMetadataData.records["spell:119:70205:enUS:"..owner])
before=#seen
InCombatLockdown=function() return true end
for id=200,264 do event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",id) end
event("UNIT_SPELLCAST_SUCCEEDED",{protected=true},"castGUID",265)
event("UNIT_SPELLCAST_SUCCEEDED","player","castGUID",{protected=true})
assert(#seen==before,"combat queue must not look up spells")
description="Ready"
InCombatLockdown=function() return false end
event("PLAYER_REGEN_ENABLED")
local wakes=0
while #timers>0 and wakes<20 do local wake=table.remove(timers,1);wake();wakes=wakes+1 end
assert(#seen==before+64 and wakes<=20,"bounded deduplicated queue drops 65th ID")
assert(VaultkeeperMetadataData.records["spell:263:70205:enUS:"..owner] and not VaultkeeperMetadataData.records["spell:264:70205:enUS:"..owner])
print("spell metadata event contract ok")
