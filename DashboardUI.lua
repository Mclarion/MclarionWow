-- Data-first offline dashboard. Opening, selecting and refreshing never scans.
local keys={"combat","character","bags","bank","items","quest","reputation","gold","currency","honor","title"}
local names={"Combat log","Character","Bags","Character bank","Item details","Quests","Reputation","Gold","Currencies","Honor","Titles"}
local scopes={
 "WoW writes its combat-log file. This addon keeps no combat events or record count.",
 "Own identity, gear, level and location; not every past state.",
 "Own carried-bag item totals; not account or guild storage.",
 "Own character-bank tabs only while the own bank view is open; no account bank.",
 "Cached names/details from own bags, gear and open own bank. Incomplete cache is refused.",
 "Active quest-log view only; not completed quest history.",
 "Visible faction list only; collapsed or unavailable rows are not inferred.",
 "Current own money balance; not transaction history.",
 "Visible currency list only; not hidden currencies or acquisition history.",
 "Supported visible PvP counters only; not a full match history.",
 "Selected/known title observation; not acquisition history.",
}
local triggers={
 "Auto-start at world entry if opted in. Turning off auto-start does not stop logging already active.",
 "World entry; equipment, level, zone, post-combat; every 5 minutes. Manual Scan out of combat.",
 "World entry, delayed bag updates, bag opening, post-combat; every 5 minutes. Manual Scan out of combat.",
 "Bank opens, slots/tabs change, own-bank page selection. Manual Scan requires open own bank, out of combat.",
 "World entry, equipment, bags, post-combat; bank events for bank items; every 5 minutes for bags/gear. Manual Scan bags/gear, bank details follow bank scan.",
 "World entry, quest updates, post-combat; every 5 minutes and bounded retry. Manual Scan out of combat.",
 "World entry, faction updates, post-combat; every 5 minutes and bounded retry. Manual Scan out of combat.",
 "World entry, post-combat, money updates; every 5 minutes and bounded retry. Manual Scan out of combat.",
 "World entry, post-combat, currency updates; every 5 minutes and bounded retry. Manual Scan out of combat.",
 "World entry, post-combat, PvP-rank updates; every 5 minutes and bounded retry. Manual Scan out of combat.",
 "World entry and post-combat; every 5 minutes and bounded retry. Manual Scan out of combat.",
}
local function safeRead(name,key,limit,fallback)
 if type(issecretvalue)~="function" then return fallback end
 local fn=_G[name]
 local ok,secret=pcall(issecretvalue,fn)
 if not ok or secret or type(fn)~="function" then return fallback end
 local success,value=pcall(fn,key)
 if not success then return fallback end
 ok,secret=pcall(issecretvalue,value)
 if not ok or secret or type(value)~="string" or #value>limit then return fallback end
 return value
end
local function measure(label,value)
 label:SetHeight(0);label:SetText(value);local height=math.max(14,label:GetStringHeight())
 label:SetHeight(height);return height
end
local function wheel(self,delta)
 self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*35)))
end
function MclarionWow_CreateDashboard(model)
 local panel=CreateFrame("Frame","MclarionWowSettingsFrame",UIParent,"BasicFrameTemplateWithInset")
 local width,height=1000,700
 if UIParent and type(UIParent.GetWidth)=="function" and type(UIParent.GetHeight)=="function" then
  local ok,value=pcall(UIParent.GetWidth,UIParent)
  if ok and type(value)=="number" and value>0 then width=math.min(width,math.max(1,value-28)) end
  ok,value=pcall(UIParent.GetHeight,UIParent)
  if ok and type(value)=="number" and value>0 then height=math.min(height,math.max(1,value-28)) end
 end
 panel:SetSize(width,height);panel:SetPoint("CENTER");panel:SetFrameStrata("DIALOG")
 panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag("LeftButton")
 panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
 local function label(parent,font,w,value,x,y)
  local text=parent:CreateFontString(nil,"OVERLAY",font)
  text:SetWidth(w);text:SetJustifyH("LEFT");text:SetPoint("TOPLEFT",x,y)
  measure(text,value);return text
 end
 local fullWidth=math.max(1,width-36)
 local brand=CreateFrame("Button",nil,panel)
 brand:SetSize(24,24);brand:SetPoint("TOPLEFT",18,-26);brand:EnableMouse(false)
 brand:SetNormalTexture("Interface\\AddOns\\MclarionWow\\VaultkeeperIcon.tga")
 label(panel,"GameFontNormalLarge",math.max(1,fullWidth-32),"Vaultkeeper | saved-data dashboard",50,-30)
 label(panel,"GameFontNormal",fullWidth,"Auto-capture runs with window closed; no upload. Select a category to inspect saved observations.",18,-54)
 local footer=label(panel,"GameFontNormal",fullWidth,"Saves at /reload or exit; memory != disk.",18,-height+40)
 footer:ClearAllPoints();footer:SetPoint("BOTTOMLEFT",18,35)
 local compact=width<800
 local available=math.max(30,height-115-footer:GetHeight())
 local listWidth=compact and fullWidth or math.max(220,math.floor(fullWidth*0.59))
 local detailWidth=compact and fullWidth or math.max(60,fullWidth-listWidth-12)
 local listHeight=compact and math.max(1,math.floor(available*0.57)) or available
 local detailHeight=compact and math.max(1,available-listHeight-8) or available
 local list=CreateFrame("ScrollFrame",nil,panel)
 list:SetSize(listWidth,listHeight);list:SetPoint("TOPLEFT",18,-78)
 local rows=CreateFrame("Frame",nil,list);local rowHeight=compact and 64 or 48
 rows:SetSize(listWidth,math.max(listHeight,rowHeight*#keys))
 list:SetScrollChild(rows);list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",wheel)
 local detail=CreateFrame("ScrollFrame",nil,panel)
 detail:SetSize(detailWidth,detailHeight)
 detail:SetPoint("TOPLEFT",compact and 18 or (30+listWidth),compact and -(86+listHeight) or -78)
 local content=CreateFrame("Frame",nil,detail)
 content:SetSize(detailWidth,detailHeight);detail:SetScrollChild(content)
 detail:EnableMouseWheel(true);detail:SetScript("OnMouseWheel",wheel)
 local selectorWidth=compact and math.min(86,listWidth*0.33) or 115
 local checkX=selectorWidth+4;local scanX=checkX+27;local statusX=scanX+73
 local statusWidth=compact and math.max(20,listWidth-8) or math.max(20,listWidth-statusX-7)
 local statusLeft=compact and 0 or statusX
 local statusY=compact and -26 or 0
 local summaryY=compact and -44 or -25
 local links,checks,statuses,summaries={},{},{},{}
 for i,key in ipairs(keys) do
  local y=-(i-1)*rowHeight
  local link=CreateFrame("Button",nil,rows,"UIPanelButtonTemplate")
  link:SetSize(selectorWidth,25);link:SetPoint("TOPLEFT",0,y);link:SetText(names[i]);links[i]=link
  local check=CreateFrame("CheckButton",nil,rows,"UICheckButtonTemplate")
  check:SetPoint("TOPLEFT",checkX,y);check:Show();checks[i]=check
  if key~="combat" then
   local scan=CreateFrame("Button",nil,rows,"UIPanelButtonTemplate")
   scan:SetSize(67,25);scan:SetPoint("TOPLEFT",scanX,y);scan:SetText("Scan")
   scan:SetScript("OnClick",function() model.action(key);MclarionWow_DashboardRefresh() end)
  end
  statuses[i]=label(rows,"GameFontHighlight",statusWidth,"",statusLeft,y+statusY)
  summaries[i]=label(rows,"GameFontHighlight",statusWidth,"",statusLeft,y+summaryY)
  check:SetScript("OnClick",function(self) model.toggle(key,self:GetChecked()==true);MclarionWow_DashboardRefresh() end)
 end
 local detailLabels={}
 for i=1,6 do
  local text=content:CreateFontString(nil,"OVERLAY",i==1 and "GameFontNormalLarge" or "GameFontHighlight")
  text:SetWidth(math.max(12,detailWidth-8));text:SetJustifyH("LEFT");detailLabels[i]=text
 end
 local current=1
 local function refresh()
  for i,key in ipairs(keys) do
   local state=model.status(key)
   checks[i]:SetChecked(model.auto(key)==true)
   local message=type(state.message)=="string" and state.message or "Status unavailable."
   local maxStatus=math.max(1,math.floor(statusWidth/7)-22)
   if #message>maxStatus then message=message:sub(1,math.max(1,maxStatus-3)).."..." end
   measure(statuses[i],"Status: "..message.." | Auto: "..(checks[i]:GetChecked() and "on" or "off"))
   local summary=safeRead("MclarionWow_DashboardSummary",key,240,"summary unavailable.")
   local maxSummary=math.max(1,math.floor(statusWidth/7)-16)
   if #summary>maxSummary then summary=summary:sub(1,math.max(1,maxSummary-3)).."..." end
   measure(summaries[i],"Stored data: "..summary)
  end
  local state=model.status(keys[current]);local y=0
  local values={names[current].."  ("..current.."/11)",
   "Auto-capture works with this window closed; no upload.\nCaptured: "..scopes[current],
   "Triggers: "..triggers[current],names[current]..": "..(state.message or "Unavailable.").." | Auto: "..(checks[current]:GetChecked() and "on" or "off"),
   "Last request (memory): "..(state.attempt or "none this session").."\nLast success (memory, this session): "..(state.success or "none this session"),
   "Stored observations:\n"..safeRead("MclarionWow_DashboardDetails",keys[current],32768,"Saved-data details unavailable.")}
  for i,value in ipairs(values) do
   local text=detailLabels[i];text:ClearAllPoints();text:SetPoint("TOPLEFT",0,-y)
   y=y+measure(text,value)+9
  end
  content:SetSize(detailWidth,math.max(detailHeight,y))
  detail:SetVerticalScroll(math.min(detail:GetVerticalScroll(),detail:GetVerticalScrollRange()))
 end
 local function navigate(index)
  if type(index)=="string" then
   local found
   for i,key in ipairs(keys) do if key==index then found=i;break end end
   index=found
  end
  if type(index)~="number" or index~=math.floor(index) or index<1 or index>#keys then return false end
  current=index;detail:SetVerticalScroll(0);refresh()
  local y=(index-1)*rowHeight
  if y<list:GetVerticalScroll() or y+rowHeight>list:GetVerticalScroll()+listHeight then
   list:SetVerticalScroll(math.min(list:GetVerticalScrollRange(),y))
  end
  return true
 end
 for i=1,#keys do links[i]:SetScript("OnClick",function() navigate(i) end) end
 local previous=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
 previous:SetSize(math.min(95,fullWidth/3),23);previous:SetPoint("BOTTOMLEFT",18,10);previous:SetText("Previous")
 previous:SetScript("OnClick",function() navigate(current==1 and #keys or current-1) end)
 local nextButton=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
 nextButton:SetSize(math.min(95,fullWidth/3),23);nextButton:SetPoint("BOTTOMRIGHT",-18,10);nextButton:SetText("Next")
 nextButton:SetScript("OnClick",function() navigate(current==#keys and 1 or current+1) end)
 local up,down=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"),CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
 up:SetSize(27,23);up:SetPoint("BOTTOM",panel,"BOTTOM",-17,10);up:SetText("^")
 down:SetSize(27,23);down:SetPoint("BOTTOM",panel,"BOTTOM",17,10);down:SetText("v")
 up:SetScript("OnClick",function() wheel(detail,1) end)
 down:SetScript("OnClick",function() wheel(detail,-1) end)
 MclarionWow_DashboardNavigate=navigate;MclarionWow_DashboardRefresh=refresh
 refresh();panel:Hide();return panel
end
