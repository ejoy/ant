local assetmgr = import_package "ant.asset"

local function create_world()
    local ecs = import_package "ant.ecs"
    local cr = import_package "ant.compile_resource"
    local world = ecs.new_world {
        width  = 0,
        height = 0,
    }
    cr.set_identity "windows_direct3d11"
    return world
end

local world = create_world()
local prefab = assetmgr.resource("/pkg/ant.test.noecs/Fox.glb|mesh.prefab", world)

print "ok"
