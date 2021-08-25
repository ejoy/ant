local assetmgr = import_package "ant.asset"

local bake2 = require "bake2"

local b = bake2.create()
bake2.bake(b)
b.destroy()

local function create_world()
    local ecs = import_package "ant.luaecs"
    local cr = import_package "ant.compile_resource"
    local world = ecs.new_world {
        width  = 0,
        height = 0,
    }
    cr.set_identity "windows_direct3d11"
    assert(loadfile "/pkg/ant.prefab/prefab_system.lua")({world = world})
    function world:create_entity_template(v)
        return v
    end
    return world
end

local world = create_world()
local prefab = assetmgr.resource("/pkg/ant.test.noecs/Fox.glb|mesh.prefab", world)

print "ok"
