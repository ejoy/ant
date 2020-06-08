local cr = import_package "ant.compile_resource"
local thread = require "thread"
local math3d = require "math3d"
local function create_bounding(bounding)
    if bounding then
        bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
    end
end
local function loader(filename, world)
    local c = cr.read_file(filename)
    local mesh = thread.unpack(c)
    create_bounding(mesh.bounding)
    return world.component "mesh" (mesh)
end
local function unloader()
end
return {
    loader = loader,
    unloader = unloader,
}
