--[[
identity:
    osx_metal
    ios_metal
    windows_direct3d11
]]

local project, identity = ...
identity = identity or "ios_metal"
_VFS_ROOT_ = assert(project, "Need project dir.")

package.path = "engine/?.lua;tools/prebuilt/?.lua"
require "bootstrap"
local fs = require "filesystem"
local prebuilt = require "prebuilt"

local function read_prebuilt()
    local f = assert(fs.open(fs.path "prebuilt"))
    local data = f:read "a"
    f:close()
    local datalist = require "datalist"
    return datalist.parse(data)
end

local prebuiltResource

local supports = {
    material = true,
    prefab = true,
    glb = true,
    texture = true,
}

local function supportsExtension(path)
    local ext = path:extension():string():sub(2):lower()
    return supports[ext] and true or false
end

local function prebuiltFolder(folder, setting)
    for path in folder:list_directory() do
        if supportsExtension(path) then
            prebuiltResource {
                path = path:string(),
                setting = setting,
            }
        end
    end
end

function prebuiltResource(config)
    assert(config.path)
    local path = fs.path(config.path)
    if fs.is_directory(path) then
        prebuiltFolder(path, config.setting)
    else
        local type = config.type and config.type or path:extension():string():sub(2)
        prebuilt.load(type, config.path, config.setting)
    end
end

for _, config in ipairs(read_prebuilt()) do
    if config.type == "fx" and not config.path then
        prebuilt.load_fx(config)
    else
        prebuiltResource(config)
    end
end

prebuilt.build(identity)
