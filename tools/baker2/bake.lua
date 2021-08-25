--local assetmgr = import_package "ant.asset"
local serialize = import_package "ant.serialize"

local bake2 = require "bake2"
local datalist = require "datalist"

local math3d = require "math3d"
local fs = require "filesystem"

local pkgpath = fs.path(arg[1])
if not fs.exists(pkgpath) then
    error("invalid output pkgpath, need vfs path:".. pkgpath:string())
end

local scenepath = fs.path(arg[2])
if not fs.exists(scenepath) then
    error("invalid output scenepath, need vfs path: ", scenepath:string())
end

local bakescene_path = scenepath / "output"

local scenefile = bakescene_path / "output.txt"
if not fs.exists(scenefile) then
    error(("not found scene output file:%s, it's not a valid bake path"):format(scenefile:string()))
end

local function readfile(filename)
    local f = fs.open(filename, "rb")
    local c = f:read "a"
    f:close()
    return c
end

local scene = datalist.parse(readfile(scenefile))
local filecache = {}
local function read_mesh_content(meshfile)
    local m = filecache[meshfile]
    if m == nil then
        m = serialize.unpack(readfile(meshfile))
        filecache[meshfile] = m
    end
    return m
end

local struct_scene = {}
local models = {}
local lights = {}
local materials = {}
for _, e in ipairs(scene) do
    if e.mesh then
        local m = read_mesh_content(bakescene_path / e.mesh)
        e.meshdata = m

        models[#models+1] = {
            worldmat = math3d.tovalue(math3d.matrix(e)),
            positions = 
        }
    elseif e.light then
    end
end



local b = bake2.create(scene)
local bakeresult = bake2.bake(b)
b.destroy()

-- local function create_world()
--     local ecs = import_package "ant.luaecs"
--     local cr = import_package "ant.compile_resource"
--     local world = ecs.new_world {
--         width  = 0,
--         height = 0,
--     }
--     cr.set_identity "windows_direct3d11"
--     assert(loadfile "/pkg/ant.prefab/prefab_system.lua")({world = world})
--     function world:create_entity_template(v)
--         return v
--     end
--     return world
-- end

-- local world = create_world()

-- print "ok"
