-- Synthetic SavedVariables only. Run with Lua 5.1 and 5.4.
local source = "DashboardSummary.lua"
local f = io.open(source, "r")
if not f then source = "../DashboardSummary.lua" else f:close() end
assert(loadfile(source))()
local A, B = "Player-1-AAAA", "Player-2-BBBB"
local guid = A
UnitGUID = function(unit) assert(unit == "player"); return guid end
issecretvalue = function(v) return type(v) == "table" and v.__secret == true end
issecrettable = function(v) return v.__secret == true end
local function reset()
    guid=A
    MclarionWowData={schema=2,characters={},bags={},bank={},items={}}
    MclarionWowQuestData={schema=1,characters={}}
    MclarionWowReputationData={schema=1,characters={}}
    MclarionWowWealthData={schema=1,characters={},accountCurrency={}}
    MclarionWowHonorTitleData={schema=1,characters={}}
end
local function check(key, parts)
    local result=MclarionWow_DashboardSummary(key)
    assert(type(result)=="string" and #result<=240, key .. " length/type")
    assert(not result:find("Player%-") and not result:find("AAAA"), key .. " leaked identifier")
    for _,part in ipairs(parts) do assert(result:find(part,1,true),key.." missing "..part..": "..result) end
    return result
end
local function gear(id)
    local a={}; for i=1,19 do a[i]="0" end; if id then a[1]=tostring(id) end
    return table.concat(a,",")
end
local function character(owner,stamp,id)
    return table.concat({"MHWOW1","forever",stamp,owner,"Synthetic","TestRealm","MAGE","60","1","TestZone",gear(id),"70205"},"|")
end
local function item(id)
    return table.concat({id,"53796E746865746963","",1,60,1,"","",1,"",1,0,0,0,0,0,"",0,""},":")
end
local function meta(owner,entries)
    return table.concat({"MHWOWI1","forever","100",owner,"70205","enUS",entries},"|")
end
reset()
check("character",{"no observation"})
MclarionWowData.characters[B]={character(B,100,9)}
check("character",{"no observation"})
MclarionWowData.characters[A]={character(A,100,9),character(A,101,nil)}
check("character",{"2 observations","0 equipped"})
MclarionWowData.bags[A]={"MHWOWB1|forever|100|"..A.."|10:4|70205", "MHWOWB1|forever|101|"..A.."|10:2,20:3|70205"}
check("bags",{"2 observations","2 types","5 units"})
MclarionWowData.bank[A]={"MHWOWK1|forever|100|"..A.."|6:10:2,8:20:4|70205"}
check("bank",{"1 observation","2 tabs with items","2 types","6 units"})
MclarionWowData.items[A]={bags=meta(A,item(10)..";"..item(20)),bank={meta(A,item(10)),meta(A,item(20))}}
check("items",{"bags/gear 2 cached","bank 2 cached"})
check("combat",{"native file","no addon observations"})
MclarionWowQuestData.characters[A]={"MHWOWQ1|forever|100|"..A.."|70205|active-log|3|2|10,20"}
check("quest",{"1 observation","2 active quest IDs"})
MclarionWowReputationData.characters[A]={"MHWOWR1|forever|100|"..A.."|70205|visible-ui|2|1|0|0|10:4:0:3000:100"}
check("reputation",{"1 observation","1 visible character faction leaf"})
MclarionWowWealthData.characters[A]={gold={{at=100,build=70205,copper=12345}},currency={{at=101,build=70205,scope="visible-ui",rows=3,values={{id=10,quantity=0},{id=20,quantity=4}}}}}
MclarionWowWealthData.accountCurrency={{at=101,build=70205,scope="visible-ui",rows=3,values={{id=30,quantity=2}},observedBy=A}}
check("gold",{"1 observation","1g 23s 45c"})
check("currency",{"character: 2 visible entries","account-wide: 1 visible entry","observed by current character"})
MclarionWowHonorTitleData.characters[A]={honor={"MHWOWH1|forever|100|"..A.."|70205|100|2|3|0|4|0|5|6|10|9"},title={"MHWOWT1|forever|100|"..A.."|70205|active:2|2|1,2"}}
check("honor",{"1 observation","100 lifetime honorable kills"})
check("title",{"1 observation","2 known titles","selected"})
-- A newer account-wide observation by someone else must not be attributed to this character.
MclarionWowWealthData.accountCurrency[2]={at=102,build=70205,scope="visible-ui",rows=3,values={},observedBy=B}
check("currency",{"account-wide: unavailable","other character"})
MclarionWowWealthData.accountCurrency={}
check("currency",{"account-wide: no observation"})
-- A schema-valid empty observation is zero, whereas missing and malformed are unavailable.
MclarionWowData.bags[A]={"MHWOWB1|forever|101|"..A.."||70205"}
check("bags",{"0 types","0 units"})
MclarionWowData.bank[A]={"MHWOWK1|forever|101|"..A.."||70205"}
check("bank",{"0 tabs with items","0 types","0 units"})
MclarionWowQuestData.characters[A]={"MHWOWQ1|forever|100|"..A.."|70205|active-log|0|0|"}
check("quest",{"0 active quest IDs"})
MclarionWowHonorTitleData.characters[A].title={"MHWOWT1|forever|101|"..A.."|70205|none|0|"}
check("title",{"0 known titles","none selected"})
MclarionWowData.characters[A]={[1]=character(A,100,9),[3]=character(A,101,10)}
check("character",{"unavailable"})
MclarionWowData.bags[A]={"MHWOWB1|forever|100|"..B.."|10:1|70205"}
check("bags",{"unavailable"})
MclarionWowData.bank[A]={"MHWOWK1|forever|100|"..A.."|15:10:1|70205"}
check("bank",{"unavailable"})
MclarionWowData.items[A].bank={[1]=meta(A,item(10)),[3]=meta(A,item(20))}
check("items",{"bank unavailable"})
MclarionWowWealthData.characters[A].gold[1].copper=-2
check("gold",{"unavailable"})
MclarionWowHonorTitleData.characters[A].honor[1]="MHWOWH1|forever|100|"..A.."|70205|bad"
check("honor",{"unavailable"})
-- Protected sentinels must be checked before indexing, comparison or formatting.
local sentinel=setmetatable({__secret=true},{__index=function() error("protected index") end,__lt=function() error("protected compare") end,__tostring=function() error("protected format") end})
MclarionWowData.items=sentinel
check("items",{"unavailable"})
guid=sentinel
for _,key in ipairs({"character","bags","bank","items","quest","reputation","gold","currency","honor","title"}) do check(key,{"unavailable"}) end
UnitGUID=nil
check("character",{"unavailable"})
issecretvalue=nil
check("character",{"unavailable"})
issecretvalue = function(v) return type(v) == "table" and v.__secret == true end
UnitGUID = function(unit) assert(unit == "player"); return guid end
-- No capture/scan API is called; all roots remain referentially unchanged.
reset()
MclarionWowData.characters[B]={character(B,100,9)}
MclarionWowData.bags[B]={"MHWOWB1|forever|100|"..B.."|10:5|70205"}
MclarionWowData.bank[B]={"MHWOWK1|forever|100|"..B.."|6:10:5|70205"}
MclarionWowData.items[B]={bags=meta(B,item(10))}
MclarionWowQuestData.characters[B]={"MHWOWQ1|forever|100|"..B.."|70205|active-log|1|1|10"}
MclarionWowReputationData.characters[B]={"MHWOWR1|forever|100|"..B.."|70205|visible-ui|1|1|0|0|10:4:0:3000:100"}
MclarionWowWealthData.characters[B]={gold={{at=100,build=70205,copper=100}},currency={{at=100,build=70205,scope="visible-ui",rows=1,values={{id=10,quantity=2}}}}}
MclarionWowWealthData.accountCurrency={{at=100,build=70205,scope="visible-ui",rows=1,values={{id=10,quantity=2}},observedBy=B}}
MclarionWowHonorTitleData.characters[B]={honor={"MHWOWH1|forever|100|"..B.."|70205|100|2|3|0|4|0|5|6|10|9"},title={"MHWOWT1|forever|100|"..B.."|70205|none|0|"}}
for _,key in ipairs({"character","bags","bank","items","quest","reputation","gold","honor","title"}) do check(key,{"no observation"}) end
check("currency",{"character: no observation","account-wide: unavailable"})
local preserved=MclarionWowData.bags[B][1]
C_Container={GetContainerNumSlots=function() error("scan forbidden") end}
C_QuestLog={GetInfo=function() error("scan forbidden") end}
GetMoney=function() error("scan forbidden") end
for _,key in ipairs({"character","bags","bank","items","combat","quest","reputation","gold","currency","honor","title"}) do check(key,{}) end
assert(MclarionWowData.bags[B][1]==preserved)
reset()
local roots={MclarionWowData,MclarionWowQuestData,MclarionWowReputationData,MclarionWowWealthData,MclarionWowHonorTitleData}
for _,key in ipairs({"character","bags","bank","items","combat","quest","reputation","gold","currency","honor","title"}) do check(key,{}) end
assert(MclarionWowData==roots[1] and MclarionWowQuestData==roots[2] and MclarionWowReputationData==roots[3] and MclarionWowWealthData==roots[4] and MclarionWowHonorTitleData==roots[5])
assert(not _G.MclarionWow_DashboardSummary("invalid-key"):find("Player%-"))
print("Dashboard summary synthetic tests passed")
