-- Deterministic construction/navigation checks; not a rendered-game screenshot.
local failures, assertions = 0, 0
local function check(value, message)
    assertions = assertions + 1
    if not value then failures = failures + 1; io.stderr:write("FAIL: " .. message .. "\n") end
end
local frames = {}
UIParent = {GetWidth=function() return 540 end, GetHeight=function() return 410 end, GetScale=function() return 1 end}
issecretvalue=function() return false end
function CreateFrame(kind, name, parent)
    local f = {kind=kind, name=name, parent=parent, scripts={}, shown=true}
    frames[#frames+1]=f
    function f:SetSize(w,h) self.width=w;self.height=h end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:SetFrameStrata() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:SetScript(event,callback) self.scripts[event]=callback end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:SetText(t) self.text=t end
    function f:SetChecked(t) self.checked=t end
    function f:GetChecked() return self.checked end
    function f:EnableMouseWheel(t) self.wheel=t end
    function f:SetScrollChild(child) self.child=child end
    function f:SetVerticalScroll(t) self.offset=t end
    function f:GetVerticalScroll() return self.offset or 0 end
    function f:GetVerticalScrollRange() return math.max(0, (self.child and self.child.height or 0) - (self.height or 0)) end
    function f:GetHeight() return self.height end
    function f:CreateFontString()
        local label={parent=self}
        function label:SetPoint(...) self.point={...} end
        function label:ClearAllPoints() self.point=nil end
        function label:SetWidth(w) self.width=w end
        function label:SetHeight(h) self.height=h end
        function label:SetJustifyH(j) self.justify=j end
        function label:SetText(t) self.text=t end
        function label:GetStringHeight()
            local chars=math.max(1, math.floor((self.width or 200)/7))
            local lines=0
            for line in (tostring(self.text or "").."\n"):gmatch("(.-)\n") do
                lines=lines+math.max(1,math.ceil(#line/chars))
            end
            return lines*14
        end
        function label:Hide() self.shown=false end
        function label:Show() self.shown=true end
        self.labels=self.labels or {};self.labels[#self.labels+1]=label
        return label
    end
    return f
end
local actions, toggles, summaries = {}, {}, {}
local names={"character","bags","bank","items","combat","quest","reputation","gold","currency","honor","title"}
local scans=0
assert(loadfile("../DashboardUI.lua"))()
MclarionWow_DashboardSummary=nil
local dashboard=MclarionWow_CreateDashboard({
    status=function(key) return {message="Unavailable: "..string.rep("protected view ",24),attempt=nil,success=nil} end,
    auto=function() return false end,
    action=function(key) actions[key]=(actions[key] or 0)+1 end,
    toggle=function(key,value) toggles[key]=value end,
})
check(scans==0 and not next(actions),"opening dashboard does not request any scan")
check(dashboard.width<=UIParent:GetWidth()-28 and dashboard.height<=UIParent:GetHeight()-28,
    "panel clamps to smaller viewport")
local scroll
for _,f in ipairs(frames) do if f.kind=="ScrollFrame" then scroll=f end end
check(scroll and scroll.child and scroll.wheel and scroll.scripts.OnMouseWheel,
    "native scroll child keeps long status and summary reachable")
scroll.scripts.OnMouseWheel(scroll,-100)
check(scroll.offset==scroll:GetVerticalScrollRange(),"wheel clamps at end")
scroll.scripts.OnMouseWheel(scroll,100)
check(scroll.offset==0,"wheel clamps at beginning")
for i,key in ipairs(names) do
    MclarionWow_DashboardNavigate(key)
    local selected=0
    for _,f in ipairs(frames) do
        if f.parent==dashboard and f.kind=="CheckButton" and f.shown then selected=selected+1 end
    end
    check(selected==1,"one checkbox visible on section "..key)
    check(not next(actions),"navigation remains read-only on "..key)
end
check(MclarionWow_DashboardNavigate("unknown")==false,"unknown navigation refused")
local function summaryText()
    for _,f in ipairs(frames) do
        if f==scroll.child then
            for _,label in ipairs(f.labels or {}) do
                if label.text and label.text:find("Stored data:",1,true) then return label.text end
            end
        end
    end
end
check(summaryText() and summaryText():find("unavailable",1,true),"missing summary has fallback")
MclarionWow_DashboardSummary=function() error("protected") end
MclarionWow_DashboardRefresh()
check(summaryText():find("unavailable",1,true),"throwing summary has fallback")
MclarionWow_DashboardSummary=function() return string.rep("secret",400) end
MclarionWow_DashboardRefresh()
check(summaryText():find("unavailable",1,true),"oversized summary is not shown")
MclarionWow_DashboardSummary=function() return "2 saved observations" end
MclarionWow_DashboardRefresh()
check(summaryText():find("2 saved observations",1,true),"bounded stored-data summary shown")
local count=0
for _,f in ipairs(frames) do if f.kind=="CheckButton" and f.parent==dashboard then count=count+1 end end
check(count==11,"eleven separate opt-in controls constructed")
count=0
for _,f in ipairs(frames) do
    if f.kind=="Button" and f.parent==dashboard and (f.text=="Stop logging now" or f.text and f.text:find(" now",1,true)) then count=count+1 end
end
check(count==11,"eleven separate manual controls constructed")
-- Every category/status must be directly available in one scrollable index.
local index, detail
for _,f in ipairs(frames) do
    if f.kind=="ScrollFrame" and f~=scroll then index=f end
end
check(index and index.child and index.scripts.OnMouseWheel,"separate scrollable category index")
local direct=0
if index and index.child then
    for _,f in ipairs(frames) do
        if f.parent==index.child and f.kind=="Button" and f.scripts.OnClick then
            direct=direct+1; f.scripts.OnClick(f)
            check(not next(actions),"index navigation is read-only")
        end
    end
    local visible=0
    for _,label in ipairs(index.child.labels or {}) do
        if label.shown~=false and label.text and label.text:find("Unavailable:",1,true) then visible=visible+1 end
        check(label.height and label.height>=label:GetStringHeight(),"index wrapped text measured")
    end
    check(visible==11,"all eleven status messages visible in index")
    check(index.child.height>=index.height and index:GetVerticalScrollRange()>0,"index is scroll-reachable")
end
check(direct==11,"eleven direct category links")
local secret=setmetatable({}, {__len=function() error("secret length") end})
local oldSecret=issecretvalue
local inspected=0
issecretvalue=function(v) if v==secret then inspected=inspected+1; return true end; return false end
MclarionWow_DashboardSummary=function() return secret end
check(pcall(MclarionWow_DashboardRefresh) and inspected>0 and summaryText():find("unavailable",1,true),
    "protected summary return rejected before length")
issecretvalue=oldSecret
check(not (summaryText() or ""):find("Last attempt",1,true),"request is not called scanner attempt")
for _,label in ipairs(scroll.child.labels or {}) do
    check(label.height and label.height>=label:GetStringHeight(),"detail wrapped text measured")
end
-- Both compact and spacious UIParent dimensions keep fixed chrome outside scrolling detail.
for _,view in ipairs({{350,280},{1100,850}}) do
    UIParent.GetWidth=function() return view[1] end
    UIParent.GetHeight=function() return view[2] end
    local start=#frames
    local panel=MclarionWow_CreateDashboard({
        status=function(key) return {message=string.rep("Long status with words ",36)} end,
        auto=function() return false end, action=function() error("navigation scanned") end,
        toggle=function() error("navigation opted in") end,
    })
    local list={}
    for n=start+1,#frames do
        local f=frames[n]
        if f.parent==panel and f.kind=="ScrollFrame" then list[#list+1]=f end
    end
    local idx, body=list[1],list[2]
    check(panel.width<=view[1]-28 and panel.height<=view[2]-28,
        "viewport bounds "..view[1])
    check(idx and body and idx.height>0 and body.height>0 and
        body.child.height>body.height and idx.child.height>idx.height,
        "both regions scroll at "..view[1])
    local footer, previous, nextButton
    for _,label in ipairs(panel.labels or {}) do
        if label.text and label.text:find("Saves at /reload",1,true) then footer=label end
    end
    for _,f in ipairs(frames) do
        if f.parent==panel and f.kind=="Button" then
            if f.text=="Previous" then previous=f end
            if f.text=="Next" then nextButton=f end
        end
    end
    local detailBottom=body.point and -body.point[3]+body.height
    local footerTop=footer and panel.height-footer.point[3]-footer.height
    local footerBottom=footer and panel.height-footer.point[3]
    local navTop=previous and panel.height-previous.point[3]-previous.height
    check(footer and footer.height==footer:GetStringHeight() and
        (view[1]~=350 or footer.height>=28), "footer uses measured wrapped height at "..view[1])
    check(detailBottom and footerTop and detailBottom+6<=footerTop,
        "detail ends before actual footer top plus gap at "..view[1])
    check(footerBottom and navTop and footerBottom+2<=navTop and nextButton,
        "footer ends before bottom navigation at "..view[1])
    check(body.height>=20, "compact detail remains usable at "..view[1])
    print("Dashboard geometry "..view[1].."x"..view[2]..": panel "..panel.width.."x"..panel.height..
        ", detail "..(-body.point[3]).."-"..detailBottom..
        ", footer "..footerTop.."-"..footerBottom..", nav starts "..navTop)
    local reached=0
    for _,f in ipairs(frames) do
        if f.parent==idx.child and f.kind=="Button" and f.scripts.OnClick then
            f.scripts.OnClick(f); reached=reached+1
        end
    end
    check(reached==11,"direct access at "..view[1])
    for _,f in ipairs({idx.child,body.child}) do
        for _,label in ipairs(f.labels or {}) do
            check(label.height>=label:GetStringHeight(),"long text measured at "..view[1])
        end
    end
end
print("Dashboard UI: "..assertions.." assertions, "..failures.." failures")
if failures>0 then os.exit(1) end
