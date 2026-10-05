-- Offline companion candidate. Gethe/wow-ui-source forever commit
-- e3ecc27b64d30fdc735a3f6579b866858f9f9df1: generated
-- CurrencyInfoDocumentation.lua GetCurrencyListSize/GetCurrencyListInfo(index)
-- and CurrencyInfo fields; Blizzard_AuctionHouseCommoditiesBuyFrame.lua:55 GetMoney().
-- Explicit whole-companion budget callback mandatory; no TOC integration.
local MAX=2147483647
local function sec(v)
 local ok,s=pcall(issecretvalue,v)
 if not ok or type(s)~="boolean" or s then return true end
 if type(v)=="table" then local yes,t=pcall(issecrettable,v); return not yes or type(t)~="boolean" or t end
 return false
end
local function ready()
 if type(issecretvalue)~="function" or type(issecrettable)~="function" then return false end
 local a,b=pcall(issecretvalue,nil); local c,d=pcall(issecrettable,{})
 return a and type(b)=="boolean" and c and type(d)=="boolean"
end
local function plain(v)
 if sec(v) or type(v)~="table" then return false end
 local ok,m=pcall(getmetatable,v)
 return ok and not sec(m) and m==nil
end
local function num(v,lo,hi) return not sec(v) and type(v)=="number" and v>=lo and v<=hi and v==math.floor(v) end
local function guid(v) return not sec(v) and type(v)=="string" and #v>=11 and #v<=77 and v:match("^Player%-[A-Za-z0-9%-]+$")~=nil end
local function keys(t,allow)
 if not plain(t) then return false end
 for k,v in pairs(t) do if sec(k) or sec(v) or not allow[k] then return false end end
 return true
end
local rootKeys={schema=true,settings=true,characters=true,accountCurrency=true}
local settingsKeys={autoGoldCapture=true,autoCurrencyCapture=true}
local groupKeys={gold=true,currency=true}
local goldKeys={at=true,build=true,copper=true}
local currencyKeys={at=true,build=true,scope=true,rows=true,values=true,observedBy=true}
local itemKeys={id=true,quantity=true}
local function dense(t,limit)
 if not plain(t) then return nil end
 local n=0
 for k in pairs(t) do if not num(k,1,limit) then return nil end; n=n+1 end
 for i=1,n do if rawget(t,i)==nil then return nil end end
 return n
end
local function history(t,kind,seen,usage)
 local n=dense(t,20)
 if not n or n==0 or seen[t] then return false end
 seen[t]=true
 local previousTime,previousState=0,nil
 for i=1,n do
  local r=rawget(t,i)
  if not keys(r,kind=="gold" and goldKeys or currencyKeys) or seen[r] then return false end
  seen[r]=true
  local at,build=rawget(r,"at"),rawget(r,"build")
  if not num(at,1,253402300799) or not num(build,1,MAX) then return false end
  usage.n=usage.n+100
  local state
  if kind=="gold" then
   local copper=rawget(r,"copper")
   if not num(copper,0,9007199254740991) then return false end
   state=tostring(build)..":"..tostring(copper)
  else
   local scope,rows,values,observer=rawget(r,"scope"),rawget(r,"rows"),rawget(r,"values"),rawget(r,"observedBy")
   if sec(scope) or sec(observer) or scope~="visible-ui" or not num(rows,0,256) or
     (kind=="account" and not guid(observer)) or (kind=="currency" and observer~=nil) then return false end
   local count=dense(values,200)
   if not count or count>rows or seen[values] then return false end
   seen[values]=true
   local prev,entries=0,{}
   for j=1,count do
    local e=rawget(values,j)
    if not keys(e,itemKeys) or seen[e] then return false end
    seen[e]=true
    local id,quantity=rawget(e,"id"),rawget(e,"quantity")
    if not num(id,1,MAX) or id<=prev or not num(quantity,0,9007199254740991) then return false end
    prev=id; entries[j]=id..":"..quantity;usage.n=usage.n+80
   end
   state=tostring(build)..":"..rows..":"..table.concat(entries,";")
  end
  if at<=previousTime or state==previousState then return false end
  previousTime,previousState=at,state
 end
 return true
end
local function validate(root)
 if not keys(root,rootKeys) then return nil,"Wealth storage format refused." end
 local schema,settings,characters,account=rawget(root,"schema"),rawget(root,"settings"),rawget(root,"characters"),rawget(root,"accountCurrency")
 if sec(schema) or schema~=1 or not keys(settings,settingsKeys) or not plain(characters) or not plain(account) or
  sec(rawget(settings,"autoGoldCapture")) or sec(rawget(settings,"autoCurrencyCapture")) or
  type(rawget(settings,"autoGoldCapture"))~="boolean" or type(rawget(settings,"autoCurrencyCapture"))~="boolean" then return nil,"Wealth storage format refused." end
 local seen={[root]=true,[settings]=true,[characters]=true};local usage={n=512};local owners=0
 for owner,group in pairs(characters) do
  if not guid(owner) or not keys(group,groupKeys) or seen[group] then return nil,"Wealth owner format refused." end
  seen[group]=true;owners=owners+1;usage.n=usage.n+128+#owner
  if owners>256 then return nil,"Wealth owner limit reached." end
  local gold,currency=rawget(group,"gold"),rawget(group,"currency")
  if sec(gold) or sec(currency) or (gold==nil and currency==nil) or
    (gold~=nil and not history(gold,"gold",seen,usage)) or
    (currency~=nil and not history(currency,"currency",seen,usage)) then return nil,"Wealth history format refused." end
 end
 if seen[account] or not plain(account) then return nil,"Wealth account history format refused." end
 local count=dense(account,20)
 if not count or (count>0 and not history(account,"account",seen,usage)) then return nil,"Wealth account history format refused." end
 if usage.n>1048576 then return nil,"Wealth structural limit reached." end
 return owners
end
local function cloneRecord(r,kind)
 local out={at=rawget(r,"at"),build=rawget(r,"build")}
 if kind=="gold" then out.copper=rawget(r,"copper");return out end
 out.scope=rawget(r,"scope");out.rows=rawget(r,"rows");out.values={}
 if kind=="account" then out.observedBy=rawget(r,"observedBy") end
 for i,e in ipairs(rawget(r,"values")) do out.values[i]={id=rawget(e,"id"),quantity=rawget(e,"quantity")} end
 return out
end
local function cloneHistory(t,kind)
 local out={};for i,r in ipairs(t) do out[i]=cloneRecord(r,kind) end;return out
end
local function candidate(source)
 if sec(source) then return nil,"Wealth protected value refused." end
 if source==nil then return {schema=1,settings={autoGoldCapture=false,autoCurrencyCapture=false},characters={},accountCurrency={}},nil,0 end
 local owners,why=validate(source)
 if not owners then return nil,why end
 local flags=rawget(source,"settings")
 local out={schema=1,settings={autoGoldCapture=rawget(flags,"autoGoldCapture"),autoCurrencyCapture=rawget(flags,"autoCurrencyCapture")},characters={},accountCurrency=cloneHistory(rawget(source,"accountCurrency"),"account")}
 for owner,g in pairs(rawget(source,"characters")) do
  local next={};local gold,currency=rawget(g,"gold"),rawget(g,"currency")
  if gold then next.gold=cloneHistory(gold,"gold") end
  if currency then next.currency=cloneHistory(currency,"currency") end
  out.characters[owner]=next
 end
 return out,nil,owners
end
local function equivalent(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b end
 if not plain(a) or not plain(b) then return false end
 for k,v in pairs(a) do if not equivalent(v,rawget(b,k)) then return false end end
 for k in pairs(b) do if rawget(a,k)==nil then return false end end
 return true
end
local function budget(root)
 local fn=MclarionWow_WealthStorageBudget
 if sec(fn) or type(fn)~="function" then return nil,"Wealth storage budget refused." end
 -- A caller-controlled budget must not be able to alter the candidate to be committed.
 local offered=candidate(root)
 if not offered then return nil,"Wealth storage budget refused." end
 local ok,result=pcall(fn,offered)
 if not ok or sec(result) or result~=true or not validate(offered) or
    not equivalent(root,offered) then return nil,"Wealth storage budget refused." end
 return true
end
local function context()
 local combat=InCombatLockdown
 if sec(combat) or type(combat)~="function" then return nil,nil,nil,"Combat status unavailable." end
 local ok,locked=pcall(combat)
 if not ok or sec(locked) or type(locked)~="boolean" or locked then return nil,nil,nil,"Wealth capture unavailable in combat." end
 local own,time,buildFn=UnitGUID,GetServerTime,GetBuildInfo
 if sec(own) or sec(time) or sec(buildFn) or type(own)~="function" or type(time)~="function" or type(buildFn)~="function" then return nil,nil,nil,"Wealth metadata unavailable." end
 local a,owner=pcall(own,"player");local b,stamp=pcall(time);local c,_,text=pcall(buildFn)
 if not a or not b or not c or not guid(owner) or not num(stamp,1,253402300799) or sec(text) or type(text)~="string" or not text:match("^[1-9]%d*$") then return nil,nil,nil,"Wealth metadata unavailable." end
 local build=tonumber(text)
 if not num(build,1,MAX) or tostring(build)~=text then return nil,nil,nil,"Wealth metadata unavailable." end
 return owner,stamp,build
end
local function row(info)
 if not plain(info) then return nil,"Currency row unavailable." end
 local ok,name,header,expanded,depth=pcall(function() return info.name,info.isHeader,info.isHeaderExpanded,info.currencyListDepth end)
 if not ok or sec(name) or sec(header) or sec(expanded) or sec(depth) or type(name)~="string" or #name<1 or #name>256 or type(header)~="boolean" or type(expanded)~="boolean" or not num(depth,0,16) then return nil,"Currency row unavailable." end
 local signature=(header and "H" or "L")..#name..":"..name..":"..tostring(expanded)..":"..depth
 if header then return signature end
 local yes,id,quantity,account=pcall(function() return info.currencyID,info.quantity,info.isAccountWide end)
 if not yes or not num(id,1,MAX) or not num(quantity,0,9007199254740991) or sec(account) or type(account)~="boolean" then return nil,"Currency balance or provenance unavailable." end
 return signature..":"..id..":"..quantity..":"..tostring(account),{id=id,quantity=quantity},account
end
local function scan()
 local ns=C_CurrencyInfo
 if not plain(ns) then return nil,"Currency API unavailable." end
 local ok,count,get=pcall(function() return ns.GetCurrencyListSize,ns.GetCurrencyListInfo end)
 if not ok or sec(count) or sec(get) or type(count)~="function" or type(get)~="function" then return nil,"Currency API unavailable." end
 local function size() local yes,n=pcall(count);if yes and num(n,0,256) then return n end end
 local signatures,character,account,ids={},{},{},{};local observed
 for pass=1,2 do
  local n=size()
  if not n or (observed and n~=observed) then return nil,"Currency view changed or unavailable." end
  observed=n
  for i=1,n do
   local called,info=pcall(get,i)
   if not called then return nil,"Currency row unavailable." end
   local signature,entry,accountWide=row(info)
   if not signature then return nil,entry end
   if pass==1 then
    signatures[i]=signature
    if entry then
     if ids[entry.id] then return nil,"Duplicate currency ID." end
     ids[entry.id]=true
     local target=accountWide and account or character
     target[#target+1]=entry
     if #character+#account>200 then return nil,"Currency entry limit reached." end
    end
   elseif signatures[i]~=signature then return nil,"Currency view changed." end
  end
  if size()~=n then return nil,"Currency view changed." end
 end
 local function sort(t) table.sort(t,function(a,b) return a.id<b.id end) end
 sort(character);sort(account)
 return {rows=observed,char=character,account=account}
end
local function same(a,b,kind)
 if not a or not b or a.build~=b.build then return false end
 if kind=="gold" then return a.copper==b.copper end
 if a.rows~=b.rows or a.scope~=b.scope or #a.values~=#b.values then return false end
 for i=1,#a.values do if a.values[i].id~=b.values[i].id or a.values[i].quantity~=b.values[i].quantity then return false end end
 return true
end
local function append(history,record,kind)
 local prev=history[#history]
 if prev and same(prev,record,kind) then return false,"unchanged" end
 if prev and record.at<=prev.at then return false,"same-second" end
 history[#history+1]=record
 if #history>20 then table.remove(history,1) end
 return true
end
local function enabled(flag)
 if not ready() then return false end
 local source=MclarionWowWealthData
 if sec(source) or source==nil or not validate(source) then return false end
 return rawget(rawget(source,"settings"),flag)==true
end
function MclarionWow_GoldAutoEnabled() local ok,v=pcall(enabled,"autoGoldCapture");return ok and v or false end
function MclarionWow_CurrencyAutoEnabled() local ok,v=pcall(enabled,"autoCurrencyCapture");return ok and v or false end
local function setFlag(flag,value)
 if not ready() or sec(value) or type(value)~="boolean" then return nil,"Wealth setting unavailable." end
 local root,why=candidate(MclarionWowWealthData)
 if not root then return nil,why end
 if root.settings[flag]==value then return true end
 root.settings[flag]=value
 if not validate(root) then return nil,"Wealth storage format refused." end
 local ok,reason=budget(root)
 if not ok then return nil,reason end
 if not validate(root) then return nil,"Wealth storage format refused." end
 MclarionWowWealthData=root
 return true
end
function MclarionWow_SetAutoGoldCapture(value) local ok,v,why=pcall(setFlag,"autoGoldCapture",value);if not ok then return nil,"Wealth setting unavailable." end;return v,why end
function MclarionWow_SetAutoCurrencyCapture(value) local ok,v,why=pcall(setFlag,"autoCurrencyCapture",value);if not ok then return nil,"Wealth setting unavailable." end;return v,why end
local function capture(kind,manual)
 if not ready() or sec(manual) or type(manual)~="boolean" then return nil,"Wealth capture mode unavailable." end
 local owner,stamp,build,why=context()
 if not owner then return nil,why end
 local root,reason,owners=candidate(MclarionWowWealthData)
 if not root then return nil,reason end
 local flag=kind=="gold" and "autoGoldCapture" or "autoCurrencyCapture"
 if not manual and not root.settings[flag] then return nil,"Automatic wealth capture is off." end
 local view,record
 if kind=="gold" then
  local fn=GetMoney
  if sec(fn) or type(fn)~="function" then return nil,"Money API unavailable." end
  local called,copper=pcall(fn)
  if not called or not num(copper,0,9007199254740991) then return nil,"Money balance unavailable." end
  record={at=stamp,build=build,copper=copper}
 else view,reason=scan();if not view then return nil,reason end end
 local still,_,_,check=context()
 if not still or still~=owner then return nil,check or "Wealth owner changed." end
 local group=root.characters[owner]
 if not group and owners>=256 then return nil,"Wealth owner limit reached." end
 if kind=="gold" then
  group=group or {};local h=group.gold or {}
  local added,status=append(h,record,"gold")
  if not added then return true,status end
  group.gold=h;root.characters[owner]=group
 else
  group=group or {};local h=group.currency or {}
  local c={at=stamp,build=build,scope="visible-ui",rows=view.rows,values=view.char}
  local a={at=stamp,build=build,scope="visible-ui",rows=view.rows,values=view.account,observedBy=owner}
  local changed,status=append(h,c,"currency")
  local accountChanged,accountStatus=append(root.accountCurrency,a,"account")
  if changed then group.currency=h;root.characters[owner]=group end
  if not changed and not accountChanged then
   if status=="same-second" or accountStatus=="same-second" then return true,"same-second" end
   return true,"unchanged"
  end
 end
 if not validate(root) then return nil,"Wealth storage format refused." end
 local allowed,budgetReason=budget(root)
 if not allowed then return nil,budgetReason end
 if not validate(root) then return nil,"Wealth storage format refused." end
 local final,_,_,finalReason=context()
 if not final or final~=owner then return nil,finalReason or "Wealth owner changed." end
 MclarionWowWealthData=root
 return true,"saved"
end
function MclarionWow_CaptureGold(manual) local ok,v,why=pcall(capture,"gold",manual);if not ok then return nil,"Gold capture unavailable." end;return v,why end
function MclarionWow_CaptureCurrency(manual) local ok,v,why=pcall(capture,"currency",manual);if not ok then return nil,"Currency capture unavailable." end;return v,why end
