local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local ientity 	= world:interface "ant.render|entity"
local ies 		= world:interface "ant.scene|ientity_state"
local iom 		= world:interface "ant.objcontroller|obj_motion"
local icamera 	= world:interface "ant.camera|camera"
local irq		= world:interface "ant.render|irenderqueue"
local lm_baker = ecs.system "lightmap_baker_system"

local function create_lm_entity(name, material, m, srt)
    return world:create_entity {
		policy = {
			"ant.render|render",
            "ant.bake|lightmap",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= m,
			state		= ies.create_state "visible|lightmap",
            lightmap    = {
                size = 64,
            },
			name		= name,
			scene_entity= true,
		}
	}
end

function lm_baker:init()
    world:instance "/pkg/ant.tool.lightmap_baker/assets/light.prefab"
    ientity.create_procedural_sky()

    local p = world:instance "/pkg/ant.tool.lightmap_baker/assets/box.glb|mesh.prefab"

	local eid = p[1]
    local s = iom.get_scale(eid)
    iom.set_scale(eid, math3d.mul(s, {100, 100, 100, 0}))
end

function lm_baker:init_world()
	local mceid = irq.main_camera()
	local p = math3d.vector(0, 5, 12)
	iom.set_position(mceid, p)
	iom.set_direction(mceid, math3d.inverse(p))

	world:pub{"bake"}	--bake all scene
end

local bake_finish_mb = world:sub{"bake_finish"}

function lm_baker:data_changed()
	for msg in bake_finish_mb:each() do
		local id = msg[2]
		if id == nil then
		else
			for e in w:select "lightmap:in" do
				local lm = e.lightmap
				lm.data:save ""
			end
		end
	end
end