local serialize = import_package "ant.serialize"
local aio       = import_package "ant.io"
local vfs               = require "vfs"
local lfs       = require "bee.filesystem"
local fs        = require "filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"

local settingpath = lfs.path(vfs.repopath()):parent_path():parent_path():string().."/pkg/tools.editor/editor.settings"
local function read()
    if not io.open(settingpath, "r") then
        return {}
    end
    return datalist.parse(fastio.readall(settingpath))
end

local editor_setting = read()

local function save()
    local f <close> = assert(io.open(settingpath, "w"))
    local c = serialize.stringify(editor_setting)
    f:write(c)
end

local function update_lastproj(name, projpath)
    if not editor_setting.lastprojs then
        editor_setting.lastprojs = {}
    end
    projpath = projpath:gsub("\\", "/")
    local proj_list = {
        {name = name, proj_path = projpath}
    }
    for _, proj in ipairs(editor_setting.lastprojs) do
        if projpath ~= proj.proj_path then
            proj_list[#proj_list + 1] = proj
        end
    end
    editor_setting.lastprojs = proj_list
    save()
end

return {
    update_lastproj = update_lastproj,
    setting = editor_setting,
}