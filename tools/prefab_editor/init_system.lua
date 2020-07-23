local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local irq = world:interface "ant.render|irenderqueue"
local camera = world:interface "ant.camera|camera"
local entity = world:interface "ant.render|entity"
local m = ecs.system 'init_system'
local imgui      = require "imgui"
--local prefab_mgr = require "prefab_manager"
local iom = world:interface "ant.objcontroller|obj_motion"
local worldedit = require "worldedit"(world)
local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local vfs = require "vfs"
local root
local entities = {}
local prefab
local function normalizeAabb()
    local aabb
    for _, eid in ipairs(entities) do
        local e = world[eid]
        if e.mesh and e.mesh.bounding then
            local newaabb = math3d.aabb_transform(iom.calc_worldmat(eid), e.mesh.bounding.aabb)
            aabb = aabb and math3d.aabb_merge(aabb, newaabb) or newaabb
        end
    end

    if not aabb then return end

    local aabb_mat = math3d.tovalue(aabb)
    local min_x, min_y, min_z = aabb_mat[1], aabb_mat[2], aabb_mat[3]
    local max_x, max_y, max_z = aabb_mat[5], aabb_mat[6], aabb_mat[7]
    local s = 1/math.max(max_x - min_x, max_y - min_y, max_z - min_z)
    local t = {-(max_x+min_x)/2,-min_y,-(max_z+min_z)/2}
    local transform = math3d.mul(math3d.matrix{ s = s }, { t = t })
    iom.set_srt(root, math3d.mul(transform, iom.srt(root)))
end

local function LoadImguiLayout(filename)
    local rf = lfs.open(filename, "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
end

function m:init()
    imgui.setDockEnable(true)
    LoadImguiLayout(vfs.repo()._root .. "/" .. "imgui.layout")

	--prefab_mgr:init(world)
    entity.create_procedural_sky()
    local e = world:singleton_entity "main_queue"
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
    camera.bind(camera.create {
        eyepos = {-200, 100,200, 1},
        viewdir = {2,-1,-2,0},
        frustum = {f = 1000}
    }, "main_queue")
    -- local cu = import_package "ant.render".components
    -- entity.create_plane_entity(
	-- 	{srt = {t = {0, 0, 0, 1}, s = {50, 1, 50, 0}}},
	-- 	"/pkg/ant.resources/materials/mesh_shadow.material",
	-- 	{0.8, 0.8, 0.8, 1},
	-- 	"test shadow plane"
    -- )
    entity.create_grid_entity("", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
	--local axis = entity.create_axis_entity()
    --world:instance '/pkg/tools.viewer.prefab_viewer/light_directional.prefab'
    world:instance "res/light_directional.prefab"
	-- local res = world:instance "res/fox.glb|mesh.prefab"
	-- world[res[3]].transform =  {s={0.01}}
    -- world:add_policy(res[3], {
    --     policy = {
	-- 		"ant.objcontroller|select"
	-- 	},
    --     data = {
	-- 		can_select = true,
	-- 		name = "fox",
	-- 	},
    -- })

    -- local cubeid = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	--		state = ies.create_state "visible|selectable",
	-- 		transform =  {
	-- 			s=100,
	-- 			t={0, 2, 0, 0}
	-- 		},
	-- 		material = "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
	-- 		name = "test_cube",
	-- 	}
	-- }
	--imaterial.set_property(cubeid, "u_color", {1, 1, 1, 1})
end

local function instancePrefab(filename)
    if root then world:remove_entity(root) end
    for _, eid in ipairs(entities) do
        world:remove_entity(eid)
    end

    root = world:create_entity {
        policy = {
            "ant.scene|transform_policy",
        },
        data = {
            transform = {},
            scene_entity = true,
        }
    }
    prefab = worldedit:prefab_template(filename)
    entities = worldedit:prefab_instance(prefab, {root=root})
    --worldedit:prefab_set(prefab, "/3/data/state", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    normalizeAabb()
    world:pub {"editor", "prefab", entities}
end

local eventInstancePrefab = world:sub {"instance_prefab"}
local eventSerializePrefab = world:sub {"serialize_prefab"}

function m:data_changed()
    for _, filename in eventInstancePrefab:unpack() do
        instancePrefab(filename)
    end
    for _, filename in eventSerializePrefab:unpack() do
        serializePrefab(filename)
    end
end