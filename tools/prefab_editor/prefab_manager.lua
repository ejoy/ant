local task          = require "task"
local import_prefab = require "import_prefab"
local lfs           = require "filesystem.local"
local prefab_view   = require "prefab_view"

local m = {}
local world
function m:init(w)
    world = w
end

local VIEWER <const> = "/pkg/test.prefab_editor/res/"

function m:create_prefab(path)
    if not world then
        print("world not exist.")
        return
    end

    local inputPath = lfs.path(path)
    local fileName = inputPath:filename()

    task.create(function()
        import_prefab(fileName, VIEWER .. fileName .. ".glb")
        world:pub {"instance_prefab", VIEWER .. fileName .. ".glb|mesh.prefab"}
    end)

    -- testcylinder = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.scene|hierarchy_policy",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	-- 		state = ies.create_state "visible|selectable",
	-- 		transform =  {
	-- 			s= 30,
	-- 			t={1, 0.5, 0, 0}
	-- 		},
	-- 		material = "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = "/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin",
	-- 		name = "cylinder",
	-- 	}
	-- }
	-- prefab_view:add(testcylinder)

	-- testcubeid = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.scene|hierarchy_policy",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	-- 		state = ies.create_state "visible|selectable",
	-- 		transform =  {
	-- 			s= 50,
	-- 			t={0, 0.5, 1, 0}
	-- 		},
	-- 		material = "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
	-- 		name = "cube",
	-- 	}
    -- }
end

return m