-- Offline Forever 1.60.1.70205 candidate. Separate companion SavedVariables
-- MclarionWowHonorTitleData; never read or write MclarionWowData here.
-- Honor: lifetime honorable kills / maximum PvP rank; current session and
-- yesterday honorable/dishonorable kills; Camelot rank faction 2800 level,
-- earned points, level threshold and maximum level. These are NOT cumulative
-- honor earned, an acquisition log, or an observed current PvP title.
-- Titles: active mask ID or explicit none; bounded known mask IDs, not dates.
local PROTECTED = "Honor/title protected value refused."
local function ready()
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then return false end
    local a,x=pcall(issecretvalue,nil);local b,y=pcall(issecrettable,{})
    return a and b and type(x)=="boolean" and type(y)=="boolean"
end
local function secret(v)
    local ok,x=pcall(issecretvalue,v)
    if not ok or type(x)~="boolean" or x then return true end
    if type(v)=="table" then
        ok,x=pcall(issecrettable,v)
        if not ok or type(x)~="boolean" or x then return true end
    end
    return false
end
local function plain(v)
    if secret(v) or type(v)~="table" then return false end
    local ok,m=pcall(getmetatable,v)
    return ok and not secret(m) and m==nil
end
local function number(v,lo,hi)
    return not secret(v) and type(v)=="number" and v>=lo and v<=hi and v==math.floor(v)
end
local function owner(v)
    return not secret(v) and type(v)=="string" and #v>=11 and #v<=77 and v:match("^Player%-[A-Za-z0-9%-]+$")~=nil
end
local function canonical(v,lo,hi)
    if type(v)~="string" or (v~="0" and not v:match("^[1-9]%d*$")) then return nil end
    local n=tonumber(v);if number(n,lo,hi) and tostring(n)==v then return n end
end
local function split(s)
    local t,start={},1
    while true do
        local i=s:find("|",start,true)
        if not i then t[#t+1]=s:sub(start);return t end
        t[#t+1]=s:sub(start,i-1);start=i+1
    end
end
local function parse(record,guid,kind)
    if secret(record) or type(record)~="string" or #record>4096 then return nil end
    local f=split(record)
    if f[1]~=(kind=="honor" and "MHWOWH1" or "MHWOWT1") or
        f[2]~="forever" or f[4]~=guid then return nil end
    local stamp=canonical(f[3],1,253402300799)
    if not stamp or not canonical(f[5],1,2147483647) then return nil end
    if kind=="honor" then
        if #f~=15 then return nil end
        for i=6,15 do
            if not canonical(f[i],0,i==12 and 64 or 2147483647) then return nil end
        end
        if tonumber(f[12])>tonumber(f[15]) or
            tonumber(f[13])>tonumber(f[14]) then return nil end
    end
    return stamp,record:match("^[^|]+|[^|]+|[^|]+|(.*)$")
end
local function titleParse(record,guid)
    if secret(record) or type(record)~="string" or #record>4096 then return end
    local f=split(record)
    if #f~=8 or f[1]~="MHWOWT1" or f[2]~="forever" or f[4]~=guid then return end
    local stamp=canonical(f[3],1,253402300799)
    if not stamp or not canonical(f[5],1,2147483647) then return end
    local active=canonical(f[7],0,512)
    if not active then return end
    local known,last={},0
    if f[8]~="" then
        if f[8]:sub(1,1)=="," or f[8]:sub(-1)=="," or f[8]:find(",,",1,true) then return end
        for text in f[8]:gmatch("[^,]+") do
            local id=canonical(text,1,512)
            if not id or id<=last then return end
            known[id]=true;last=id
        end
    end
    if f[6]=="none" then if active~=0 then return end
    elseif f[6]~=("active:"..f[7]) or active==0 or not known[active] then return end
    return stamp,record:match("^[^|]+|[^|]+|[^|]+|(.*)$")
end
local function recordParse(record,guid,kind)
    if kind=="title" then return titleParse(record,guid) end
    return parse(record,guid,"honor")
end
local function validate(root)
    if secret(root) then return nil,PROTECTED end
    if not plain(root) then return nil,"Honor/title storage format refused." end
    for k in pairs(root) do
        if secret(k) then return nil,PROTECTED end
        if k~="schema" and k~="settings" and k~="characters" then return nil,"Honor/title storage format refused." end
    end
    local schema,settings,characters=rawget(root,"schema"),rawget(root,"settings"),rawget(root,"characters")
    if secret(schema) or secret(settings) or secret(characters) then return nil,PROTECTED end
    if schema~=1 or not plain(settings) or not plain(characters) or
        root==settings or root==characters or settings==characters then return nil,"Honor/title storage format refused." end
    for k,v in pairs(settings) do
        if secret(k) or secret(v) then return nil,PROTECTED end
        if (k~="autoHonorCapture" and k~="autoTitleCapture") or type(v)~="boolean" then
            return nil,"Honor/title storage format refused." end
    end
    local h,t=rawget(settings,"autoHonorCapture"),rawget(settings,"autoTitleCapture")
    if secret(h) or secret(t) then return nil,PROTECTED end
    if type(h)~="boolean" or type(t)~="boolean" then return nil,"Honor/title storage format refused." end
    local owners,bytes,seen=0,0,{[root]=true,[settings]=true,[characters]=true}
    for guid,categories in pairs(characters) do
        if secret(guid) or secret(categories) then return nil,PROTECTED end
        if not owner(guid) or not plain(categories) or seen[categories] then return nil,"Honor/title storage format refused." end
        owners=owners+1;if owners>256 then return nil,"Honor/title owner limit reached." end
        seen[categories]=true
        local any=false
        for kind,history in pairs(categories) do
            if secret(kind) or secret(history) then return nil,PROTECTED end
            if kind~="honor" and kind~="title" then return nil,"Honor/title storage format refused." end
            if not plain(history) or seen[history] then return nil,"Honor/title storage format refused." end
            seen[history]=true;any=true
            local count=0
            for k,v in pairs(history) do
                if secret(k) or secret(v) then return nil,PROTECTED end
                if not number(k,1,20) then return nil,"Honor/title storage format refused." end
                count=count+1
            end
            if count==0 or count>20 then return nil,"Honor/title storage format refused." end
            local last,state=0,nil
            for i=1,count do
                local wire=rawget(history,i)
                local stamp,s=recordParse(wire,guid,kind)
                if not stamp or stamp<=last or s==state then return nil,"Honor/title storage format refused." end
                bytes=bytes+#wire;if bytes>1048576 then return nil,"Honor/title storage limit reached." end
                last,state=stamp,s
            end
        end
        if not any then return nil,"Honor/title storage format refused." end
    end
    return settings,characters,owners
end
local function candidate(source)
    if source==nil then source=MclarionWowHonorTitleData end
    if secret(source) then return nil,PROTECTED end
    if source==nil then return {schema=1,settings={autoHonorCapture=false,autoTitleCapture=false},characters={}},nil,0 end
    local settings,characters,owners=validate(source)
    if not settings then return nil,characters end
    local root={schema=1,settings={autoHonorCapture=settings.autoHonorCapture,autoTitleCapture=settings.autoTitleCapture},characters={}}
    for guid,categories in pairs(characters) do
        local copied={}
        for kind,history in pairs(categories) do
            copied[kind]={};for i=1,#history do copied[kind][i]=history[i] end
        end
        root.characters[guid]=copied
    end
    return root,nil,owners
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
    local fn=MclarionWow_HonorTitleStorageBudget
    if secret(fn) or type(fn)~="function" then return nil,"Honor/title storage budget refused." end
    -- Offer a deep copy, never the candidate that will be committed.
    local offered=candidate(root)
    if not offered then return nil,"Honor/title storage budget refused." end
    local ok,allowed=pcall(fn,offered)
    if not ok then return nil,"Honor/title storage budget refused." end
    if secret(allowed) then return nil,PROTECTED end
    if allowed~=true or not validate(offered) or not validate(root) or
        not equivalent(root,offered) then return nil,"Honor/title storage budget refused." end
    return true
end
local function metadata()
    local combat=InCombatLockdown
    if secret(combat) or type(combat)~="function" then return nil,"Combat status unavailable." end
    local ok,locked=pcall(combat)
    if not ok or secret(locked) or type(locked)~="boolean" then return nil,"Combat status unavailable." end
    if locked then return nil,"Capture unavailable in combat." end
    local u,t,b=UnitGUID,GetServerTime,GetBuildInfo
    if secret(u) or secret(t) or secret(b) or type(u)~="function" or type(t)~="function" or type(b)~="function" then return nil,"Capture metadata unavailable." end
    local own,guid=pcall(u,"player");local timed,stamp=pcall(t);local built,_,build=pcall(b)
    if not own or not timed or not built or not owner(guid) or not number(stamp,1,253402300799) or secret(build) or not canonical(build,1,2147483647) then
        return nil,"Capture metadata unavailable." end
    return {guid=guid,stamp=stamp,build=build}
end
local function honor()
    local a,b,c=GetPVPLifetimeStats,GetPVPSessionStats,GetPVPYesterdayStats
    local ns=C_MajorFactions
    if secret(a) or secret(b) or secret(c) or type(a)~="function" or type(b)~="function" or type(c)~="function" or not plain(ns) then return nil,"Honor API unavailable." end
    local safe,rankFn=pcall(function() return ns.GetMajorFactionProgressionInfo end)
    if not safe or secret(rankFn) or type(rankFn)~="function" then return nil,"Honor API unavailable." end
    local x,lifetime,maxRank=pcall(a);local y,todayHK,todayDK=pcall(b);local z,yesterdayHK,yesterdayDK=pcall(c)
    local r,rank=pcall(rankFn,2800)
    if not x or not y or not z or not r or not plain(rank) then return nil,"Honor API unavailable." end
    local q,level,earned,threshold,maxLevel=pcall(function()
        return rank.renownLevel,rank.renownReputationEarned,rank.renownLevelThreshold,rank.maxLevel end)
    local values={lifetime,maxRank,todayHK,todayDK,yesterdayHK,yesterdayDK,level,earned,threshold,maxLevel}
    if not q then return nil,"Honor API unavailable." end
    for i=1,10 do
        if not number(values[i],0,(i==2 or i==7 or i==10) and 64 or 2147483647) then return nil,"Honor API unavailable." end
    end
    if level>maxLevel or earned>threshold then return nil,"Honor API unavailable." end
    return values
end
local function titles()
    local current,count,known,name=GetCurrentTitle,GetNumTitles,IsTitleKnown,GetTitleName
    if secret(current) or secret(count) or secret(known) or secret(name) or
        type(current)~="function" or type(count)~="function" or
        type(known)~="function" or type(name)~="function" then
        return nil,"Title API unavailable."
    end
    local previous
    for pass=1,2 do
        local ok,n=pcall(count);local activeOk,active=pcall(current)
        if not ok or not activeOk or not number(n,0,512) or not number(active,-1,512) then return nil,"Title API unavailable." end
        local ids,has,signature={},{},{}
        for i=1,n do
            local valid,value=pcall(known,i)
            if not valid or secret(value) or type(value)~="boolean" then return nil,"Title API unavailable." end
            signature[#signature+1]=value and "1" or "0"
            if value then
                local named,title,isPlayer=pcall(name,i)
                if not named or secret(title) or secret(isPlayer) or type(title)~="string" or #title<1 or #title>256 or type(isPlayer)~="boolean" then return nil,"Title API unavailable." end
                signature[#signature+1]=#title..":"..title..(isPlayer and "1" or "0")
                if isPlayer then ids[#ids+1]=tostring(i);has[i]=true end
            end
        end
        if active>0 and (active>n or not has[active]) then return nil,"Title API unavailable." end
        local state={active>0 and ("active:"..active) or "none",active>0 and tostring(active) or "0",table.concat(ids,",")}
        local fingerprint=tostring(n)..":"..tostring(active)..":"..table.concat(signature,"|")
        if previous and previous~=fingerprint then return nil,"Title view changed." end
        previous=fingerprint
        if pass==2 then return state end
    end
end
local function setFlag(which,enabled)
    if not ready() then return nil,"Honor/title protection unavailable." end
    if secret(enabled) then return nil,PROTECTED end
    if type(enabled)~="boolean" then return nil,"Honor/title setting unavailable." end
    local root,why=candidate();if not root then return nil,why end
    local key=which=="honor" and "autoHonorCapture" or "autoTitleCapture"
    if root.settings[key]==enabled then return true end
    root.settings[key]=enabled
    local valid,reason=validate(root);if not valid then return nil,reason end
    local allowed,refusal=budget(root);if not allowed then return nil,refusal end
    local final,finalReason=validate(root);if not final then return nil,finalReason end
    MclarionWowHonorTitleData=root;return true
end
local function enabled(which)
    if not ready() then return false,"Honor/title protection unavailable." end
    local root=MclarionWowHonorTitleData
    if secret(root) then return false,PROTECTED end
    if root==nil then return false end
    local settings,why=validate(root)
    if not settings then return false,why end
    return settings[which=="honor" and "autoHonorCapture" or "autoTitleCapture"]
end
local function capture(kind,manual)
    if not ready() then return nil,"Honor/title protection unavailable." end
    if secret(manual) then return nil,PROTECTED end
    if type(manual)~="boolean" then return nil,"Capture mode unavailable." end
    local ctx,why=metadata();if not ctx then return nil,why end
    local root,err,owners=candidate();if not root then return nil,err end
    if not manual and not root.settings[kind=="honor" and "autoHonorCapture" or "autoTitleCapture"] then
        return nil,kind=="honor" and "Automatic honor capture is off." or "Automatic title capture is off."
    end
    local values,issue
    if kind=="honor" then values,issue=honor() else values,issue=titles() end
    if not values then return nil,issue end
    local fields={kind=="honor" and "MHWOWH1" or "MHWOWT1","forever",tostring(ctx.stamp),ctx.guid,ctx.build}
    for i=1,#values do fields[#fields+1]=tostring(values[i]) end
    local wire=table.concat(fields,"|")
    local stamp,state=recordParse(wire,ctx.guid,kind)
    if not stamp then return nil,kind=="honor" and "Honor record unavailable." or "Title record unavailable." end
    local categories=root.characters[ctx.guid]
    local history=categories and categories[kind]
    if history then
        local previous,prior=recordParse(history[#history],ctx.guid,kind)
        if not previous then return nil,"Honor/title storage format refused." end
        if state==prior then return true,"unchanged" end
        if stamp<=previous then return true,"same-second" end
    elseif not categories and owners>=256 then return nil,"Honor/title owner limit reached." end
    local again,change=metadata()
    if not again then return nil,change end
    if again.guid~=ctx.guid then return nil,"Owner changed." end
    categories=categories or {};history=history or {}
    history[#history+1]=wire;if #history>20 then table.remove(history,1) end
    categories[kind]=history;root.characters[ctx.guid]=categories
    local valid,reason=validate(root);if not valid then return nil,reason end
    local allowed,refusal=budget(root);if not allowed then return nil,refusal end
    local final,finalReason=validate(root);if not final then return nil,finalReason end
    MclarionWowHonorTitleData=root;return true,"saved"
end
local function safe(fn,...)
    local ok,a,b=pcall(fn,...)
    if not ok then return nil,"Honor/title capture unavailable." end
    return a,b
end
function MclarionWow_CaptureHonor(manual) return safe(capture,"honor",manual) end
function MclarionWow_CaptureTitle(manual) return safe(capture,"title",manual) end
function MclarionWow_SetAutoHonorCapture(enabled) return safe(setFlag,"honor",enabled) end
function MclarionWow_SetAutoTitleCapture(enabled) return safe(setFlag,"title",enabled) end
function MclarionWow_HonorAutoEnabled() local ok,a,b=pcall(enabled,"honor");if not ok then return false,"Honor/title protection unavailable." end;return a,b end
function MclarionWow_TitleAutoEnabled() local ok,a,b=pcall(enabled,"title");if not ok then return false,"Honor/title protection unavailable." end;return a,b end
