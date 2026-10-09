-- Synthetic data only; run from repository root or tests on Lua 5.1 and 5.4.
local path="DashboardDetails.lua"
local f=io.open(path,"r"); if not f then path="../DashboardDetails.lua" else f:close() end
if _VERSION=="Lua 5.1" then assert(loadfile(path))() else assert(loadfile(path,"t",_G))() end
local A,B="Player-1-AAAA","Player-2-BBBB"
local who=A
UnitGUID=function(u) assert(u=="player");return who end
issecretvalue=function(v) return type(v)=="table" and rawget(v,"__secret")==true end
issecrettable=issecretvalue
local function check(k,yes,no)
 local s=MclarionWow_DashboardDetails(k)
 assert(type(s)=="string" and #s<=32768,k.." output bound")
 assert(not s:find("Player%-") and not s:find("AAAA",1,true) and not s:find("BBBB",1,true),k.." privacy")
 for _,v in ipairs(yes or {}) do assert(s:find(v,1,true),k.." missing "..v.." in "..s) end
 for _,v in ipairs(no or {}) do assert(not s:find(v,1,true),k.." leaked "..v) end
 return s
end
local function reset()
 MclarionWowData={schema=2,characters={},bags={},bank={},items={}}
 MclarionWowQuestData={schema=1,characters={}}
 MclarionWowReputationData={schema=1,characters={}}
 MclarionWowWealthData={schema=1,characters={},accountCurrency={}}
 MclarionWowHonorTitleData={schema=1,characters={}}
 who=A
end
local function wire(tag,at,...) return table.concat({tag,"forever",tostring(at),A,...},"|") end
local function gear() local a={};for i=1,19 do a[i]="0" end;a[1]="42";return table.concat(a,",") end
local function hex(s) return (s:gsub(".",function(c)return string.format("%02X",string.byte(c)) end)) end
local function item(id,name) return table.concat({id,hex(name),hex("|Hbad|h"),2,60,45,hex("Armor"),hex("Plate"),20,hex("INVTYPE_HEAD"),123,99,4,1,2,10,"",1,hex("A|cffff0000red|r\nline")},":") end
local function meta(at,row) return wire("MHWOWI1",at,"70205","enUS",row) end
reset()
local keys={"character","bags","bank","items","combat","quest","reputation","gold","currency","honor","title"}
for _,k in ipairs(keys) do check(k,{k=="combat" and "native" or "no observation"}) end
MclarionWowData.characters[A]={wire("MHWOW1",100,"Older","Realm","MAGE","59","1","Old",gear(),"70204"),wire("MHWOW2",101,"S%7C%7CcBAD","R%25","MAGE","60","2","Zone%7CNew",gear(),"70205","Alliance","Dwarf","Male")}
check("character",{"2 retained observations","101","70205","S||||cBAD","level 60","map ID 2","Zone||New","slot 1: item ID 42","Alliance","Dwarf","Male","Old -> Zone||New"})
for _,text in ipairs({"Bad%2G","Bad%7","Bad%", "Bad%7C%2G"}) do
 MclarionWowData.characters[A][2]=wire("MHWOW2",101,text,"Realm","MAGE","60","2","Zone",gear(),"70205","Alliance","Dwarf","Male")
 check("character",{"unavailable"},{"Name Bad"})
end
MclarionWowData.characters[A][2]=wire("MHWOW2",101,"Literal%252G%25","Realm","MAGE","60","2","Zone",gear(),"70205","Alliance","Dwarf","Male")
check("character",{"Literal%2G%"})
MclarionWowData.bags[A]={wire("MHWOWB1",100,"10:1","70204"),wire("MHWOWB1",101,"10:2,20:3","70205")}
check("bags",{"2 retained observations","item ID 10: 2","item ID 20: 3","101","70205","item ID 10: 1 -> 2"})
for _,entries in ipairs({"10:2,10:3","20:3,10:2"}) do
 MclarionWowData.bags[A][2]=wire("MHWOWB1",101,entries,"70205")
 check("bags",{"unavailable"},{"item ID 10"})
end
MclarionWowData.bags[A][2]=wire("MHWOWB1",101,"10:2,20:3","70205")
MclarionWowData.bank[A]={wire("MHWOWK1",101,"6:10:2,8:10:3,8:20:4","70205")}
check("bank",{"tab 6","item ID 10: 2","tab 8","item ID 10: 3","item ID 20: 4"})
for _,entries in ipairs({"6:10:2,6:10:3","6:20:2,6:10:3","8:10:2,6:20:3"}) do
 MclarionWowData.bank[A][1]=wire("MHWOWK1",101,entries,"70205")
 check("bank",{"unavailable"},{"tab 6 item ID"})
end
MclarionWowData.bank[A][1]=wire("MHWOWK1",101,"6:10:2,8:10:3,8:20:4","70205")
MclarionWowData.items[A]={bags=meta(101,item(10,"Saved|cBad")..";"..item(20,"Second")),bank={meta(102,item(10,"Banked"))}}
check("items",{"Bags/gear","Banked","Second","Saved||cBad","link ||Hbad||h","A||cffff0000red||r\\x0Aline","quality 2","texture ID 123","sell price 99","reagent yes","102","70205"})
MclarionWowQuestData.characters[A]={wire("MHWOWQ1",101,"70205","active-log","3","2","10,20")}
check("quest",{"Active quest IDs","10","20","3 UI rows","101","70205"},{"completed"})
MclarionWowReputationData.characters[A]={wire("MHWOWR1",101,"70205","visible-ui","2","1","0","0","10:4:0:3000:100")}
check("reputation",{"faction ID 10","standing 4","minimum 0","maximum 3000","value 100","Visible","101"})
MclarionWowWealthData.characters[A]={gold={{at=101,build=70205,copper=12345}},currency={{at=101,build=70205,scope="visible-ui",rows=2,values={{id=10,quantity=0},{id=20,quantity=4}}}}}
MclarionWowWealthData.accountCurrency={{at=101,build=70205,scope="visible-ui",rows=1,values={{id=30,quantity=7}},observedBy=A}}
check("gold",{"12345 copper","1g 23s 45c","101","70205"})
check("currency",{"character","currency ID 10: 0","currency ID 20: 4","Account-wide","currency ID 30: 7","observed by current character","101"})
MclarionWowHonorTitleData.characters[A]={honor={wire("MHWOWH1",101,"70205","100","2","3","0","4","0","5","6","10","9")},title={wire("MHWOWT1",101,"70205","active:2","2","1,2")}}
check("honor",{"lifetime honorable kills 100","max PvP rank 2","session honorable kills 3","session dishonorable kills 0","yesterday honorable kills 4","yesterday dishonorable kills 0","faction-2800 renown level 5","reputation earned 6","level threshold 10","max level 9"})
check("title",{"Known title IDs: 1, 2","Selected title ID 2","101"})
MclarionWowWealthData.accountCurrency[2]={at=102,build=70205,scope="visible-ui",rows=1,values={{id=999,quantity=999}},observedBy=B}
check("currency",{"other character","unavailable"},{"999","currency ID 30: 7"})
MclarionWowData.bags[A]={[1]=wire("MHWOWB1",100,"10:1","70205"),[3]=wire("MHWOWB1",101,"10:2","70205")}
check("bags",{"unavailable"},{"item ID 10"})
MclarionWowData.bank[A]={wire("MHWOWK1",101,"15:10:2","70205")}
check("bank",{"unavailable"},{"item ID 10"})
MclarionWowQuestData.characters[A]={wire("MHWOWQ1",101,"70205","active-log","2","2","10")}
check("quest",{"unavailable"},{"quest ID 10"})
local secret=setmetatable({__secret=true},{__index=function() error("secret indexed") end,__len=function() error("secret length") end,__lt=function() error("secret compare") end})
who=secret
for _,k in ipairs(keys) do if k~="combat" then check(k,{"unavailable"}) end end
who=A;MclarionWowData.items=secret;check("items",{"unavailable"})
MclarionWowWealthData.accountCurrency[2].observedBy=secret;check("currency",{"unavailable"},{"999"})
reset()
MclarionWowData.characters[B]={"MHWOW1|forever|100|"..B.."|Other|Realm|MAGE|60|1|Zone|"..gear().."|70205"}
MclarionWowData.bags[B]={"MHWOWB1|forever|100|"..B.."|999:1|70205"}
MclarionWowQuestData.characters[B]={"MHWOWQ1|forever|100|"..B.."|70205|active-log|1|1|999"}
MclarionWowWealthData.accountCurrency={{at=100,build=70205,scope="visible-ui",rows=1,values={{id=999,quantity=999}},observedBy=B}}
check("character",{"no observation"},{"Other"});check("bags",{"no observation"},{"999"})
check("quest",{"no observation"},{"999"});check("currency",{"other character"},{"999"})
MclarionWowData.items[A]={bags=meta(101,item(10,"Valid")),bank={[1]=meta(102,item(20,"Valid")),[3]=meta(103,item(30,"Bad"))}}
check("items",{"Bank metadata: unavailable"},{"item ID 20"})
reset();MclarionWowData.bags[A]={wire("MHWOWB1",101,"10:2","70205")}
MclarionWowData.characters[A]={wire("MHWOW1",101,"Player-1-ABCD","Realm","MAGE","60","1","Zone",gear(),"70205")}
check("character",{"[redacted identifier]"},{A,"Player-1-ABCD"})
C_Container={GetContainerNumSlots=function() error("scan called") end}
GetMoney=function() error("scan called") end
for _,k in ipairs(keys) do check(k) end
assert(MclarionWowData.bags[A][1]==wire("MHWOWB1",101,"10:2","70205"))
local first,second={},{};for i=1,100 do first[i]=item(i,string.rep("Long",10));second[i]=item(i+100,string.rep("Long",10)) end
MclarionWowData.items[A]={bank={meta(101,table.concat(first,";")),meta(102,table.concat(second,";"))}}
local bounded=check("items",{"Truncated"});assert(#bounded<=32768)
-- Read-only metadata overlay is same-build/locale/observer and markup-safe.
if _VERSION=="Lua 5.1" then assert(loadfile("../VaultkeeperMetadata/MetadataCapture.lua"))()
else assert(loadfile("../VaultkeeperMetadata/MetadataCapture.lua","t",_G))() end
reset();GetLocale=function() return "enUS" end
MclarionWowReputationData.characters[A]={wire("MHWOWR1",101,"70205","visible-ui","1","1","0","0","17:4:0:3000:1200")}
VaultkeeperMetadataData={schema=1,records={}}
VaultkeeperMetadataData.records["reputation:17:70205:enUS"]={entityType="reputation",id=17,build=70205,locale="enUS",observedAt=101,observedBy=A,scope="character",name="|cffff0000Guild",description="|Hbad|h"}
check("reputation",{"faction ID 17 — ||cffff0000Guild", "||Hbad||h", "value 1200"},{"faction ID 17: standing"})
local previous=VaultkeeperMetadataData
C_Reputation={GetFactionDataByID=function() error("read-only display called API") end}
check("reputation",{"||cffff0000Guild"});assert(VaultkeeperMetadataData==previous)
VaultkeeperMetadataData.records["reputation:17:70205:enUS"].observedBy=B
check("reputation",{"faction ID 17: standing"},{"Guild"})
VaultkeeperMetadataData.records["reputation:17:70205:enUS"].observedBy=A
GetLocale=function() return "frFR" end
check("reputation",{"faction ID 17: standing"},{"Guild"})
GetLocale=function() return "enUS" end
VaultkeeperMetadataData.bad=true
check("reputation",{"faction ID 17: standing"},{"Guild"})
VaultkeeperMetadataData={schema=1,records={
 ["spell:116:70205:enUS:"..A]={entityType="spell",id=116,build=70205,locale="enUS",observedAt=101,
 observedBy=A,scope="character",name="|cffSpell",description="|Hcast|h",iconFileID=1234,
 descriptionProvenance="player-spellcast:C_Spell.GetSpellDescription"}}}
GetBuildInfo=function() return "1.60.1","70205" end
local spellText=check("spells",{"spell ID 116", "||cffSpell", "||Hcast||h", "not learned spells"})
assert(#spellText<=32768)
GetBuildInfo=function() return "1.60.1","70245" end
check("spells",{"No observed spell metadata"},{"Spell"})
GetBuildInfo=function() return "1.60.1","70205" end
VaultkeeperMetadataData.records["spell:116:70205:enUS:"..A].observedBy=B
check("spells",{"unavailable"},{"Spell"}) -- malformed key/observer pair invalidates the root
VaultkeeperMetadataData.records["spell:116:70205:enUS:"..A].observedBy=A
VaultkeeperMetadataData.records["spell:116:70205:enUS:"..B]={entityType="spell",id=116,build=70205,locale="enUS",observedAt=102,
 observedBy=B,scope="character",name="OtherSpell",description="Other text",
 descriptionProvenance="player-spellcast:C_Spell.GetSpellDescription"}
check("spells",{"||cffSpell"},{"OtherSpell","Other text"})
who=B;check("spells",{"OtherSpell","Other text"},{"||cffSpell","||Hcast||h"})
print("dashboard details synthetic checks passed")
