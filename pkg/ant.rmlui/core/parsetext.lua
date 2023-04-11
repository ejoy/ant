local m={}
local filemanager = require "core.filemanager"
local ltask = require "ltask"
local ServiceResource = ltask.queryservice "ant.compile_resource|resource"
local texture_map = {}
local texture_table = filemanager.getTextureTable()
local path_table = texture_table.path_table
local rect_table = texture_table.rect_table
for path_idx, path in pairs(path_table) do
    ltask.fork(function ()
    local info = ltask.call(ServiceResource, "texture_create", path)
        texture_map[path_idx] = {
            id = info.id,
            width = info.texinfo.width,
            height = info.texinfo.height
        }
    end) 
end 

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
local images = {}
local imagemap = {}

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
   local prevtext = string.sub(str, 1, gstart - 1)
   local textinfo = prevtext .. string.sub(str, gend+1, string.len(str))

   for k,v in string.gmatch(grouptext, "/(%w+):(%w+)") do
        group[k] = v
   end

   if next(group)==nil then
        error("group need state like /key1:value1 /key2:value2 ...")
   end

   local idx = 1
   local mstart, mend, chs = string.find(textinfo, "([^{}]*)", idx)
   while mstart do
    for i=1, string.len(chs) do
        local ch = string.sub(chs, i, i)
        if ch == "`" then
            imagemap[#imagemap+1] = groupmapidx
            groupmap[groupmapidx] = 100 + #imagemap
            ctable[#ctable+1] = ch
        else
            ctable[#ctable+1] = ch
            groupmap[groupmapidx] = curidx
        end
        groupmapidx = groupmapidx + 1
    end
    idx = mend+1
    while idx <= string.len(textinfo) do
            local istart, iend, ichs = string.find(textinfo, "(%b{})", idx)
            if not iend or istart ~= idx then
                break
            end
            idx = iend + 1
            if ichs then
                preorder(ichs)
            end
        end
        mstart, mend, chs = string.find(textinfo, "([^{}]+)", idx)
   end
end

local function replace_image(os)

    for image_text in string.gmatch(os, "%([_,%.%w]+%)") do
        images[#images+1] = {id = nil, rect = {}}
        local str = string.sub(image_text, 2, string.len(image_text) - 1)
        for k in string.gmatch(str, "[^,]+") do
            local texture_info
            while(not texture_info) do
                texture_info = texture_map[rect_table[k].path_idx]
            end
            images[#images].id = texture_info.id
            images[#images].rect = rect_table[k].rect
            images[#images].width = texture_info.width
            images[#images].height = texture_info.height
        end
   end
   os = string.gsub(os, "%([_,%.%w]+%)", "`")
   return os
end



function m.ParseText(os)
    ctext = ""
    ctable = {}
    groups = {}
    groupmap = {}
    groupsidx = 1
    groupmapidx = 1
    images = {}
    imagemap = {}
    local replaced_os = replace_image(os)
    local s = prereplace(replaced_os)
    preorder(s)
    ctext = table.concat(ctable, nil)
    return ctext, groups, groupmap, images, imagemap
end

return m