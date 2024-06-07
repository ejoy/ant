local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.require "ant.entity|entity"
local imesh		= ecs.require "ant.asset|mesh"
local iom		= ecs.require "ant.objcontroller|obj_motion"
local ipt		= ecs.require "ant.landform|plane_terrain"
local common 	= ecs.require "common"

local util		= ecs.require "util"

local PC		= util.proxy_creator()

local function create_instance(pfile, s, r, t)
	s = s or {0.1, 0.1, 0.1}
	return util.create_instance(
        pfile,
		function (p)
			local ee<close> = world:entity(p.tag["*"][1])
			iom.set_scale(ee, s)
	
			if r then
				iom.set_rotation(ee, r)
			end
	
			if t then
				iom.set_position(ee, t)
			end

			PC:add_instance(p)
		end)
end

local function multi_entities()
	local rn = 12
	for i=1, rn * 24 do
		local xidx, zidx = (i-1)%rn, (i-1)//rn
		local pos = math3d.vector(xidx * 80 - 80, 10, zidx * 80 - 80)
		util.create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb/mesh.prefab", function (e)
			local root<close> = world:entity(e.tag['*'][1])
			iom.set_scale(root, 10)
			iom.set_position(root, pos)
			PC:add_instance(e)
		end)
	end

	local cs = 16 * 10

	local positions = {}
	local size = 32
	local offset = (size // 2) * cs
	for j=1, size do
		for i=1, size do
			positions[#positions+1] = {x=(i-1)*cs-offset, y=(j-1)*cs-offset}
		end
	end

	local groups = {
		[0] = positions,
	}

	ipt.create_plane_terrain(groups, "opacity", cs, "/pkg/ant.test.features/assets/terrain/plane_terrain.material")
end

local function plane_entity(srt)
	return world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= srt,
            mesh		= "plane.primitive",
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_masks = "main_view|cast_shadow",
			cast_shadow = true,
			visible     = true,
		}
	}
end

local function simple_entities()
	PC:create_instance{
		prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb/mesh.prefab",
		on_ready = function (p)
			local root<close> = world:entity(p.tag['*'][1], "scene:in")
			iom.set_position(root, math3d.vector(0.0, 1.5, 0.0, 1.0))
		end
	}
	PC:add_entity(util.create_shadow_plane(1000))

	-- PC:create_instance{
	-- 	prefab = "/pkg/ant.test.features/assets/wind-turbine-1.glb/mesh.prefab",
	-- 	on_ready = function (p)
	-- 		local root<close> = world:entity(p.tag['*'][1], "scene:in")
	-- 		iom.set_scale(root, 0.1)
	-- 	end
	-- }

	-- PC:create_instance{
	-- 	prefab = "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb/mesh.prefab", on_ready = function (e)
	-- 	local root<close> = world:entity(e.tag['*'][1])
	-- end}

end

local st_sys	= common.test_system "shadow"
function st_sys:init()
--	multi_entities()
	simple_entities()
end

function st_sys:init_world()
	-- local mq = w:first "main_queue camera_ref:in"
    -- local eyepos = math3d.vector(0, 5, -5)
    -- local camera_ref<close> = world:entity(mq.camera_ref)
    -- iom.set_position(camera_ref, eyepos)
    -- local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    -- iom.set_direction(camera_ref, dir)
	for e in w:select "make_shadow light:in scene:in eid:in" do
		PC:add_entity(ientity.create_arrow_entity(0.3, {1, 1, 1, 1}, "/pkg/ant.resources/materials/meshcolor.material", {parent=e.eid}))
	end
end

local ky_mb = world:sub{"keyboard"}
function st_sys:data_changed()
	for _, key, press in ky_mb:unpack() do
		if key == "L" then
			local D = w:first "directional_light scene:update"
			iom.set_direction(D, math3d.vector(5, -5, 0))
			w:submit(D)
		elseif key == "O" then
			local D = w:first "directional_light scene:update"
			iom.set_direction(D, math3d.vector(0.0, -1.0, 0.0))
			w:submit(D)
		end
	end
end

function st_sys:exit()
	PC:clear()
	ipt.clear_plane_terrain()
end
