local ecs = ...
local world = ecs.world


local serialize = import_package "ant.serialize"

local fs = require "filesystem"
local lfs = require "filesystem.local"

local vikingmap = fs.path "/pkg/unity_viking/Assets/viking.map"

local unity_viking_package_local_path = lfs.path "test/samples/unity_viking"
local pm = require "antpm"
pm.register_package(unity_viking_package_local_path)

local sm = require "unityscenemaker"
local ve = ecs.system "viking_export"

function ve:init()
    local ecs_fw = import_package "ant.ecs"
    
    local tmpworld = ecs_fw.new_world(
        {
            args = world.args,
            packages = {
                'unity_viking',
            },
            systems = {},
        }
    )

    sm.create(tmpworld, "/pkg/viking_export/scene/viking_glb.lua")
    local s = serialize.save_world(tmpworld)
    local vfs = require "vfs"
    local localpathname = vfs.realpath(vikingmap:string())
    local f = io.open(localpathname, 'w')
    f:write(s)
    f:close()
end