local m={}
local ltask = require "ltask"
local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local datalist   = require "datalist"
local fs = require "filesystem"
local aio = import_package "ant.io"
local config_table, path_table
 local texture_cfg_table = {
} 
local texture_table = {}

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
    for image_text in string.gmatch(os, "<.+>") do
        images[#images+1] = {id = nil, rect = {}}
        local str = string.sub(image_text, 2, string.len(image_text) - 1)
        for k in string.gmatch(str, "[^,]+") do
            local texture_info
            while(not texture_info) do
                texture_info = texture_table[k]
            end
            images[#images].id = texture_info.id
            images[#images].rect = texture_info.rect
            images[#images].width = texture_info.width
            images[#images].height = texture_info.height
        end
   end
   os = string.gsub(os, "<.+>", "`")
   return os
end


for idx, info in pairs(texture_cfg_table) do
    local bundle_cfg_path = fs.path(info.cfg_path)
    if fs.exists(bundle_cfg_path) then
        local cfg = datalist.parse(aio.readall(bundle_cfg_path:string()))
        if cfg then
            if not config_table then
                config_table = {}
                config_table[idx] = cfg
            end
        end
        if not path_table then
            path_table = {}
        end
        path_table[idx] = {path = info.texture_path, list = {}} 
    end
end 

if config_table then
    while (#config_table ~= #texture_cfg_table) do
        ltask.sleep(1)
    end
    for path_idx, t_table in pairs(config_table) do
        for texture_path, texture_info in pairs(t_table) do
            --local texture_name_temp = string.match(texture_path, "[%w%-]+%.")
            local texture_name      = texture_path
            texture_table[texture_name] = {
                    path_idx = path_idx,
                    rect = {x = texture_info.x, y = texture_info.y, w = texture_info.width, h = texture_info.height},
                    id = nil, width = nil, height = nil
            }
            path_table[path_idx].list[texture_name] = true
        end
    end
        
    for path_idx, path_info in pairs(path_table) do
        local info = ltask.call(ServiceResource, "texture_create", path_info.path)
        for abbrev, _ in pairs(path_info.list) do
            texture_table[abbrev].id = info.id
            texture_table[abbrev].width = info.texinfo.width
            texture_table[abbrev].height = info.texinfo.height
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
    images = {}
    imagemap = {}
    local replaced_os = replace_image(os)
    local s = prereplace(replaced_os)
    preorder(s)
    ctext = table.concat(ctable, nil)
    for k, v in pairs(groupmap) do
        groupmap[k] = v-1
    end
    return ctext, groups, groupmap, images, imagemap
end

return m