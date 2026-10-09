-- Only player-success IDs, with explicit consent. No combat payload, cast history or spellbook traversal.
local pending,order={},{}
local timerScheduled=false
local generation=0
local function clear()
 pending={};order={};timerScheduled=false;generation=generation+1
end
local MAX_PENDING,MAX_ID=64,2147483647
local function safe(v)
 if type(issecretvalue)~="function" then return false end
 local ok,s=pcall(issecretvalue,v)
 return ok and s==false
end
local function valid(id) return safe(id) and type(id)=="number" and id>=1 and id<=MAX_ID and id==math.floor(id) end
local function consent()
 local root=VaultkeeperMetadataData
 if not safe(root) or type(root)~="table" or type(issecrettable)~="function" then return false end
 local ok,secret=pcall(issecrettable,root)
 if not ok or secret~=false then return false end
 local meta,mt=pcall(getmetatable,root)
 if not meta or not safe(mt) or mt~=nil then return false end
 local enabled=rawget(root,"spellCaptureEnabled")
 return safe(enabled) and enabled==true
end
local function context()
 local g,t,b=UnitGUID,GetServerTime,GetBuildInfo
 if not safe(g) or not safe(t) or not safe(b) or type(g)~="function" or type(t)~="function" or type(b)~="function" then return end
 local a,owner=pcall(g,"player")
 local c,stamp=pcall(t)
 local d,_,build=pcall(b)
 if not a or not c or not d or not safe(owner) or type(owner)~="string" or not owner:match("^Player%-[A-Za-z0-9%-]+$") or
  not safe(stamp) or type(stamp)~="number" or stamp<1 or stamp>253402300799 or stamp~=math.floor(stamp) or
  not safe(build) or type(build)~="string" or not build:match("^[1-9]%d*$") then return end
 local n=tonumber(build)
 if not n or n>MAX_ID then return end
 return owner,stamp,n
end
local function outOfCombat()
 local fn=InCombatLockdown
 if not safe(fn) or type(fn)~="function" then return false end
 local ok,v=pcall(fn)
 return ok and safe(v) and v==false
end
local function process()
 if not consent() then clear();return end
 if not outOfCombat() then return end
 local owner,stamp,build=context()
 if not owner then return end
 -- Work is bounded to four IDs per callback; leftovers get a delayed wakeup.
 local batch=math.min(4,#order)
 for i=1,batch do
  local id=table.remove(order,1)
  if not id then break end
  local tries=pending[id]
  pending[id]=nil
  if tries and valid(id) then
   local fn=MclarionWow_EnrichObserved
   if safe(fn) and type(fn)=="function" then
    local ok,done=pcall(fn,"spell",{id},owner,stamp,build)
    if ok and done and tries<3 then
     local label=MclarionWow_MetadataLabel
     local got,name,description=pcall(label,"spell",id,build,owner)
     if got and safe(name) and type(name)=="string" and (not safe(description) or type(description)~="string" or description=="") then
      local spell=C_Spell
      if safe(spell) and type(spell)=="table" and type(issecrettable)=="function" and not issecrettable(spell) then
       local requested,load=pcall(function() return spell.RequestLoadSpellData end)
       if requested and safe(load) and type(load)=="function" then pcall(load,id) end
      end
      pending[id]=tries+1;order[#order+1]=id
     end
    end
   end
  end
 end
 if #order>0 and not timerScheduled then
  local timer=C_Timer
  if safe(timer) and type(timer)=="table" and type(issecrettable)=="function" and not issecrettable(timer) then
   local ok,after=pcall(function() return timer.After end)
   if ok and safe(after) and type(after)=="function" then
    timerScheduled=true
    local scheduledGeneration=generation
    local scheduled=pcall(after,2,function()
     if generation~=scheduledGeneration then return end
     timerScheduled=false;process()
    end)
    if not scheduled then timerScheduled=false end
   end
  end
 end
end
local frame=type(CreateFrame)=="function" and CreateFrame("Frame")
if frame then
 for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","SPELL_TEXT_UPDATE","SPELL_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED"}) do frame:RegisterEvent(e) end
 frame:SetScript("OnEvent",function(_,event,a,b,c)
  if not consent() then clear();return end
  if event=="UNIT_SPELLCAST_SUCCEEDED" then
   if not safe(a) or a~="player" or not valid(c) then return end
   if not pending[c] and #order<MAX_PENDING then pending[c]=1;order[#order+1]=c end
  elseif event=="SPELL_TEXT_UPDATE" or event=="SPELL_DATA_LOAD_RESULT" then
   if not valid(a) or not pending[a] then return end
   if event=="SPELL_DATA_LOAD_RESULT" and (not safe(b) or b~=true) then return end
  end
  process()
 end)
end
-- Wrap the public setter so every successful opt-out clears this private queue,
-- including callers that never pass through the slash command.
local setConsent=MclarionWow_SetSpellMetadataConsent
if type(setConsent)=="function" then
 MclarionWow_SetSpellMetadataConsent=function(enabled)
  local accepted=setConsent(enabled)
  if accepted and enabled==false then clear() end
  return accepted
 end
end
-- No automatic opt-in: the player must explicitly run /vkmspells on.
SLASH_VAULTKEEPERMETADATASPELLS1="/vkmspells"
SlashCmdList=SlashCmdList or {}
SlashCmdList.VAULTKEEPERMETADATASPELLS=function(command)
 if not safe(command) or type(command)~="string" then return end
 local value=command=="on" and true or command=="off" and false or nil
 local message="Usage: /vkmspells on|off (spell metadata capture is off by default)."
 if value~=nil and type(MclarionWow_SetSpellMetadataConsent)=="function" then
  if MclarionWow_SetSpellMetadataConsent(value) then
   message=value and "Vaultkeeper spell metadata: enabled." or "Vaultkeeper spell metadata: disabled."
  else message="Vaultkeeper spell metadata: change refused (combat, invalid data or storage budget)." end
 end
 local chat=DEFAULT_CHAT_FRAME
 if safe(chat) and type(chat)=="table" and safe(chat.AddMessage) and type(chat.AddMessage)=="function" then
  pcall(chat.AddMessage,chat,message)
 end
end
