-- Read-only dashboard over already captured, character-owned SavedVariables.
-- No scan API is invoked. Missing/malformed data is not an empty observation.
local MAX = 2147483647
local function safe(v)
    local ok, hidden = pcall(issecretvalue, v)
    if not ok or type(hidden) ~= "boolean" or hidden then return false end
    if type(v) == "table" then
        ok, hidden = pcall(issecrettable, v)
        if not ok or type(hidden) ~= "boolean" or hidden then return false end
    end
    return true
end
local function plain(v)
    if not safe(v) or type(v) ~= "table" then return false end
    local ok, meta = pcall(getmetatable, v)
    return ok and safe(meta) and meta == nil
end
local function num(v, lo, hi)
    return safe(v) and type(v) == "number" and v >= lo and v <= hi and v == math.floor(v)
end
local function owner(v)
    return safe(v) and type(v) == "string" and #v >= 11 and #v <= 77 and
        v:match("^Player%-[A-Za-z0-9%-]+$") ~= nil
end
local function decimal(s, lo, hi)
    if type(s) ~= "string" or #s > 16 or
        (s ~= "0" and not s:match("^[1-9]%d*$")) then return nil end
    local n = tonumber(s)
    if num(n, lo, hi) and tostring(n) == s then return n end
end
local function signed(s)
    if type(s)~="string" or #s>11 or not s:match("^%-?%d+$") or
        s=="-0" or s:match("^%-?0%d") then return nil end
    local n=tonumber(s)
    if num(n,-MAX,MAX) and tostring(n)==s then return n end
end
local function split(s, separator, cap)
    local out, start = {}, 1
    while true do
        if #out >= cap then return nil end
        local pos = s:find(separator, start, true)
        if not pos then out[#out+1] = s:sub(start); return out end
        out[#out+1] = s:sub(start, pos-1)
        start = pos+#separator
    end
end
local function array(t, cap, allowEmpty)
    if not plain(t) then return nil end
    local n = 0
    for k,v in pairs(t) do
        if not num(k, 1, cap) or not safe(v) then return nil end
        n=n+1
        if n>cap then return nil end
    end
    if n==0 and not allowEmpty then return nil end
    for i=1,n do if rawget(t,i)==nil then return nil end end
    return n
end
local function rootMap(root, field, schema)
    if not plain(root) then return nil end
    local version, map = rawget(root,"schema"),rawget(root,field)
    if not safe(version) or version ~= schema or not plain(map) then return nil end
    return map
end
local function history(map, guid, cap, parser)
    local entries = rawget(map,guid)
    if entries == nil then return nil,"no observation" end
    local n = array(entries,cap,false)
    if not n then return nil,"unavailable" end
    local last=0
    for i=1,n do
        local stamp=parser(rawget(entries,i),guid)
        if not stamp or stamp<=last then return nil,"unavailable" end
        last=stamp
    end
    return n,rawget(entries,n)
end
local function wire(record, guid, tag, fields, size, buildIndex)
    if not safe(record) or type(record)~="string" or #record>size then return nil end
    local f=split(record,"|",fields)
    if not f or #f~=fields or f[1]~=tag or f[2]~="forever" or
        f[4]~=guid or not decimal(f[3],1,253402300799) or
        not decimal(f[buildIndex or 5],1,MAX) then return nil end
    return decimal(f[3],1,253402300799),f
end
local function entries(text, sep, cap, parse)
    if text=="" then return 0,0,{} end
    if text:sub(1,1)==sep or text:sub(-1)==sep or text:find(sep..sep,1,true) then return nil end
    local parts=split(text,sep,cap)
    if not parts or #parts>cap then return nil end
    local units, seen, prior=0,{},0
    for _,part in ipairs(parts) do
        local id,amount,tab=parse(part)
        if not id or (not tab and id<=prior) or (tab and seen[tab..":"..id]) then return nil end
        prior=id
        if tab then seen[tab..":"..id]=true;seen["tab:"..tab]=true;seen["type:"..id]=true end
        units=units+amount
        if units>9007199254740991 then return nil end
    end
    if parse==nil then return nil end
    return #parts,units,seen
end
local function bagPart(part)
    local id,amount=part:match("^([^:]+):([^:]+)$")
    id,amount=decimal(id,1,MAX),decimal(amount,1,9007199254740991)
    return id,amount
end
local function bankPart(part)
    local tab,id,amount=part:match("^([^:]+):([^:]+):([^:]+)$")
    tab,id,amount=decimal(tab,6,14),decimal(id,1,MAX),decimal(amount,1,9007199254740991)
    if not tab then return nil end
    return id,amount,tab
end
local function legacy(kind,guid)
    local root=MclarionWowData
    local field=kind=="character" and "characters" or kind
    if not plain(root) then return "unavailable" end
    local schema=rawget(root,"schema")
    if not safe(schema) or (schema~=1 and schema~=2) then return "unavailable" end
    if kind=="items" and schema~=2 then return "no observation" end
    local map=rawget(root,field)
    if map==nil and kind=="items" then return "unavailable" end
    if map==nil and kind~="character" then return "no observation" end
    if not plain(map) then return "unavailable" end
    if kind=="items" then
        local group=rawget(map,guid)
        if group==nil then return "no observation" end
        if not plain(group) then return "unavailable" end
        local function metadata(record)
            local _,f=wire(record,guid,"MHWOWI1",7,32768)
            if not f or not f[6]:match("^[a-z][a-z][A-Z][A-Z]$") or f[7]=="" then return nil end
            local values=split(f[7],";",128)
            if not values or #values>128 then return nil end
            local prev=0
            for _,row in ipairs(values) do
                local parts=split(row,":",19)
                if not parts or #parts~=19 then return nil end
                local id=decimal(parts[1],1,MAX)
                if not id or id<=prev or not parts[2]:match("^[0-9A-F]+$") or
                    #parts[2]>320 or #parts[2]%2~=0 or
                    parts[18]~="0" and parts[18]~="1" then return nil end
                for _,position in ipairs({4,5,6,9,11,12,13,14,15,16}) do
                    if not decimal(parts[position],0,MAX) then return nil end
                end
                if parts[17]~="" and not decimal(parts[17],0,MAX) then return nil end
                for _,position in ipairs({3,7,8,10,19}) do
                    local text=parts[position]
                    if #text>1024 or #text%2~=0 or not text:match("^[0-9A-F]*$") then return nil end
                end
                prev=id
            end
            return #values
        end
        local bag=rawget(group,"bags")
        local bagCount=bag==nil and "no observation" or metadata(bag)
        if not bagCount then bagCount="unavailable" end
        local bank=rawget(group,"bank")
        local bankCount="no observation"
        if bank~=nil then
            local n=array(bank,9,false)
            if not n then bankCount="unavailable" else
                bankCount=0
                for i=1,n do
                    local count=metadata(rawget(bank,i))
                    if not count then bankCount="unavailable";break end
                    bankCount=bankCount+count
                end
            end
        end
        local a=type(bagCount)=="number" and (bagCount.." cached") or bagCount
        local b=type(bankCount)=="number" and (bankCount.." cached") or bankCount
        return "Items latest saved metadata: bags/gear "..a.."; bank "..b.."."
    end
    local function parse(record,who)
        local tag=kind=="character" and "MHWOW1" or kind=="bags" and "MHWOWB1" or "MHWOWK1"
        local count=kind=="character" and 12 or 6
        local stamp,f=wire(record,who,tag,count,kind=="bags" and 16000 or kind=="bank" and 32768 or 4096,
            kind=="character" and 12 or 6)
        if not stamp then
            if kind~="character" then return nil end
            stamp,f=wire(record,who,"MHWOW2",15,4096,12)
            if not stamp then return nil end
        end
        if kind=="character" then
            local gear=split(f[11],",",19)
            if not gear or #gear~=19 then return nil end
            local equipped=0
            for _,id in ipairs(gear) do
                local number=decimal(id,0,MAX)
                if not number then return nil end
                if number>0 then equipped=equipped+1 end
            end
            return stamp,equipped
        end
        local text=f[5]
        local types,units,seen=entries(text,",",kind=="bags" and 128 or 1080,
            kind=="bags" and bagPart or bankPart)
        if not types then return nil end
        local tabs=0
        if kind=="bank" then
            local unique=0
            for k in pairs(seen) do
                if k:sub(1,4)=="tab:" then tabs=tabs+1 end
                if k:sub(1,5)=="type:" then unique=unique+1 end
            end
            types=unique
        end
        return stamp,types,units,tabs
    end
    local n,last=history(map,guid,20,parse)
    if not n then return last end
    local _,a,b,c=parse(last,guid)
    if kind=="character" then return "Character latest saved: "..n.." observations; "..a.." equipped items." end
    if kind=="bags" then return "Bags latest saved: "..n.." observations; "..a.." types, "..b.." units." end
    return "Bank latest saved: "..n.." observations; "..c.." tabs with items, "..a.." types, "..b.." units (empty tabs not encoded)."
end
local function progression(kind,guid)
    local quest=kind=="quest"
    local root=quest and MclarionWowQuestData or MclarionWowReputationData
    local map=rootMap(root,"characters",1)
    if not map then return "unavailable" end
    local function parse(record,who)
        local stamp,f=wire(record,who,quest and "MHWOWQ1" or "MHWOWR1",quest and 9 or 11,quest and 4096 or 32768)
        if not stamp or f[6]~=(quest and "active-log" or "visible-ui") then return nil end
        local rows=decimal(f[7],0,quest and 128 or 256)
        local leaves=decimal(f[8],0,quest and 100 or 200)
        if not rows or not leaves or leaves>rows then return nil end
        if not quest then
            local header=decimal(f[9],0,256);local collapsed=decimal(f[10],0,256)
            if not header or not collapsed or leaves+header>rows or leaves+collapsed>rows then return nil end
        end
        local data=f[quest and 9 or 11]
        if data=="" then if leaves~=0 then return nil end;return stamp,leaves end
        local parts=split(data,quest and "," or ";",quest and 100 or 200)
        if not parts or #parts~=leaves then return nil end
        local previous=0
        for _,entry in ipairs(parts) do
            local id
            if quest then id=decimal(entry,1,MAX) else
                local values=split(entry,":",5)
                if not values or #values~=5 then return nil end
                id=decimal(values[1],1,MAX)
                if not decimal(values[2],1,16) then return nil end
                local minimum,maximum,value=signed(values[3]),signed(values[4]),signed(values[5])
                if not minimum or not maximum or not value or minimum>=maximum or
                    value<minimum or value>maximum then return nil end
            end
            if not id or id<=previous then return nil end
            previous=id
        end
        return stamp,leaves
    end
    local n,last=history(map,guid,20,parse)
    if not n then return last end
    local _,leaves=parse(last,guid)
    if quest then return "Quest latest saved: "..n.." observations; "..leaves.." active quest IDs (not completed history)." end
    return "Reputation latest saved: "..n.." observations; "..leaves.." visible character faction "..(leaves==1 and "leaf" or "leaves").." (partial UI)."
end
local function wealth(kind,guid)
    local root=MclarionWowWealthData
    local map=rootMap(root,"characters",1)
    if not map or not plain(rawget(root,"accountCurrency")) then return "unavailable" end
    local group=rawget(map,guid)
    local h
    if group~=nil then
        if not plain(group) then return "unavailable" end
        h=rawget(group,kind=="gold" and "gold" or "currency")
    end
    local function currency(record,account)
        if not plain(record) or not num(rawget(record,"at"),1,253402300799) or
            not num(rawget(record,"build"),1,MAX) or rawget(record,"scope")~="visible-ui" or
            not num(rawget(record,"rows"),0,256) then return nil end
        local observer=rawget(record,"observedBy")
        if not safe(observer) or (account and not owner(observer)) or (not account and observer~=nil) then return nil end
        local values=rawget(record,"values")
        local n=array(values,200,true)
        if not n or n>rawget(record,"rows") then return nil end
        local previous=0
        for i=1,n do
            local entry=rawget(values,i)
            if not plain(entry) then return nil end
            local id,quantity=rawget(entry,"id"),rawget(entry,"quantity")
            if not num(id,1,MAX) or id<=previous or not num(quantity,0,9007199254740991) then return nil end
            previous=id
        end
        return rawget(record,"at"),n,observer
    end
    local function gold(record)
        if not plain(record) or not num(rawget(record,"at"),1,253402300799) or
            not num(rawget(record,"build"),1,MAX) or
            not num(rawget(record,"copper"),0,9007199254740991) then return nil end
        return rawget(record,"at"),rawget(record,"copper")
    end
    local function extract(t, parser)
        if t==nil then return nil,"no observation" end
        local n=array(t,20,false)
        if not n then return nil,"unavailable" end
        local previous=0
        for i=1,n do
            local stamp=parser(rawget(t,i))
            if not stamp or stamp<=previous then return nil,"unavailable" end
            previous=stamp
        end
        return n,rawget(t,n)
    end
    if kind=="gold" then
        local n,last=extract(h,gold)
        if not n then return last end
        local _,copper=gold(last)
        local g=math.floor(copper/10000); local s=math.floor(copper%10000/100);local c=copper%100
        return "Gold latest saved: "..n.." observations; "..g.."g "..s.."s "..c.."c."
    end
    local n,last=extract(h,function(r) return currency(r,false) end)
    local own=n and (select(2,currency(last,false)).." visible "..(select(2,currency(last,false))==1 and "entry" or "entries").." ("..n.." observations)") or last
    local account=rawget(root,"accountCurrency")
    local m,latest
    if array(account,20,true)==0 then latest="no observation"
    else m,latest=extract(account,function(r) return currency(r,true) end) end
    local accountText
    if not m and latest=="no observation" then accountText="no observation"
    elseif not m then accountText="unavailable"
    else
        local _,count,observer=currency(latest,true)
        accountText=observer==guid and (count.." visible "..(count==1 and "entry" or "entries").." (observed by current character; "..m.." observations)") or
            "unavailable (latest observed by other character)"
    end
    return "Currency latest saved: character: "..own.."; account-wide: "..accountText.."."
end
local function honorTitle(kind,guid)
    local map=rootMap(MclarionWowHonorTitleData,"characters",1)
    if not map then return "unavailable" end
    local group=rawget(map,guid)
    if group==nil then return "no observation" end
    if not plain(group) then return "unavailable" end
    local records=rawget(group,kind)
    if records==nil then return "no observation" end
    local function parse(record,who)
        local stamp,f=wire(record,who,kind=="honor" and "MHWOWH1" or "MHWOWT1",kind=="honor" and 15 or 8,4096)
        if not stamp then return nil end
        if kind=="honor" then
            local v={}
            for i=6,15 do v[i]=decimal(f[i],0,(i==7 or i==12 or i==15) and 64 or MAX);if not v[i] then return nil end end
            if v[12]>v[15] or v[13]>v[14] then return nil end
            return stamp,v[6]
        end
        local selected=decimal(f[7],0,512)
        if not selected then return nil end
        local ids=f[8]=="" and {} or split(f[8],",",512)
        if not ids then return nil end
        local previous,found=0,false
        for _,text in ipairs(ids) do
            local id=decimal(text,1,512)
            if not id or id<=previous then return nil end
            if id==selected then found=true end
            previous=id
        end
        if (selected==0 and f[6]~="none") or
            (selected>0 and (f[6]~="active:"..selected or not found)) then return nil end
        return stamp,#ids,selected
    end
    local n,last=history({[guid]=records},guid,20,parse)
    if not n then return last end
    local _,a,b=parse(last,guid)
    if kind=="honor" then return "Honor latest saved: "..n.." observations; "..a.." lifetime honorable kills (not earned honor)." end
    return "Title latest saved: "..n.." observations; "..a.." known titles; "..(b==0 and "none selected" or "selected").." (no acquisition dates)."
end
local allowed={character=true,bags=true,bank=true,items=true,combat=true,quest=true,reputation=true,gold=true,currency=true,honor=true,title=true}
local function summary(key)
    if not safe(key) or type(key)~="string" or #key>20 or not allowed[key] then return "Summary unavailable." end
    if key=="combat" then return "Combat: native file; no addon observations or saved count." end
    if type(issecretvalue)~="function" or type(issecrettable)~="function" then return key..": unavailable" end
    local fn=UnitGUID
    if not safe(fn) or type(fn)~="function" then return key..": unavailable" end
    local ok,guid=pcall(fn,"player")
    if not ok or not owner(guid) then return key..": unavailable" end
    local result
    if key=="character" or key=="bags" or key=="bank" or key=="items" then result=legacy(key,guid)
    elseif key=="quest" or key=="reputation" then result=progression(key,guid)
    elseif key=="gold" or key=="currency" then result=wealth(key,guid)
    else result=honorTitle(key,guid) end
    if result=="unavailable" or result=="no observation" then return key..": "..result end
    if type(result)~="string" or #result>240 then return key..": unavailable" end
    return result
end
function MclarionWow_DashboardSummary(key)
    local ok,result=pcall(summary,key)
    if not ok then return "Summary unavailable." end
    return result
end
