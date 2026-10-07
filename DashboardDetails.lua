-- Read-only latest validated SavedVariables detail, never a scan or raw wire dump.
-- Each call returns at most 32768 bytes; omitted rows end in an explicit truncation notice.
local MAX, BIG, TIME, LIMIT = 2147483647, 9007199254740991, 253402300799, 32768
local function safe(v)
 local ok,s=pcall(issecretvalue,v)
 if not ok or type(s)~="boolean" or s then return false end
 if type(v)=="table" then
  ok,s=pcall(issecrettable,v)
  if not ok or type(s)~="boolean" or s then return false end
 end
 return true
end
local function plain(t)
 if not safe(t) or type(t)~="table" then return false end
 local ok,m=pcall(getmetatable,t)
 return ok and safe(m) and m==nil
end
local function number(v,lo,hi)
 return safe(v) and type(v)=="number" and v>=lo and v<=hi and v==math.floor(v)
end
local function owner(v)
 return safe(v) and type(v)=="string" and #v>=11 and #v<=77 and v:match("^Player%-[A-Za-z0-9%-]+$")~=nil
end
local function decimal(s,lo,hi)
 if type(s)~="string" or #s>16 or (s~="0" and not s:match("^[1-9]%d*$")) then return nil end
 local n=tonumber(s)
 if number(n,lo,hi) and tostring(n)==s then return n end
end
local function signed(s)
 if type(s)~="string" or #s>11 or not s:match("^%-?%d+$") or s=="-0" or s:match("^%-?0%d") then return nil end
 local n=tonumber(s)
 if number(n,-MAX,MAX) and tostring(n)==s then return n end
end
local function split(s,sep,cap)
 local out,start={},1
 while true do
  if #out>=cap then return nil end
  local p=s:find(sep,start,true)
  if not p then out[#out+1]=s:sub(start);return out end
  out[#out+1]=s:sub(start,p-1);start=p+#sep
 end
end
local function list(t,cap,empty)
 if not plain(t) then return nil end
 local n=0
 for k,v in pairs(t) do
  if not number(k,1,cap) or not safe(v) then return nil end
  n=n+1;if n>cap then return nil end
 end
 if n==0 and not empty then return nil end
 for i=1,n do if rawget(t,i)==nil then return nil end end
 return n
end
local function root(global,field,schema)
 if not plain(global) or not safe(rawget(global,"schema")) or rawget(global,"schema")~=schema then return nil end
 local map=rawget(global,field)
 if not plain(map) then return nil end
 return map
end
local function legacy(field)
 local r=MclarionWowData
 if not plain(r) then return nil end
 local schema=rawget(r,"schema")
 if not safe(schema) or (schema~=1 and schema~=2) or (field=="items" and schema~=2) then return nil end
 return plain(rawget(r,field)) and rawget(r,field) or nil
end
local function wire(v,guid,tag,fields,size,build)
 if not safe(v) or type(v)~="string" or #v>size then return nil end
 local f=split(v,"|",fields)
 if not f or #f~=fields or f[1]~=tag or f[2]~="forever" or f[4]~=guid or
    not decimal(f[3],1,TIME) or not decimal(f[build or 5],1,MAX) then return nil end
 return tonumber(f[3]),f
end
local function history(records,cap,parse)
 if records==nil then return nil,"no observation" end
 local n=list(records,cap,false)
 if not n then return nil,"unavailable" end
 local previous=0
 for i=1,n do
  local stamp=parse(rawget(records,i))
  if not stamp or stamp<=previous then return nil,"unavailable" end
  previous=stamp
 end
 local _,latest=parse(rawget(records,n))
 return n,latest
end
-- Text from saved records is data, not WoW color/link/texture control syntax.
local function display(s)
 s=s:gsub("Player%-[A-Za-z0-9%-]+","[redacted identifier]")
 return (s:gsub("[%c|]",function(c)
  if c=="|" then return "||" end
  return string.format("\\x%02X",string.byte(c))
 end))
end
local function percent(s,cap)
 if #s>cap*3 then return nil end
 local at=s:find("%",1,true)
 while at do
  local token=s:sub(at+1,at+2)
  if token~="25" and token~="7C" then return nil end
  at=s:find("%",at+3,true)
 end
 local decoded=s:gsub("%%(..)",function(token)return token=="25" and "%" or "|" end)
 if #decoded>cap then return nil end
 return display(decoded)
end
local function hex(s,cap,nonempty)
 if #s>cap*2 or #s%2~=0 or not s:match("^[0-9A-F]*$") or (nonempty and s=="") then return nil end
 return display((s:gsub("..",function(h)return string.char(tonumber(h,16)) end)))
end
local function rows(text,sep,cap,parse)
 if text=="" then return {} end
 if text:sub(1,1)==sep or text:sub(-1)==sep or text:find(sep..sep,1,true) then return nil end
 local parts=split(text,sep,cap)
 if not parts then return nil end
 local out,prev={},0
 for _,p in ipairs(parts) do
  local row,id=parse(p)
  if not row or (id and id<=prev) then return nil end
  prev=id or prev;out[#out+1]=row
 end
 return out
end
local function render(key,guid)
 local lines={}
 local function add(s) lines[#lines+1]=s end
 local function header(at,build,n)
  add("Latest saved observation: server time "..at.."; build "..build..".")
  if n then add(n.." retained observations (latest values below; not cumulative).") end
 end
 if key=="character" or key=="bags" or key=="bank" then
  local map=legacy(key=="character" and "characters" or key)
  if not map then return "unavailable" end
  local function parse(record)
   local at,f,tag
   if key=="character" then
    at,f=wire(record,guid,"MHWOW1",12,4096,12);tag="MHWOW1"
    if not at then at,f=wire(record,guid,"MHWOW2",15,4096,12);tag="MHWOW2" end
   else tag=key=="bags" and "MHWOWB1" or "MHWOWK1";at,f=wire(record,guid,tag,6,key=="bags" and 16000 or 32768,6) end
   if not at then return nil end
   local out={at=at,build=f[key=="character" and 12 or 6]}
   if key=="character" then
    out.name,out.realm,out.zone=percent(f[5],80),percent(f[6],80),percent(f[10],160)
    out.class=f[7];out.level=decimal(f[8],1,MAX);out.map=decimal(f[9],0,MAX)
    if not out.name or out.name=="" or not out.realm or not out.class:match("^[A-Z_]+$") or
       #out.class>32 or not out.level or not out.map or not out.zone or out.zone=="" then return nil end
    local gear=split(f[11],",",19)
    if not gear or #gear~=19 then return nil end
    out.gear={}
    for i=1,19 do out.gear[i]=decimal(gear[i],0,MAX);if not out.gear[i] then return nil end end
    if tag=="MHWOW2" then
     if f[13]~="Alliance" and f[13]~="Horde" and f[13]~="Neutral" then return nil end
     if #f[14]<2 or #f[14]>32 or not f[14]:match("^[A-Za-z]+$") or
        (f[15]~="Male" and f[15]~="Female" and f[15]~="Unknown") then return nil end
     out.identity=f[13].." / "..f[14].." / "..f[15]
    end
   else
    local previousTab,previousId=0,0
    out.entries=rows(f[5],",",key=="bags" and 128 or 1080,function(part)
     if key=="bags" then
      local a,b=part:match("^([^:]+):([^:]+)$")
      local id,q=decimal(a,1,MAX),decimal(b,1,BIG)
      if id and q then return "item ID "..id..": "..q,id end
     else
      local a,b,c=part:match("^([^:]+):([^:]+):([^:]+)$")
      local tab,id,q=decimal(a,6,14),decimal(b,1,MAX),decimal(c,1,BIG)
      if tab and id and q and (tab>previousTab or (tab==previousTab and id>previousId)) then
       previousTab,previousId=tab,id
       return {tab=tab,id=id,quantity=q}
      end
     end
    end)
    if not out.entries then return nil end

   end
   return at,out
  end
  local n,latest=history(rawget(map,guid),20,parse)
  if not n then return latest end
  header(latest.at,latest.build,n)
  if key=="character" then
   add("Name "..latest.name.."; realm "..latest.realm.."; class "..latest.class.."; level "..latest.level.."; map ID "..latest.map.."; zone "..latest.zone..".")
   add("Faction / race / gender: "..(latest.identity or "not captured in MHWOW1")..".")
   for i,id in ipairs(latest.gear) do add("Equipped slot "..i..": "..(id==0 and "empty" or "item ID "..id)..".") end
  elseif key=="bags" then
   add("Own bags: aggregated IDs and quantities, not slots. "..#latest.entries.." item types.")
   for _,v in ipairs(latest.entries) do add(v) end
  else
   add("Own character bank: aggregated IDs and quantities by tab; empty tabs not encoded.")
   for _,v in ipairs(latest.entries) do add("tab "..v.tab.." item ID "..v.id..": "..v.quantity) end
  end
 elseif key=="items" then
  local map=legacy("items")
  if not map then return "unavailable" end
  local group=rawget(map,guid)
  if group==nil then return "no observation" end
  if not plain(group) then return "unavailable" end
  local function metadata(record)
   local at,f=wire(record,guid,"MHWOWI1",7,32768)
   if not at or not f[6]:match("^[a-z][a-z][A-Z][A-Z]$") or f[7]=="" then return nil end
   local parts=split(f[7],";",128)
   if not parts then return nil end
   local out,prev={},0
   for _,part in ipairs(parts) do
    local p=split(part,":",19)
    if not p or #p~=19 then return nil end
    local id=decimal(p[1],1,MAX)
    if not id or id<=prev then return nil end
    prev=id
    local text={}
    for _,i in ipairs({2,3,7,8,10,19}) do
     text[i]=hex(p[i],i==2 and 160 or (i==3 or i==19) and 512 or i==10 and 64 or 160,i==2)
     if not text[i] then return nil end
    end
    local nums={}
    for _,i in ipairs({4,5,6,9,11,12,13,14,15,16}) do nums[i]=decimal(p[i],0,MAX);if not nums[i] then return nil end end
    nums[17]=p[17]=="" and nil or decimal(p[17],0,MAX)
    if p[17]~="" and not nums[17] or (p[18]~="0" and p[18]~="1") then return nil end
    out[#out+1]="item ID "..id..": "..text[2].."; link "..text[3].."; quality "..nums[4].."; level "..nums[5].."; required level "..nums[6].."; class "..text[7].."; subclass "..text[8].."; stack "..nums[9].."; equip location "..text[10].."; texture ID "..nums[11].."; sell price "..nums[12].."; class ID "..nums[13].."; subclass ID "..nums[14].."; bind "..nums[15].."; expansion "..nums[16].."; set ID "..(nums[17] or "unknown").."; reagent "..(p[18]=="1" and "yes" or "no").."; description "..text[19].."."
   end
   return {at=at,build=f[5],locale=f[6],entries=out}
  end
  local bag=rawget(group,"bags")
  if bag==nil then add("Bags/gear metadata: no observation.")
  else
   local m=metadata(bag)
   if not m then add("Bags/gear metadata: unavailable.") else
    add("Bags/gear metadata latest saved: server time "..m.at.."; build "..m.build.."; locale "..m.locale.."; "..#m.entries.." cached IDs.")
    for _,v in ipairs(m.entries) do add(v) end
   end
  end
  local bank=rawget(group,"bank")
  if bank==nil then add("Bank metadata: no observation.") else
   local n=list(bank,9,false)
   if not n then add("Bank metadata: unavailable.") else
    local pages={}
    for i=1,n do pages[i]=metadata(rawget(bank,i));if not pages[i] then break end end
    if #pages~=n then add("Bank metadata: unavailable.") else
     for i,page in ipairs(pages) do
      add("Bank metadata page "..i.." latest saved: server time "..page.at.."; build "..page.build.."; locale "..page.locale.."; "..#page.entries.." cached IDs (page is not a bank tab).")
      for _,v in ipairs(page.entries) do add(v) end
     end
    end
   end
  end
 elseif key=="quest" or key=="reputation" then
  local q=key=="quest"
  local map=root(q and MclarionWowQuestData or MclarionWowReputationData,"characters",1)
  if not map then return "unavailable" end
  local function parse(record)
   local at,f=wire(record,guid,q and "MHWOWQ1" or "MHWOWR1",q and 9 or 11,q and 4096 or 32768)
   if not at or f[6]~=(q and "active-log" or "visible-ui") then return nil end
   local count=decimal(f[7],0,q and 128 or 256)
   local leaves=decimal(f[8],0,q and 100 or 200)
   if not count or not leaves or leaves>count then return nil end
   local h,c
   if not q then
    h,c=decimal(f[9],0,256),decimal(f[10],0,256)
    if not h or not c or leaves+h>count or leaves+c>count then return nil end
   end
   local text=f[q and 9 or 11]
   local out={}
   if text~="" then
    local parts=split(text,q and "," or ";",q and 100 or 200)
    if not parts or #parts~=leaves then return nil end
    local prior=0
    for _,p in ipairs(parts) do
     local id
     if q then id=decimal(p,1,MAX);out[#out+1]="active quest ID "..(id or "?")
     else
      local v=split(p,":",5)
      if not v or #v~=5 then return nil end
      id=decimal(v[1],1,MAX)
      local standing=decimal(v[2],1,16)
      local minimum,maximum,value=signed(v[3]),signed(v[4]),signed(v[5])
      if not standing or not minimum or not maximum or not value or minimum>=maximum or value<minimum or value>maximum then return nil end
      out[#out+1]="faction ID "..(id or "?")..": standing "..standing.."; minimum "..minimum.."; maximum "..maximum.."; value "..value
     end
     if not id or id<=prior then return nil end
     prior=id
    end
   elseif leaves~=0 then return nil end
   return at,{at=at,build=f[5],rows=count,leaves=leaves,headers=h,collapsed=c,entries=out}
  end
  local n,m=history(rawget(map,guid),20,parse)
  if not n then return m end
  header(m.at,m.build,n)
  add(q and ("Active quest IDs only; "..m.rows.." UI rows; "..m.leaves.." active leaves (not completion history).") or
   ("Visible character-provenance faction leaves only; "..m.rows.." UI rows; "..m.leaves.." leaves; headers "..m.headers.."; collapsed "..m.collapsed.." (partial view)."))
  for _,v in ipairs(m.entries) do add(v) end
 elseif key=="gold" or key=="currency" then
  local r=MclarionWowWealthData
  local map=root(r,"characters",1)
  if not map or not plain(rawget(r,"accountCurrency")) then return "unavailable" end
  local group=rawget(map,guid)
  if group~=nil and not plain(group) then return "unavailable" end
  local function parse(record,account)
   if not plain(record) then return nil end
   local at,build=rawget(record,"at"),rawget(record,"build")
   if not number(at,1,TIME) or not number(build,1,MAX) then return nil end
   if key=="gold" then
    local copper=rawget(record,"copper")
    if not number(copper,0,BIG) then return nil end
    return at,{at=at,build=build,copper=copper}
   end
   local scope,rows,observer=rawget(record,"scope"),rawget(record,"rows"),rawget(record,"observedBy")
   if not safe(scope) or scope~="visible-ui" or not number(rows,0,256) or not safe(observer) or
      (account and not owner(observer)) or (not account and observer~=nil) then return nil end
   local values=rawget(record,"values")
   local count=list(values,200,true)
   if not count or count>rows then return nil end
   local out,prev={},0
   for i=1,count do
    local entry=rawget(values,i)
    if not plain(entry) then return nil end
    local id,q=rawget(entry,"id"),rawget(entry,"quantity")
    if not number(id,1,MAX) or id<=prev or not number(q,0,BIG) then return nil end
    prev=id;out[#out+1]="currency ID "..id..": "..q
   end
   return at,{at=at,build=build,rows=rows,entries=out,observer=observer}
  end
  local records=group and rawget(group,key=="gold" and "gold" or "currency")
  local n,m=history(records,20,function(v)return parse(v,false) end)
  if key=="gold" then
   if not n then return m end
   header(m.at,m.build,n)
   local c=m.copper
   add("Current saved balance: "..c.." copper ("..math.floor(c/10000).."g "..math.floor(c%10000/100).."s "..(c%100).."c). Not transactions.")
  else
   local function section(title,count,record)
    if not count then add(title..": "..record..".");return end
    add(title..": "..count.." retained observations; latest server time "..record.at.."; build "..record.build.."; visible UI rows "..record.rows.."; "..#record.entries.." captured balances (partial view).")
    for _,v in ipairs(record.entries) do add(v) end
   end
   section("Character currency",n,m)
   local account=rawget(r,"accountCurrency")
   local size=list(account,20,true)
   if not size then add("Account-wide currency: unavailable.")
   elseif size==0 then add("Account-wide currency: no observation.")
   else
    local count,latest=history(account,20,function(v)return parse(v,true) end)
    if not count then add("Account-wide currency: unavailable.")
    elseif latest.observer~=guid then add("Account-wide currency: unavailable (latest observed by other character).")
    else section("Account-wide currency (observed by current character)",count,latest) end
   end
  end
 elseif key=="honor" or key=="title" then
  local map=root(MclarionWowHonorTitleData,"characters",1)
  if not map then return "unavailable" end
  local group=rawget(map,guid)
  if group==nil then return "no observation" end
  if not plain(group) then return "unavailable" end
  local function parse(record)
   local h=key=="honor"
   local at,f=wire(record,guid,h and "MHWOWH1" or "MHWOWT1",h and 15 or 8,4096)
   if not at then return nil end
   local m={at=at,build=f[5]}
   if h then
    m.values={}
    for i=6,15 do m.values[i]=decimal(f[i],0,(i==7 or i==12 or i==15) and 64 or MAX);if not m.values[i] then return nil end end
    if m.values[12]>m.values[15] or m.values[13]>m.values[14] then return nil end
   else
    m.selected=decimal(f[7],0,512)
    if not m.selected then return nil end
    m.ids={}
    if f[8]~="" then
     local ids=split(f[8],",",512)
     if not ids then return nil end
     local prior,found=0,false
     for _,v in ipairs(ids) do
      local id=decimal(v,1,512)
      if not id or id<=prior then return nil end
      if id==m.selected then found=true end
      prior=id;m.ids[#m.ids+1]=id
     end
     m.found=found
    end
    if (m.selected==0 and f[6]~="none") or (m.selected>0 and (f[6]~="active:"..m.selected or not m.found)) then return nil end
   end
   return at,m
  end
  local n,m=history(rawget(group,key),20,parse)
  if not n then return m end
  header(m.at,m.build,n)
  if key=="honor" then
   local names={"lifetime honorable kills","max PvP rank","session honorable kills","session dishonorable kills","yesterday honorable kills","yesterday dishonorable kills","faction-2800 renown level","faction-2800 reputation earned","faction-2800 level threshold","faction-2800 max level"}
   for i=6,15 do add(names[i-5].." "..m.values[i]) end
   add("Supported captured counters only; not total honor earned or a kill ledger.")
  else
   add("Known title IDs: "..(#m.ids==0 and "none" or table.concat(m.ids,", "))..".")
   add(m.selected==0 and "No title selected." or "Selected title ID "..m.selected..".")
   add("No acquisition dates captured.")
  end
 end
 return lines
end
local allowed={character=true,bags=true,bank=true,items=true,combat=true,quest=true,reputation=true,gold=true,currency=true,honor=true,title=true}
local function details(key)
 if not safe(key) or type(key)~="string" or #key>20 or not allowed[key] then return "Details unavailable." end
 if key=="combat" then return "Combat: native WoW file; no addon observations, event records or saved count. Only the auto-start preference is stored." end
 if type(issecretvalue)~="function" or type(issecrettable)~="function" then return key..": unavailable" end
 local fn=UnitGUID
 if not safe(fn) or type(fn)~="function" then return key..": unavailable" end
 local ok,guid=pcall(fn,"player")
 if not ok or not owner(guid) then return key..": unavailable" end
 local result=render(key,guid)
 if type(result)=="string" then return key..": "..result end
 local out,used={},0
 local notice="\n[Truncated at 32768 bytes; additional saved values omitted.]"
 for _,line in ipairs(result) do
  if type(line)~="string" then return key..": unavailable" end
  local part=(#out==0 and "" or "\n")..line
  if used+#part>LIMIT then
   while #out>0 and used+#notice>LIMIT do used=used-#out[#out];out[#out]=nil end
   if #out==0 then return key..": unavailable" end
   return table.concat(out)..notice
  end
  out[#out+1]=part;used=used+#part
 end
 return #out==0 and key..": no observation" or table.concat(out)
end
function MclarionWow_DashboardDetails(key)
 local ok,result=pcall(details,key)
 if not ok or type(result)~="string" or #result>LIMIT then return "Details unavailable." end
 return result
end
