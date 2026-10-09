local path = ... or "../WealthCapture.lua"
local n = 0
local function eq(a,b,label) n=n+1; assert(a==b, label..": "..tostring(a).." ~= "..tostring(b)) end
local hidden = setmetatable({}, {__mode="k"})
local function protect(v) hidden[v]=true; return v end
issecretvalue=function(v) return hidden[v] == true end
issecrettable=function(v) return hidden[v] == true end
InCombatLockdown=function() return false end
local owner="Player-1234-ABCDEF12"
UnitGUID=function() return owner end
local stamp=1720000000
GetServerTime=function() return stamp end
GetBuildInfo=function() return "1.60.1", "70205" end
local coins=12345
GetMoney=function() return coins end
local rows={{name="Header",isHeader=true,isHeaderExpanded=true,currencyListDepth=0,currencyID=0,quantity=0,isAccountWide=false},
 {name="Character",isHeader=false,isHeaderExpanded=false,currencyListDepth=1,currencyID=101,quantity=7,isAccountWide=false},
 {name="Account",isHeader=false,isHeaderExpanded=false,currencyListDepth=1,currencyID=202,quantity=9,isAccountWide=true}}
C_CurrencyInfo={GetCurrencyListSize=function() return #rows end,GetCurrencyListInfo=function(i) return rows[i] end}
local budgetCalls=0
MclarionWow_WealthStorageBudget=function() budgetCalls=budgetCalls+1; return true end
assert(loadfile(path))()
local legacy={schema=2,characters={[owner]={"untouched"}}}
MclarionWowData=legacy
local ok, reason=MclarionWow_CaptureGold(false)
eq(ok,nil,"gold auto off")
eq(MclarionWowWealthData,nil,"off does not initialize")
ok,reason=MclarionWow_CaptureGold(true)
eq(ok,true,"manual gold")
eq(reason,"saved","gold saved")
local root=MclarionWowWealthData
eq(root.characters[owner].gold[1].copper,12345,"integer copper balance")
eq(root.characters[owner].gold[1].build,70205,"second build result")
eq(legacy.characters[owner][1],"untouched","legacy preserved")
ok,reason=MclarionWow_CaptureGold(true)
eq(reason,"unchanged","same balance dedup")
eq(MclarionWowWealthData,root,"dedup no write")
coins=12346; stamp=stamp+1
ok,reason=MclarionWow_CaptureGold(true)
eq(reason,"saved","new balance")
eq(#MclarionWowWealthData.characters[owner].gold,2,"two observations")
eq(#root.characters[owner].gold,1,"copy on write")
local function refuse(label, change, restore, fn)
 local before=MclarionWowWealthData; local calls=budgetCalls
 change(); local safe,result,why=pcall(fn or MclarionWow_CaptureGold,true)
 eq(safe,true,label.." no throw"); eq(result,nil,label.." refusal"); eq(type(why),"string",label.." reason")
 eq(MclarionWowWealthData,before,label.." preserves root"); eq(budgetCalls,calls,label.." no budget")
 restore()
end
refuse("missing value primitive",function() issecretvalue=nil end,function() issecretvalue=function(v) return hidden[v]==true end end)
refuse("missing table primitive",function() issecrettable=nil end,function() issecrettable=function(v) return hidden[v]==true end end)
refuse("throwing primitive",function() issecretvalue=function() error("private") end end,function() issecretvalue=function(v) return hidden[v]==true end end)
refuse("combat",function() InCombatLockdown=function() return true end end,function() InCombatLockdown=function() return false end end)
refuse("protected combat",function() InCombatLockdown=protect(function() end) end,function() InCombatLockdown=function() return false end end)
refuse("protected combat result",function() InCombatLockdown=function() return protect({}) end end,function() InCombatLockdown=function() return false end end)
refuse("protected money",function() GetMoney=function() return protect({}) end end,function() GetMoney=function() return coins end end)
refuse("throwing money",function() GetMoney=function() error("private") end end,function() GetMoney=function() return coins end end)
refuse("fractional money",function() GetMoney=function() return 1.5 end end,function() GetMoney=function() return coins end end)
refuse("negative money",function() GetMoney=function() return -1 end end,function() GetMoney=function() return coins end end)
refuse("owner switch",function() local c=0; UnitGUID=function() c=c+1; return c==1 and owner or "Player-1234-OTHER" end end,function() UnitGUID=function() return owner end end)
local intact=MclarionWowWealthData
MclarionWowWealthData={schema=2,settings={},characters={},accountCurrency={}}
ok,reason=MclarionWow_CaptureGold(true)
eq(ok,nil,"future schema refused"); eq(MclarionWowWealthData.schema,2,"future schema retained")
MclarionWowWealthData=intact
-- Explicit budget must approve entire candidate, including preserved sibling histories.
refuse("budget veto",function() MclarionWow_WealthStorageBudget=function() return false end end,
 function() MclarionWow_WealthStorageBudget=function() budgetCalls=budgetCalls+1; return true end end,
 function() return MclarionWow_SetAutoGoldCapture(true) end)
local savedBudget=MclarionWow_WealthStorageBudget
MclarionWow_WealthStorageBudget=nil
ok=MclarionWow_SetAutoGoldCapture(true); eq(ok,nil,"budget callback required")
MclarionWow_WealthStorageBudget=savedBudget
ok=MclarionWow_SetAutoGoldCapture(true); eq(ok,true,"gold opt in")
eq(MclarionWow_GoldAutoEnabled(),true,"gold auto enabled")
coins=12347; stamp=stamp+1
ok,reason=MclarionWow_CaptureGold(false); eq(reason,"saved","gold automatic after consent")
ok=MclarionWow_SetAutoGoldCapture(false); eq(ok,true,"gold opt out")
ok=MclarionWow_CaptureGold(false); eq(ok,nil,"gold auto disabled")
-- A currency row's documented isAccountWide flag controls storage destination.
local metadataCalls=0
MclarionWow_EnrichObserved=function(kind,ids,who,at,build)
 metadataCalls=metadataCalls+1;eq(kind,"currency","metadata type");eq(ids[1],101,"character observed ID");eq(ids[2],202,"account observed ID");eq(who,owner,"observer");eq(build,70205,"build");return false
end
ok,reason=MclarionWow_CaptureCurrency(true)
eq(metadataCalls,1,"optional metadata refusal does not block currency")
eq(ok,true,"manual visible currency scan")
eq(reason,"saved","currency saved")
root=MclarionWowWealthData
local char=root.characters[owner].currency[1]
eq(char.scope,"visible-ui","partial visible scope")
eq(char.values[1].id,101,"character ID")
eq(char.values[1].quantity,7,"character quantity")
eq(#char.values,1,"account item excluded from character")
local account=root.accountCurrency[1]
eq(account.scope,"visible-ui","account partial scope")
eq(account.observedBy,owner,"observer not owner")
eq(account.values[1].id,202,"account ID")
eq(account.values[1].quantity,9,"account quantity")
ok,reason=MclarionWow_CaptureCurrency(true); eq(reason,"unchanged","currency dedup")
eq(MclarionWowWealthData,root,"currency no write")
local function crefuse(label,change,restore) refuse(label,change,restore,MclarionWow_CaptureCurrency) end
crefuse("unknown provenance",function() rows[3].isAccountWide=nil end,function() rows[3].isAccountWide=true end)
crefuse("protected provenance",function() rows[3].isAccountWide=protect({}) end,function() rows[3].isAccountWide=true end)
crefuse("protected row",function() hidden[rows[2]]=true end,function() hidden[rows[2]]=nil end)
crefuse("protected quantity",function() rows[2].quantity=protect({}) end,function() rows[2].quantity=7 end)
crefuse("row getter throws",function() C_CurrencyInfo.GetCurrencyListInfo=function() error("private") end end,
 function() C_CurrencyInfo.GetCurrencyListInfo=function(i) return rows[i] end end)
crefuse("list changes",function() local c=0; C_CurrencyInfo.GetCurrencyListSize=function() c=c+1; return c<3 and 3 or 2 end end,
 function() C_CurrencyInfo.GetCurrencyListSize=function() return #rows end end)
crefuse("row changes",function() local c=0; C_CurrencyInfo.GetCurrencyListInfo=function(i) c=c+1; if c>3 and i==2 then return {name="Character",isHeader=false,currencyID=101,quantity=8,isAccountWide=false} end; return rows[i] end end,
 function() C_CurrencyInfo.GetCurrencyListInfo=function(i) return rows[i] end end)
crefuse("duplicate IDs",function() rows[3].currencyID=101 end,function() rows[3].currencyID=202 end)
crefuse("over-limit count",function() C_CurrencyInfo.GetCurrencyListSize=function() return 257 end end,
 function() C_CurrencyInfo.GetCurrencyListSize=function() return #rows end end)
crefuse("protected namespace",function() hidden[C_CurrencyInfo]=true end,function() hidden[C_CurrencyInfo]=nil end)
crefuse("combat currency",function() InCombatLockdown=function() return true end end,function() InCombatLockdown=function() return false end end)
local previous=MclarionWowWealthData
rows[2].quantity=8; stamp=stamp+1
MclarionWow_WealthStorageBudget=function(candidate) candidate.characters[owner].gold[1].copper=0; return true end
ok=MclarionWow_CaptureCurrency(true); eq(ok,nil,"budget mutation rejected")
eq(MclarionWowWealthData,previous,"budget mutation does not touch source")
eq(previous.characters[owner].gold[1].copper,12345,"old gold intact")
MclarionWow_WealthStorageBudget=savedBudget
ok,reason=MclarionWow_CaptureCurrency(true); eq(reason,"saved","currency state changed")
eq(#MclarionWowWealthData.accountCurrency,1,"unchanged account history not rewritten")
local oldRoot=MclarionWowWealthData
local newOwner="Player-1234-OTHER"
owner=newOwner; stamp=stamp+1
ok,reason=MclarionWow_CaptureGold(true); eq(reason,"saved","new owner gold")
eq(MclarionWowWealthData.characters[newOwner].gold[1].copper,coins,"new owner separate")
eq(#MclarionWowWealthData.characters["Player-1234-ABCDEF12"].gold,#oldRoot.characters["Player-1234-ABCDEF12"].gold,"first owner preserved")
-- Caps are refusals rather than truncated or overwritten histories.
for i=1,22 do
 stamp=stamp+1;coins=coins+1
 ok,reason=MclarionWow_CaptureGold(true)
 eq(reason,"saved","rolling gold capture "..i)
end
eq(#MclarionWowWealthData.characters[newOwner].gold,20,"gold history limited to 20")
local full={schema=1,settings={autoGoldCapture=false,autoCurrencyCapture=false},characters={},accountCurrency={}}
for i=1,256 do full.characters["Player-1234-F"..i]={gold={{at=1720000000,build=70205,copper=i}}} end
local active=MclarionWowWealthData
MclarionWowWealthData=full
ok=MclarionWow_CaptureGold(true)
eq(ok,nil,"owner 257 refused")
eq(MclarionWowWealthData,full,"owner overflow preserved")
MclarionWowWealthData=active
owner="Player-1234-ABCDEF12"
crefuse("protected header title",function() rows[1].name=protect({}) end,function() rows[1].name="Header" end)
crefuse("missing header expansion",function() rows[1].isHeaderExpanded=nil end,function() rows[1].isHeaderExpanded=true end)
crefuse("protected field",function() rows[2].currencyID=protect({}) end,function() rows[2].currencyID=101 end)
crefuse("provenance changes between scans",function()
 local c=0;C_CurrencyInfo.GetCurrencyListInfo=function(i)
  c=c+1
  if c>3 and i==3 then
   return {name="Account",isHeader=false,isHeaderExpanded=false,currencyListDepth=1,currencyID=202,quantity=9,isAccountWide=false}
  end
  return rows[i]
 end
end,function() C_CurrencyInfo.GetCurrencyListInfo=function(i) return rows[i] end end)
local ns=C_CurrencyInfo
crefuse("missing currency namespace",function() C_CurrencyInfo=nil end,function() C_CurrencyInfo=ns end)
crefuse("protected list count",function() C_CurrencyInfo.GetCurrencyListSize=function() return protect({}) end end,
 function() C_CurrencyInfo.GetCurrencyListSize=function() return #rows end end)
local previous=MclarionWowWealthData
local opaque=protect(setmetatable({}, {__eq=function() error("protected equality") end}))
MclarionWowWealthData=opaque
local safe,result,why=pcall(MclarionWow_CaptureGold,true)
eq(safe,true,"protected root controlled")
eq(result,nil,"protected root refused")
eq(why,"Wealth protected value refused.","protected root checked first")
eq(MclarionWowWealthData,opaque,"protected root not replaced")
MclarionWowWealthData=previous
MclarionWow_WealthStorageBudget=function() return protect({}) end
ok=MclarionWow_SetAutoCurrencyCapture(true)
eq(ok,nil,"protected budget result refused")
MclarionWow_WealthStorageBudget=savedBudget
ok=MclarionWow_SetAutoCurrencyCapture(true)
eq(ok,true,"currency auto opt in")
eq(MclarionWow_CurrencyAutoEnabled(),true,"currency auto enabled")
ok=MclarionWow_SetAutoCurrencyCapture(false)
eq(ok,true,"currency auto opt out")
eq(MclarionWow_CurrencyAutoEnabled(),false,"currency auto off")
print("Wealth capture: "..n.." assertions passed")
