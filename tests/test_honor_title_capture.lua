local path = ... or "../HonorTitleCapture.lua"
local checks = 0
local function eq(a,b,label) checks=checks+1; assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function copy(x) if type(x)~="table" then return x end local y={} for k,v in pairs(x) do y[k]=copy(v) end return y end
local function same(a,b) if type(a)~=type(b) then return false end if type(a)~="table" then return a==b end for k,v in pairs(a) do if not same(v,b[k]) then return false end end for k in pairs(b) do if a[k]==nil then return false end end return true end
local secrets=setmetatable({},{__mode="k"})
local danger=setmetatable({},{__index=function() error("secret indexed") end,__eq=function() error("secret compared") end,__lt=function() error("secret ordered") end})
secrets[danger]=true
issecretvalue=function(v) return secrets[v]==true end
issecrettable=function(v) return secrets[v]==true end
InCombatLockdown=function() return false end
local owner="Player-1234-ABCDEF12"; UnitGUID=function() return owner end
local stamp=1720000000; GetServerTime=function() return stamp end
GetBuildInfo=function() return "1.60.1","70205" end
GetPVPLifetimeStats=function() return 100,3 end
GetPVPSessionStats=function() return 4,1 end
GetPVPYesterdayStats=function() return 7,2 end
C_MajorFactions={GetMajorFactionProgressionInfo=function(id) assert(id==2800);return {renownLevel=2,renownReputationEarned=50,renownLevelThreshold=100,maxLevel=14} end}
local active=0; GetCurrentTitle=function() return active end
GetNumTitles=function() return 3 end
IsTitleKnown=function(i) return i==1 or i==3 end
GetTitleName=function(i) return ({[1]="Champion",[3]="Hero"})[i],true end
local budgetCalls=0
MclarionWow_HonorTitleStorageBudget=function(candidate) budgetCalls=budgetCalls+1; return true end
local chunk=assert(loadfile(path)); if setfenv then setfenv(chunk,_G) end; chunk()
local legacy={schema=2,settings={autoCombatLog=true},characters={[owner]={"old"}}}; MclarionWowData=legacy;local original=copy(legacy)
local function refuse(label,fn,reason)
 local before=MclarionWowHonorTitleData;local snapshot=copy(before)
 local safe,a,b=pcall(fn);eq(safe,true,label.." controlled");eq(a,nil,label.." refused");eq(b,reason,label.." fixed reason")
 eq(MclarionWowHonorTitleData,before,label.." identity");eq(same(MclarionWowHonorTitleData,snapshot),true,label.." content")
end
eq(MclarionWow_HonorAutoEnabled(),false,"honor default off");eq(MclarionWow_TitleAutoEnabled(),false,"title default off")
refuse("honor auto off",function() return MclarionWow_CaptureHonor(false) end,"Automatic honor capture is off.")
refuse("title auto off",function() return MclarionWow_CaptureTitle(false) end,"Automatic title capture is off.")
local ok,why=MclarionWow_CaptureHonor(true);eq(ok,true,"manual honor");eq(why,"saved","honor saved")
eq(MclarionWowHonorTitleData.characters[owner].honor[1],"MHWOWH1|forever|1720000000|"..owner.."|70205|100|3|4|1|7|2|2|50|100|14","honor exact semantics")
ok,why=MclarionWow_CaptureTitle(true);eq(ok,true,"manual title");eq(why,"saved","title saved")
eq(MclarionWowHonorTitleData.characters[owner].title[1],"MHWOWT1|forever|1720000000|"..owner.."|70205|none|0|1,3","no title distinct from unavailable; known bounded IDs")
eq(same(legacy,original),true,"legacy untouched")
local root=MclarionWowHonorTitleData;ok,why=MclarionWow_CaptureTitle(true);eq(why,"unchanged","dedup title");eq(MclarionWowHonorTitleData,root,"no rewrite duplicate")
active=3;ok,why=MclarionWow_CaptureTitle(true);eq(why,"same-second","same-second no history");eq(MclarionWowHonorTitleData,root,"same second unchanged")
stamp=stamp+1;ok,why=MclarionWow_CaptureTitle(true);eq(why,"saved","active changes");eq(MclarionWowHonorTitleData.characters[owner].title[2]:match("|active:3|3|1,3$"),"|active:3|3|1,3","active title ID")
local save=GetPVPSessionStats;GetPVPSessionStats=function() return danger,0 end
refuse("protected honor",function() return MclarionWow_CaptureHonor(true) end,"Honor API unavailable.");GetPVPSessionStats=save
local get=GetNumTitles;GetNumTitles=function() return 9999 end
refuse("title cap",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.");GetNumTitles=get
local known=IsTitleKnown;IsTitleKnown=function() return danger end
refuse("protected title result",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.");IsTitleKnown=known
local name=GetTitleName;GetTitleName=function() error("bad") end
refuse("throwing title",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.");GetTitleName=name
local titleCalls=0;GetTitleName=function(i) titleCalls=titleCalls+1;return titleCalls>2 and "Changed" or "Original",true end
refuse("changing title view",function() return MclarionWow_CaptureTitle(true) end,"Title view changed.");GetTitleName=name
local combat=InCombatLockdown;InCombatLockdown=function() return true end
refuse("combat",function() return MclarionWow_CaptureHonor(true) end,"Capture unavailable in combat.");InCombatLockdown=combat
local previous=UnitGUID;UnitGUID=function() return owner end
local calls=0;UnitGUID=function() calls=calls+1;return calls==1 and owner or "Player-1234-OTHER" end
stamp=stamp+1;GetPVPSessionStats=function() return 8,1 end
refuse("owner switch",function() return MclarionWow_CaptureHonor(true) end,"Owner changed.");UnitGUID=previous;GetPVPSessionStats=save
local originalBudget=MclarionWow_HonorTitleStorageBudget
-- The budget callback receives a disposable copy: even an approving callback
-- cannot change a wire record or a setting that will be committed.
stamp=stamp+1
GetPVPSessionStats=function() return 9,1 end
MclarionWow_HonorTitleStorageBudget=function(offered)
 offered.characters[owner].honor[#offered.characters[owner].honor]="broken wire"
 return true
end
refuse("manual honor malformed budget wire",function() return MclarionWow_CaptureHonor(true) end,"Honor/title storage budget refused.")
GetPVPSessionStats=save;active=1
MclarionWow_HonorTitleStorageBudget=function(offered)
 offered.settings.autoHonorCapture="true"
 return true
end
refuse("manual title budget flag type",function() return MclarionWow_CaptureTitle(true) end,"Honor/title storage budget refused.")
active=3
MclarionWow_HonorTitleStorageBudget=function(offered)
 offered.settings.autoTitleCapture=true
 return true
end
refuse("honor preference callback mutation",function() return MclarionWow_SetAutoHonorCapture(true) end,"Honor/title storage budget refused.")
MclarionWow_HonorTitleStorageBudget=function(offered)
 offered.settings.autoTitleCapture="true"
 return true
end
refuse("title preference callback flag type",function() return MclarionWow_SetAutoTitleCapture(true) end,"Honor/title storage budget refused.")
MclarionWow_HonorTitleStorageBudget=originalBudget
local budget=MclarionWow_HonorTitleStorageBudget;MclarionWow_HonorTitleStorageBudget=function() return false end
refuse("combined budget",function() return MclarionWow_SetAutoHonorCapture(true) end,"Honor/title storage budget refused.");MclarionWow_HonorTitleStorageBudget=budget
for _,p in ipairs({"issecretvalue","issecrettable"}) do local old=_G[p];_G[p]=nil
 refuse("missing "..p,function() return MclarionWow_CaptureTitle(true) end,"Honor/title protection unavailable.");_G[p]=old
 _G[p]=function() error("protection failed") end
 refuse("throwing "..p,function() return MclarionWow_SetAutoHonorCapture(true) end,"Honor/title protection unavailable.");_G[p]=old end
local source=MclarionWowHonorTitleData;MclarionWowHonorTitleData=danger
refuse("protected root",function() return MclarionWow_CaptureHonor(true) end,"Honor/title protected value refused.");MclarionWowHonorTitleData=source
ok=MclarionWow_SetAutoHonorCapture(true);eq(ok,true,"honor opt in");eq(MclarionWow_HonorAutoEnabled(),true,"honor enabled");eq(MclarionWow_TitleAutoEnabled(),false,"title independent")
ok=MclarionWow_SetAutoTitleCapture(true);eq(ok,true,"title opt in")
for i=1,23 do stamp=stamp+1; GetPVPSessionStats=function() return 100+i,1 end;ok,why=MclarionWow_CaptureHonor(false);eq(ok,true,"rolling honor "..i);eq(why,"saved","rolling result") end
eq(#MclarionWowHonorTitleData.characters[owner].honor,20,"rolling twenty")
local malformed=copy(MclarionWowHonorTitleData);malformed.characters[owner].honor[21]="bad";MclarionWowHonorTitleData=malformed
refuse("overlong source",function() return MclarionWow_CaptureTitle(true) end,"Honor/title storage format refused.")
MclarionWowHonorTitleData=source
local oldHonor=GetPVPLifetimeStats;GetPVPLifetimeStats=nil
refuse("missing lifetime API",function() return MclarionWow_CaptureHonor(true) end,"Honor API unavailable.");GetPVPLifetimeStats=oldHonor
local oldRank=C_MajorFactions.GetMajorFactionProgressionInfo
C_MajorFactions.GetMajorFactionProgressionInfo=function() return {renownLevel=1,renownReputationEarned=200,renownLevelThreshold=100,maxLevel=14} end
refuse("malformed rank",function() return MclarionWow_CaptureHonor(true) end,"Honor API unavailable.")
C_MajorFactions.GetMajorFactionProgressionInfo=function() return danger end
refuse("protected rank table",function() return MclarionWow_CaptureHonor(true) end,"Honor API unavailable.")
C_MajorFactions.GetMajorFactionProgressionInfo=oldRank
local oldCount=GetNumTitles;GetNumTitles=nil
refuse("missing title API",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.");GetNumTitles=oldCount
local oldCurrent=GetCurrentTitle;GetCurrentTitle=function() return nil end
refuse("nil active title unavailable",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.")
GetCurrentTitle=function() return -1 end
GetNumTitles=function() return 0 end
local savedKnown,savedName=IsTitleKnown,GetTitleName
IsTitleKnown=nil
refuse("missing known API with zero titles",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.")
IsTitleKnown=savedKnown;GetTitleName=nil
refuse("missing name API with zero titles",function() return MclarionWow_CaptureTitle(true) end,"Title API unavailable.")
GetTitleName=savedName
IsTitleKnown=function() error("empty enumeration should not call index") end
stamp=stamp+1
local noneOk,noneReason=MclarionWow_CaptureTitle(true)
eq(noneOk,true,"zero-title enumeration valid");eq(noneReason,"saved","explicit empty known set")
eq(MclarionWowHonorTitleData.characters[owner].title[#MclarionWowHonorTitleData.characters[owner].title]:match("|none|0|$"),"|none|0|","-1 maps to no active title")
GetNumTitles=oldCount;IsTitleKnown=known;GetCurrentTitle=oldCurrent
local oldBudget=MclarionWow_HonorTitleStorageBudget;MclarionWow_HonorTitleStorageBudget=nil
refuse("missing budget capture",function() stamp=stamp+1;return MclarionWow_CaptureHonor(true) end,"Honor/title storage budget refused.")
MclarionWow_HonorTitleStorageBudget=function() error("budget crash") end
refuse("throwing budget setting",function() return MclarionWow_SetAutoTitleCapture(true) end,"Honor/title storage budget refused.")
MclarionWow_HonorTitleStorageBudget=oldBudget
-- New owner has independent history, not a continuation of the previous owner.
owner="Player-1234-OTHER";stamp=stamp+1
local saved,kind=MclarionWow_CaptureTitle(true)
eq(saved,true,"second owner capture");eq(kind,"saved","second owner result")
eq(#MclarionWowHonorTitleData.characters[owner].title,1,"owner-local history")
eq(same(legacy,original),true,"legacy still untouched");eq(budgetCalls>0,true,"combined callback exercised")
print("Honor/title capture: "..checks.." assertions passed")
