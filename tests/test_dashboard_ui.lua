-- Map-sized overview contract; deterministic geometry mock.
local frames={}
UIParent={GetWidth=function() return 1024 end,GetHeight=function() return 768 end}
issecretvalue=function() return false end
function CreateFrame(kind,name,parent)
 local f={kind=kind,name=name,parent=parent,scripts={},shown=true};frames[#frames+1]=f
 local w,h
 function f:SetSize(a,b) w=a;h=b end
 function f:GetWidth() return w end
 function f:GetHeight() return h end
 function f:SetPoint(...) self.point={...} end
 function f:ClearAllPoints() self.point=nil end
 function f:SetFrameStrata() end
 function f:SetMovable() end
 function f:EnableMouse() end
 function f:RegisterForDrag() end
 function f:SetScript(e,cb) self.scripts[e]=cb end
 function f:StartMoving() end
 function f:StopMovingOrSizing() end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 function f:SetText(t) self.text=t end
 function f:SetNormalTexture(t) self.texture=t end
 function f:SetChecked(t) self.checked=t end
 function f:GetChecked() return self.checked end
 function f:EnableMouseWheel(t) self.wheel=t end
 function f:SetScrollChild(child) self.child=child end
 function f:SetVerticalScroll(t) self.offset=t end
 function f:GetVerticalScroll() return self.offset or 0 end
 function f:GetVerticalScrollRange() return math.max(0,(self.child and self.child:GetHeight() or 0)-(self:GetHeight() or 0)) end
 function f:CreateFontString()
  local l={parent=self};local lw,lh
  function l:SetPoint(...) self.point={...} end
  function l:ClearAllPoints() self.point=nil end
  function l:SetWidth(x) lw=x end
  function l:SetHeight(x) lh=x end
  function l:GetWidth() return lw end
  function l:GetHeight() return lh end
  function l:SetJustifyH() end
  function l:SetText(x) self.text=x end
  function l:GetStringHeight()
   local lines=0;local chars=math.max(1,math.floor((lw or 200)/7))
   for line in (tostring(self.text or "").."\n"):gmatch("(.-)\n") do lines=lines+math.max(1,math.ceil(#line/chars)) end
   local natural=lines*14
   return lh and lh>0 and math.min(natural,lh) or natural
  end
  self.labels=self.labels or {};self.labels[#self.labels+1]=l;return l
 end
 return f
end
assert(loadfile("../DashboardUI.lua"))()
local keys={"combat","character","bags","bank","items","quest","reputation","gold","currency","honor","title"}
local actions,toggles={},{};local detailCalls=0
MclarionWow_DashboardSummary=function(k) return "saved "..k end
MclarionWow_DashboardDetails=function(k) detailCalls=detailCalls+1;return k.."\n"..string.rep("Stored observation details and values. ",180) end
local function make(w,h)
 UIParent.GetWidth=function() return w end;UIParent.GetHeight=function() return h end
 local start=#frames
 local panel=MclarionWow_CreateDashboard({status=function(k) return {message="Ready "..k} end,auto=function() return false end,
 action=function(k) actions[k]=(actions[k] or 0)+1 end,toggle=function(k,v) toggles[k]=v end})
 local own,scrolls={},{}
 for i=start+1,#frames do local f=frames[i];own[#own+1]=f;if f.kind=="ScrollFrame" then scrolls[#scrolls+1]=f end end
 return panel,own,scrolls[1],scrolls[2]
end
local panel,own,index,body=make(1024,768)
local brandFound=false
for _,f in ipairs(own) do
 if f.texture=="Interface\\AddOns\\MclarionWow\\VaultkeeperIcon.tga" then brandFound=true end
end
assert(brandFound,"supplied Vaultkeeper icon in dashboard header")
assert(panel:GetWidth()>=960 and panel:GetWidth()<=996 and panel:GetHeight()>=700 and panel:GetHeight()<=740,"map-sized clamped panel")
assert(panel.width==nil and panel.height==nil and index and body and index~=body,"private geometry and independent panes")
assert(index:GetVerticalScrollRange()==0,"all eleven rows fit without category scrolling")
local links,checks,scans={},{},{}
for _,f in ipairs(own) do
 assert(f.text~="Stop logging now","no stop logging")
 if f.parent==index.child then
  if f.kind=="CheckButton" then checks[#checks+1]=f end
  if f.kind=="Button" and f.text=="Scan" then scans[#scans+1]=f end
  if f.kind=="Button" and f.text~="Scan" then links[#links+1]=f end
 end
end
assert(#links==11 and #checks==11 and #scans==10,"11 selectors/opt-ins and 10 scans")
for i,k in ipairs(keys) do
 assert(checks[i].shown~=false and links[i].point[3]==checks[i].point[3],"persistent aligned preference "..k)
 if i>1 then assert(scans[i-1].point[3]==links[i].point[3],"aligned Scan "..k) end
end
local summaries,statuses=0,0
for _,l in ipairs(index.child.labels or {}) do
 if l.text and l.text:find("Stored data: saved ",1,true) then summaries=summaries+1 end
 if l.text and l.text:find("Status: Ready ",1,true) then statuses=statuses+1 end
end
assert(summaries==11 and statuses==11,"status and stored summary alongside every row")
assert(detailCalls>0 and body.child:GetHeight()>body:GetHeight(),"long rich details independently scroll")
MclarionWow_DashboardDetails=function(k)
 if k=="bags" then return string.rep("A long saved observation with wrapped values. ",180) end
 return "short"
end
assert(MclarionWow_DashboardNavigate("combat"))
local shortRange=body:GetVerticalScrollRange()
assert(MclarionWow_DashboardNavigate("bags"))
assert(body:GetVerticalScrollRange()>shortRange and body:GetVerticalScrollRange()>0,
 "short-to-long selection remeasures wrapped text and expands scroll range")
body.scripts.OnMouseWheel(body,-100)
assert(body:GetVerticalScroll()>0 and index:GetVerticalScroll()==0,"detail wheel does not move overview")
for _,k in ipairs(keys) do assert(MclarionWow_DashboardNavigate(k) and not next(actions),"navigation read only "..k) end
MclarionWow_DashboardRefresh();assert(not next(actions),"refresh read only")
checks[1]:SetChecked(true);checks[1].scripts.OnClick(checks[1]);assert(toggles.combat==true,"combat preference")
for i=2,11 do scans[i-1].scripts.OnClick(scans[i-1]);assert(actions[keys[i]]==1,"manual Scan "..keys[i]) end
assert(actions.combat==nil,"combat action never invoked")
local detailLabel
for _,l in ipairs(body.child.labels or {}) do if l.text and l.text:find("Stored observations:",1,true) then detailLabel=l end end
MclarionWow_DashboardDetails=function() error("protected") end
assert(pcall(MclarionWow_DashboardRefresh) and detailLabel and detailLabel.text:find("unavailable",1,true),"throwing detail guarded")
local sentinel={};issecretvalue=function(v) return v==sentinel end
MclarionWow_DashboardDetails=function() return sentinel end
assert(pcall(MclarionWow_DashboardRefresh) and detailLabel.text:find("unavailable",1,true),"protected detail guarded")
issecretvalue=function() return false end
MclarionWow_DashboardDetails=function() return string.rep("x",100000) end
assert(pcall(MclarionWow_DashboardRefresh) and detailLabel.text:find("unavailable",1,true),"oversized detail refused")
local small,smallFrames,smallIndex,smallBody=make(350,280)
assert(small:GetWidth()<=322 and small:GetHeight()<=252 and small.width==nil,"small clamping and private geometry")
assert(smallIndex:GetHeight()>0 and smallBody:GetHeight()>0 and smallIndex:GetVerticalScrollRange()>0,"small overview overflow and details remain reachable")
local smallLinks=0
for _,f in ipairs(smallFrames) do if f.parent==smallIndex.child and f.kind=="Button" and f.text~="Scan" then smallLinks=smallLinks+1 end end
assert(smallLinks==11,"small viewport navigation complete")
print("Map overview contracts passed")
