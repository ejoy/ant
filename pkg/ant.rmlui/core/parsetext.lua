local m={}

local ctext = ""
local ctable = {}
local rtable = {
    ["r"]="/color:ff0000",
    ["g"]="/color:00ff00",
    ["b"]="/color:0000ff",
    ["u1"]="/underline:false",
    ["u2"]="/underline:true",
}

local default_fmt = "{/color:default %s}"
local bracket_fmt = "{%s}"
local groups = {}
local groupsidx = 1
local groupmap = {}
local groupmapidx = 1

local function prereplace(str)
    if str then
        str=string.gsub(str,"/(%w+)",rtable)
        local bracket_start = string.find(str,"%b{}")
        local group_start = string.find(str,"/(%w+)")
        if bracket_start==1 and string.byte(str,string.len(str))=="}" then
            return str
        elseif bracket_start==1 or group_start~=1 then
            return default_fmt:format(str)
        else
            return bracket_fmt:format(str)
        end
    end
end

local function preorder(str)
   if str then
        str = string.sub(str,1+1,string.len(str)-1)
   else
        return
   end

   local group = {}
   local curidx = groupsidx
   groupsidx = groupsidx+1
   groups[curidx] = group
   local gstart,gend = string.find(str, "[/%w:]+%s")
   local grouptext = string.sub(str, gstart, gend)
   local textinfo = string.sub(str, gend+1, string.len(str))

   for k,v in string.gmatch(grouptext, "/(%w+):(%w+)") do
        group[k] = v
   end

   if next(group)==nil then
        error("group need state like /key1:value1 /key2:value2 ...")
   end

   local idx = 1
   local mstart, mend, chs, subtext = string.find(textinfo, "([^{}]*)(%b{})", idx)
   while mstart do
        for i=1, string.len(chs) do
            ctable[#ctable+1] = string.sub(chs, i, i)
            groupmap[groupmapidx] = curidx
            groupmapidx = groupmapidx+1
        end
        if subtext then
            preorder(subtext)
        end
        idx = mend+1
        mstart, mend, chs, subtext = string.find(textinfo, "([^{}]+)(%b{})", idx)
   end
   if string.find(textinfo, "([^{}]+)", idx-1) then
        chs = string.match(textinfo,"([^{}]+)",idx)
        for i = 1, string.len(chs) do
            ctable[#ctable+1] = string.sub(chs, i, i)
            groupmap[groupmapidx] = curidx
            groupmapidx = groupmapidx + 1
        end
   end 
end

function m.ParseText(os)
    ctext = ""
    ctable = {}
    groups = {}
    groupmap = {}
    groupsidx = 1
    groupmapidx = 1
    local s = prereplace(os)
    preorder(s)
    ctext = table.concat(ctable, nil)
    return ctext, groups, groupmap
end

return m