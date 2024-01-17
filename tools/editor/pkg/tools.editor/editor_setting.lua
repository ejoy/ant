local serialize = import_package "ant.serialize"
local vfs       = require "vfs"
local lfs       = require "bee.filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"

local settingpath<const> = lfs.path(vfs.repopath()):string() .. "pkg/tools.editor/editor.settings"
local editor_setting = lfs.exists(settingpath) and datalist.parse(fastio.readall_f(settingpath)) or {}

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
end

local function add_recent_file(f)
    local function find_recent_file(f, rf)
        for idx, ff in ipairs(rf) do
            if ff == f then
                return idx
            end
        end
    end

    local rf = editor_setting.recent_files
    if rf == nil then
        rf = {}
        editor_setting.recent_files = rf
    end

    local idx = find_recent_file(f, rf)

    if idx == nil and #rf == 10 then
        idx = 10
    end

    if idx then
        table.remove(rf, idx)
    end
    table.insert(rf, 1, f)
    assert(#rf <= 10)
end

local function update_camera_setting(speed)
    local cs = editor_setting.camera
    if cs == nil then
        cs = {}
        editor_setting.camera = cs
    end
    cs.speed = speed
end

return {
    update_lastproj = update_lastproj,
    add_recent_file = add_recent_file,
    update_camera_setting = update_camera_setting,
    setting = editor_setting,
    save = save,
}