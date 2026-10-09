-- Optional, observed-ID-only metadata. No API enumeration, UI mutation, or numeric-history dependency.
local MAX, TIME = 2147483647, 253402300799
local function ready() return type(issecretvalue)=="function" and type(issecrettable)=="function" end
local function safe(v)
 local ok,s=pcall(issecretvalue,v)
 if not ok or type(s)~="boolean" or s then return false end
 if type(v)=="table" then ok,s=pcall(issecrettable,v); if not ok or type(s)~="boolean" or s then return false end end
 return true
end
local function plain(t)
 if not safe(t) or type(t)~="table" then return false end
 local ok,m=pcall(getmetatable,t);return ok and safe(m) and m==nil
end
local function integer(n,lo,hi) return safe(n) and type(n)=="number" and n>=lo and n<=hi and n==math.floor(n) end
local function guid(s) return safe(s) and type(s)=="string" and #s>=11 and #s<=77 and s:match("^Player%-[A-Za-z0-9%-]+$")~=nil end
local function text(s,cap,nonempty) return safe(s) and type(s)=="string" and #s<=cap and (not nonempty or #s>0) and not s:find("%z") end
local function recordKey(kind,id,build,locale,observer)
 local key=kind..":"..id..":"..build..":"..locale
 return kind=="spell" and key..":"..observer or key
end
local fields={entityType=true,id=true,build=true,locale=true,observedAt=true,observedBy=true,scope=true,name=true,description=true,iconFileID=true,quality=true,descriptionProvenance=true}
local function record(r,k)
 if not plain(r) then return false end
 for key,value in pairs(r) do if not safe(key) or not safe(value) or not fields[key] then return false end end
 local kind,id,build,locale=rawget(r,"entityType"),rawget(r,"id"),rawget(r,"build"),rawget(r,"locale")
 local scope=rawget(r,"scope")
 if not safe(kind) or not safe(scope) or (kind~="reputation" and kind~="currency" and kind~="spell") or not integer(id,1,MAX) or not integer(build,1,MAX) or
  not text(locale,8,true) or not locale:match("^[A-Za-z]+$") or not guid(rawget(r,"observedBy")) or
  k~=recordKey(kind,id,build,locale,rawget(r,"observedBy")) or
  not integer(rawget(r,"observedAt"),1,TIME) or
  (scope~="character" and scope~="account") or
  not text(rawget(r,"name"),256,true) then return false end
 local description=rawget(r,"description")
 if description~=nil and not text(description,1024,false) then return false end
 local icon,quality=rawget(r,"iconFileID"),rawget(r,"quality")
 if kind=="reputation" and (icon~=nil or quality~=nil or scope~="character") then return false end
 if kind=="spell" and (scope~="character" or quality~=nil or
  (description~=nil and rawget(r,"descriptionProvenance")~="player-spellcast:C_Spell.GetSpellDescription") or
  (description==nil and rawget(r,"descriptionProvenance")~=nil)) then return false end
 if kind~="spell" and rawget(r,"descriptionProvenance")~=nil then return false end
 if icon~=nil and not integer(icon,0,MAX) then return false end
 if quality~=nil and not integer(quality,0,10) then return false end
 return true
end
local function validate(root)
 if not plain(root) then return false end
 for k,v in pairs(root) do if not safe(k) or not safe(v) or (k~="schema" and k~="records" and k~="spellCaptureEnabled") then return false end end
 if not safe(rawget(root,"schema")) or rawget(root,"schema")~=1 then return false end
 local consent=rawget(root,"spellCaptureEnabled")
 if not safe(consent) or (consent~=nil and type(consent)~="boolean") then return false end
 local records=rawget(root,"records")
 if not plain(records) or records==root then return false end
 local count,bytes,seen=0,256,{[root]=true,[records]=true}
 for k,v in pairs(records) do
  if not text(k,128,true) or not safe(v) or seen[v] or not record(v,k) then return false end
  seen[v]=true;count=count+1
  bytes=bytes+256+#k+#rawget(v,"name")+#(rawget(v,"description") or "")+#rawget(v,"observedBy")
  if count>400 or bytes>524288 then return false end
 end
 return true
end
local function clone(root)
 local copy={schema=1,records={},spellCaptureEnabled=root.spellCaptureEnabled}
 for k,r in pairs(root.records) do
  local entry={};for field,value in pairs(r) do entry[field]=value end
  copy.records[k]=entry
 end
 return copy
end
local function api(kind,id)
 if kind=="spell" then
  local namespace=C_Spell
  if not plain(namespace) then return nil end
  local ok,infoFn,descriptionFn=pcall(function() return namespace.GetSpellInfo,namespace.GetSpellDescription end)
  if not ok or not safe(infoFn) or type(infoFn)~="function" or not safe(descriptionFn) or type(descriptionFn)~="function" then return nil end
  local found,info=pcall(infoFn,id)
  if not found or not plain(info) then return nil end
  local fieldsOk,spellID,name,icon,original=pcall(function() return info.spellID,info.name,info.iconID,info.originalIconID end)
  if not fieldsOk or not integer(spellID,1,MAX) or spellID~=id or not text(name,256,true) or
   not safe(icon) or (icon~=nil and not integer(icon,0,MAX)) or
   not safe(original) or (original~=nil and not integer(original,0,MAX)) then return nil end
  local out={name=name,iconFileID=original or icon,scope="character"}
  local described,description=pcall(descriptionFn,id)
  if described and safe(description) and text(description,1024,false) and description~="" then
   out.description=description
   out.descriptionProvenance="player-spellcast:C_Spell.GetSpellDescription"
  end
  return out
 end
 local namespace=kind=="currency" and C_CurrencyInfo or C_Reputation
 if not plain(namespace) then return nil end
 local key=kind=="currency" and "GetCurrencyInfo" or "GetFactionDataByID"
 local ok,fn=pcall(function() return namespace[key] end)
 if not ok or not safe(fn) or type(fn)~="function" then return nil end
 local called,result=pcall(fn,id)
 if not called or not plain(result) then return nil end
 local fieldsOk,found,name,description,icon,quality,account=pcall(function()
  return result[kind=="currency" and "currencyID" or "factionID"],result.name,result.description,
   result.iconFileID,result.quality,result.isAccountWide
 end)
 if not fieldsOk or not integer(found,1,MAX) or found~=id or not text(name,256,true) or
  not safe(description) or (description~=nil and not text(description,1024,false)) then return nil end
 local out={name=name}
 if description~=nil and description~="" then out.description=description end
 if kind=="currency" then
  if not safe(icon) or (icon~=nil and not integer(icon,0,MAX)) or not safe(quality) or
   (quality~=nil and not integer(quality,0,10)) or not safe(account) or type(account)~="boolean" then return nil end
  out.iconFileID=icon;out.quality=quality;out.scope=account and "account" or "character"
 else out.scope="character" end
 return out
end
local function enrich(kind,ids,owner,stamp,build)
 if not ready() or (kind~="reputation" and kind~="currency" and kind~="spell") or not guid(owner) or
  not integer(stamp,1,TIME) or not integer(build,1,MAX) or not plain(ids) then return false end
 local count,seen=0,{}
 for k,id in pairs(ids) do
  if not integer(k,1,200) or not integer(id,1,MAX) or seen[id] then return false end
  count=count+1;seen[id]=true
 end
 for i=1,count do if rawget(ids,i)==nil then return false end end
 local combat=InCombatLockdown
 if not safe(combat) or type(combat)~="function" then return false end
 local ok,locked=pcall(combat)
 if not ok or not safe(locked) or locked~=false then return false end
 local own=UnitGUID
 if not safe(own) or type(own)~="function" then return false end
 local owned,currentOwner=pcall(own,"player")
 if not owned or not guid(currentOwner) or currentOwner~=owner then return false end
 local localeFn=GetLocale
 if not safe(localeFn) or type(localeFn)~="function" then return false end
 local got,locale=pcall(localeFn)
 if not got or not text(locale,8,true) or not locale:match("^[A-Za-z]+$") then return false end
 local source=VaultkeeperMetadataData
 if not safe(source) or (source~=nil and not validate(source)) then return false end
 if kind=="spell" and (not source or source.spellCaptureEnabled~=true) then return false end
 local root=source and clone(source) or {schema=1,records={}}
 local changed=false
 for i=1,count do
  local id=ids[i];local info=api(kind,id)
  if info then
   local key=recordKey(kind,id,build,locale,owner)
   local prior=root.records[key]
   local nextRecord={entityType=kind,id=id,build=build,locale=locale,observedAt=stamp,observedBy=owner,
    scope=info.scope,name=info.name,description=info.description,iconFileID=info.iconFileID,quality=info.quality,
    descriptionProvenance=info.descriptionProvenance}
   if prior then
    -- Unavailable optional fields never clear a known value; older observations cannot overwrite newer ones.
    if prior.observedAt>stamp then nextRecord=nil
    else
     if nextRecord.description==nil then nextRecord.description=prior.description end
     if nextRecord.descriptionProvenance==nil then nextRecord.descriptionProvenance=prior.descriptionProvenance end
     if nextRecord.iconFileID==nil then nextRecord.iconFileID=prior.iconFileID end
     if nextRecord.quality==nil then nextRecord.quality=prior.quality end
    end
   end
   if nextRecord and record(nextRecord,key) then root.records[key]=nextRecord;changed=true end
  end
 end
 if not changed then return true end
 if not validate(root) then return false end
 local budget=MclarionWow_MetadataStorageBudget
 if not safe(budget) or type(budget)~="function" then return false end
 local offered=clone(root)
 local allowed,result=pcall(budget,offered)
 if not allowed or not safe(result) or result~=true or not validate(offered) then return false end
 -- Reject callback mutation, including edits that remain schema-valid.
 for k,v in pairs(root.records) do
  local other=offered.records[k]
  if not other then return false end
  for f,value in pairs(v) do if rawget(other,f)~=value then return false end end
  for f in pairs(other) do if rawget(v,f)==nil then return false end end
 end
 for k in pairs(offered.records) do if root.records[k]==nil then return false end end
 if offered.spellCaptureEnabled~=root.spellCaptureEnabled then return false end
 local again,now=pcall(combat)
 if not again or not safe(now) or now~=false then return false end
 VaultkeeperMetadataData=root
 return true
end
function MclarionWow_EnrichObserved(...)
 local ok,value=pcall(enrich,...);return ok and value or false
end
-- Explicit, off-by-default consent stored only in the optional metadata owner.
function MclarionWow_SetSpellMetadataConsent(enabled)
 local ok,result=pcall(function()
  if type(enabled)~="boolean" or not ready() then return false end
  local combat=InCombatLockdown
  if not safe(combat) or type(combat)~="function" then return false end
  local checked,locked=pcall(combat)
  if not checked or not safe(locked) or locked~=false then return false end
  local source=VaultkeeperMetadataData
  if not safe(source) or (source~=nil and not validate(source)) then return false end
  local root=source and clone(source) or {schema=1,records={}}
  root.spellCaptureEnabled=enabled
  if not validate(root) then return false end
  local budget=MclarionWow_MetadataStorageBudget
  if not safe(budget) or type(budget)~="function" then return false end
  local offered=clone(root)
  local allowed,value=pcall(budget,offered)
  if not allowed or not safe(value) or value~=true or not validate(offered) then return false end
  if offered.spellCaptureEnabled~=enabled then return false end
  for k,v in pairs(root.records) do
   local other=offered.records[k]
   if not other then return false end
   for f,field in pairs(v) do if rawget(other,f)~=field then return false end end
   for f in pairs(other) do if rawget(v,f)==nil then return false end end
  end
  for k in pairs(offered.records) do if root.records[k]==nil then return false end end
  VaultkeeperMetadataData=root
  return true
 end)
 return ok and result or false
end
function MclarionWow_MetadataLabel(kind,id,build,owner)
 local ok,name,description,icon=pcall(function()
  if not ready() or (kind~="reputation" and kind~="currency" and kind~="spell") or not integer(id,1,MAX) or
   not integer(build,1,MAX) or not guid(owner) then return end
  local root=VaultkeeperMetadataData
  if not validate(root) then return end
  local fn=GetLocale
  if not safe(fn) or type(fn)~="function" then return end
  local yes,locale=pcall(fn)
  if not yes or not text(locale,8,true) or not locale:match("^[A-Za-z]+$") then return end
  local r=rawget(root.records,recordKey(kind,id,build,locale,owner))
  if not r or r.observedBy~=owner or r.scope~="character" and kind=="reputation" then return end
  return r.name,r.description,r.iconFileID
 end)
 if ok then return name,description,icon end
end
-- Detached bounded read-only view; never calls spell APIs.
function MclarionWow_MetadataSpellRows(build,owner)
 local ok,rows=pcall(function()
  if not ready() or not integer(build,1,MAX) or not guid(owner) then return end
  local root=VaultkeeperMetadataData
  if not validate(root) then return end
  local fn=GetLocale
  if not safe(fn) or type(fn)~="function" then return end
  local got,locale=pcall(fn)
  if not got or not text(locale,8,true) or not locale:match("^[A-Za-z]+$") then return end
  local list={}
  for _,r in pairs(root.records) do
   if r.entityType=="spell" and r.build==build and r.locale==locale and r.observedBy==owner then
    list[#list+1]={id=r.id,name=r.name,description=r.description,iconFileID=r.iconFileID,
     observedAt=r.observedAt,descriptionProvenance=r.descriptionProvenance}
   end
  end
  table.sort(list,function(a,b) return a.id<b.id end)
  return list
 end)
 if ok then return rows end
end
