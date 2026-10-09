-- Saved history is read-only, bounded and character scoped.
local path="DashboardDetails.lua"
local f=io.open(path);if not f then path="../DashboardDetails.lua" else f:close() end
assert(loadfile(path))()
issecretvalue=function(v) return type(v)=="table" and rawget(v,"secret")==true end
issecrettable=issecretvalue
local A,B="Player-1-AAAA","Player-2-BBBB"
local who=A;UnitGUID=function() return who end
local function wire(tag,t,...) return table.concat({tag,"forever",tostring(t),A,...},"|") end
local function gear(first) local a={};for i=1,19 do a[i]="0" end;a[1]=tostring(first);return table.concat(a,",") end
MclarionWowData={schema=2,characters={ [A]={wire("MHWOW1",100,"Name","Realm","MAGE","59","1","Old",gear(42),"70204"),wire("MHWOW1",101,"Name","Realm","MAGE","60","2","New",gear(43),"70205")}},bags={[A]={wire("MHWOWB1",100,"10:2,20:1","70204"),wire("MHWOWB1",101,"10:5,30:1","70205")}},bank={[A]={wire("MHWOWK1",100,"6:10:2,8:20:1","70204"),wire("MHWOWK1",101,"6:10:4,8:30:3","70205")}},items={}}
MclarionWowQuestData={schema=1,characters={[A]={wire("MHWOWQ1",100,"70204","active-log","3","2","10,20"),wire("MHWOWQ1",101,"70205","active-log","3","2","20,30")}}}
MclarionWowReputationData={schema=1,characters={[A]={wire("MHWOWR1",100,"70204","visible-ui","2","2","0","0","10:4:0:3000:100;20:5:0:3000:200"),wire("MHWOWR1",101,"70205","visible-ui","2","2","0","0","10:4:0:3000:150;30:6:0:3000:300")}}}
MclarionWowWealthData={schema=1,characters={[A]={gold={{at=100,build=70204,copper=10000},{at=101,build=70205,copper=12500}},currency={{at=100,build=70204,scope="visible-ui",rows=2,values={{id=10,quantity=2},{id=20,quantity=9}}},{at=101,build=70205,scope="visible-ui",rows=2,values={{id=10,quantity=5},{id=30,quantity=8}}}}}},accountCurrency={{at=100,build=70204,scope="visible-ui",rows=1,values={{id=99,quantity=1}},observedBy=B},{at=101,build=70205,scope="visible-ui",rows=1,values={{id=30,quantity=7}},observedBy=A}}}
MclarionWowHonorTitleData={schema=1,characters={[A]={honor={wire("MHWOWH1",100,"70204","1","2","3","0","4","0","5","6","10","9"),wire("MHWOWH1",101,"70205","2","2","3","0","4","0","5","6","10","9")},title={wire("MHWOWT1",100,"70204","none","0","1"),wire("MHWOWT1",101,"70205","active:1","1","1")}}}}
local function snapshot(v)
 if type(v)~="table" then return type(v)..":"..tostring(v) end
 local keys={};for k in pairs(v) do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
 local out={};for _,k in ipairs(keys) do out[#out+1]=snapshot(k).."="..snapshot(rawget(v,k)) end
 return "{"..table.concat(out,",").."}"
end
local function saved() return snapshot({MclarionWowData,MclarionWowQuestData,MclarionWowReputationData,MclarionWowWealthData,MclarionWowHonorTitleData}) end
local baseline=saved()
local function check(k,index,want,absent)
 local text,count,selected=MclarionWow_DashboardDetails(k,index)
 assert(type(text)=="string" and #text<=32768,k.." bounded")
 for _,s in ipairs(want) do assert(text:find(s,1,true),k.." missing "..s..": "..text) end
 for _,s in ipairs(absent or {}) do assert(not text:find(s,1,true),k.." leaked "..s) end
 return text,count,selected
end
local _,n,i=check("character",nil,{"101","2 retained","level 60","level 59 -> 60","Old -> New","slot 1: item ID 42 -> item ID 43"})
assert(n==2 and i==2)
_,n,i=check("character",1,{"100","Observation 1 of 2","level 59","No earlier retained observation"},{"level 60"});assert(n==2 and i==1)
_,n,i=check("character",100,{"101","Observation 2 of 2"});assert(n==2 and i==2)
check("bags",nil,{"item ID 10: 2 -> 5","item ID 20: 1 -> 0","item ID 30: 0 -> 1"})
check("bank",nil,{"tab 6 item ID 10: 2 -> 4","tab 8 item ID 20: 1 -> 0","tab 8 item ID 30: 0 -> 3"})
check("quest",nil,{"active quest ID 30 added","active quest ID 10 no longer observed","not completion or abandonment"})
check("reputation",nil,{"value 100 -> 150","only IDs observed in both","Partial view"},{"faction ID 20: value 200 -> 0"})
check("gold",nil,{"Balance difference: +2500 copper","not transactions"})
check("currency",nil,{"currency ID 10: 2 -> 5","only IDs observed in both","Account-wide"},{"currency ID 20: 9 -> 0","currency ID 30: 0 -> 8"})
check("currency",1,{"selected server time 100","currency ID 10: 2","Account-wide currency is independently latest-only","observed by current character): 1 retained observation"},{"currency ID 10: 2 -> 5","currency ID 99","observed by current character): 2 retained observations"})
check("honor",nil,{"lifetime honorable kills: 1 -> 2"})
check("title",nil,{"Adjacent selected title ID: 0 -> 1","No acquisition dates"})
for _,k in ipairs({"honor","title"}) do local text,c,j=check(k,1,{"Observation 1 of 2","No earlier retained observation"});assert(c==2 and j==1) end
assert(saved()==baseline,"history browsing never writes observations or settings")
who=B
for _,k in ipairs({"character","bags","bank","quest","reputation","gold","currency","honor","title"}) do check(k,1,{"no observation"},{"Name","item ID 10","quest ID 10","12500"}) end
who=A
MclarionWowQuestData.characters[A][1]=wire("MHWOWQ1",100,"70204","active-log","3","2","10,20")
MclarionWowQuestData.characters[A][2]=wire("MHWOWQ1",101,"70205","active-log","3","2","20,30")
MclarionWowData.bags[A][1]=setmetatable({secret=true},{__index=function() error("secret access") end})
check("bags",1,{"unavailable"},{"item ID"})
local calls=0;GetMoney=function() calls=calls+1;error("scan") end
for _,k in ipairs({"character","bags","bank","quest","reputation","gold","currency","honor","title"}) do MclarionWow_DashboardDetails(k,1) end
assert(calls==0)
local entries={};for i=1,100 do entries[i]=i..":1" end
MclarionWowData.bags[A]={wire("MHWOWB1",100,"","70204"),wire("MHWOWB1",101,table.concat(entries,","),"70205")}
local limited=check("bags",nil,{"[Truncated changes: 36 additional changed entries omitted.]"})
assert(#limited<=32768)
print("dashboard saved-history checks passed")
