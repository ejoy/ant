local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local skypkg = import_package "ant.sky"
local serialize = import_package 'ant.serialize'
local imgui = require "imgui.ant"
local fs = require "filesystem"

local skyutil = skypkg.util
local ms = mathpkg.stack
local mu = mathpkg.util
local mc = mathpkg.constant

local lu = renderpkg.light
local cu = renderpkg.components
local defaultcomp = renderpkg.default

local m = ecs.system "model_review_system"

m.require_policy "ant.sky|procedural_sky"
m.require_policy "ant.serialize|serialize"
m.require_policy "ant.bullet|collider.capsule"
m.require_policy "ant.render|mesh"
m.require_policy "ant.render|render"
m.require_policy "ant.render|name"
m.require_policy "ant.render|shadow_cast"
m.require_policy "ant.render|light.directional"
m.require_policy "ant.render|light.ambient"

m.require_system "ant.sky|procedural_sky_system"

m.require_system "ant.imguibase|imgui_system"
m.require_system "ant.camera_controller|camera_system"


local function create_light()
	lu.create_directional_light_entity(world, "direction light", 
		{1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local singlecolor_material = fs.path "/pkg/ant.resources/depiction/materials/singlecolor.material"
local function create_material_item(filepath, color)
	return {
		ref_path = filepath,
		properties = {
			uniforms = {
				u_color = {type = "color", name = "Color", value = color},
			}
		},
	}
end

local function a2c(t)
	local r = t[1]
	for i = 2, #t do
		r[i-1] = t[i]
	end
	return r
end


local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    world:pub {"spawn_camera", "test_main_camera", {
        type    = "",
        eyepos  = {0, 3, -10, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    }}
end

function m:init()
	create_camera()
	create_light()
	
	skyutil.create_procedural_sky(world, {follow_by_directional_light=false})

	--cu.create_grid_entity(world, "grid")
	cu.create_plane_entity(world, 
		{50, 1, 50, 0}, nil, 
		fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material", 
		{0.8, 0.8, 0.8, 1},
		"test shadow plane")

	--cu.create_axis_entity(world, mu.translate_mat{0, 0, 1})

	local default_policy = {
		"ant.render|render",
		"ant.render|mesh",
		"ant.render|shadow_cast",
		"ant.render|name",
		"ant.serialize|serialize",
	}
	local origineid = world:create_entity {
		policy = default_policy,
		data = {
			transform 	= mu.scale_mat(0.2),
			rendermesh 	= {},
			mesh 		= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/campsite-door.mesh",},
			material 	= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/scene-mat.material",},
			can_render 	= true,
			can_cast	= true,
			name 		= "door",
			serialize   = serialize.create(),
		}
	}

	world:create_entity {
		policy = default_policy,
		data = {
			transform 	= mu.srt({0.2, 0.2, 0.2, 0}, nil, {5, 0, 0, 0}),
			rendermesh 	= {},
			mesh 		= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/woodother-34.mesh", },
			material 	= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/scene-mat.material", },
			can_render 	= true,
			can_cast	= true,
			name 		= "door",
			serialize   = serialize.create(),
		}
	}

	-- local originentity = world[origineid]
	-- local s, r, t = ms(originentity.transform.t, originentity.transform.r, originentity.transform.s, "TTT")
	-- world:create_entity {
	-- 	transform 	= mu.srt(s, r, t),
	-- 	rendermesh 	= {},
	-- 	material 	= {{ref_path = fs.path "/pkg/ant.resources/depiction/materials/outline/scale.material",}},
	-- 	can_render 	= true,
	-- 	main_view 	= true,
	-- 	name 		= "door_outline",
	-- }

	local eid = world:create_entity {
		policy = default_policy,
		data = {
			transform = mu.srt({0.1, 0.1, 0.1, 0}, nil,  {0, 0, 10, 0}),
			can_render = true,
			rendermesh = {
				submesh_refs = {
					["build_big_storage_01_fence_02"] 		= cu.create_submesh_item {1}, 
					["build_big_storage_01_pillars_01"] 	= cu.create_submesh_item {2, 3},
					["build_big_storage_01_straw_roof_002"] = cu.create_submesh_item {4, 5, 6, 7},
					["build_big_storage_01_walls_down"] 	= cu.create_submesh_item {2},
					["build_big_storage_01_walls_up"] 		= cu.create_submesh_item {2},
				},
			},
			mesh = {
				ref_path = fs.path "/pkg/ant.resources/depiction/meshes/test_glb.mesh",
			},
			material = a2c {
				create_material_item(singlecolor_material, {1, 0, 0, 0}),
				create_material_item(singlecolor_material, {0, 1, 0, 0}),
				create_material_item(singlecolor_material, {0, 0, 1, 0}),
				create_material_item(singlecolor_material, {1, 1, 0, 0}),
				create_material_item(singlecolor_material, {1, 0, 1, 0}),
				create_material_item(singlecolor_material, {0, 1, 1, 0}),
				create_material_item(singlecolor_material, {1, 1, 1, 0}),
			},
			can_cast = true,
			name = "test_glb",
			serialize   = serialize.create(),
		}
	}
	
    --local function save_file(file, data)
    --    assert(assert(io.open(file, 'w')):write(data)):close()
    --end
    --local function load_file(file)
    --    local f = assert(io.open(file, 'r'))
    --    local data = f:read 'a'
    --    f:close()
    --    return data
    --end
    --local s = serialize.v2.save_entity(world, eid, default_policy)
    --save_file('tools/modelviewer/serialize_entity.txt', s)
    --world:remove_entity(eid)
    --world:create_entity(load_file 'tools/modelviewer/serialize_entity.txt')
end

local function memory_info()
	local function bytestr(n)
		if n < 1024 then
			return ("%dB"):format(n)
		end
		n = n / 1024.0
		if n < 1024 then
			return ("%.1fKB"):format(n)
		end
		n = n / 1024.0
		return ("%.1fMB"):format(n)
	end

	local s = {}
	local platform = require "platform"
	local bgfx = require "bgfx"
	s[#s+1] = ""
	s[#s+1] = ("sys   memory:%s"):format(bytestr(platform.info "memory"))
	s[#s+1] = ("lua   memory:%s"):format(bytestr(collectgarbage "count" * 1024.0))
	s[#s+1] = ("bgfx  memory:%s"):format(bytestr(bgfx.get_memory()))
	s[#s+1] = ("math  memory:%s"):format(bytestr(ms:stacksize()))
	s[#s+1] = ("imgui memory:%s"):format(bytestr(imgui.ant.get_memory()))
	
	s[#s+1] = "-------------------"

	local data = bgfx.get_stats "m"
	s[#s+1] = ("rt   memory:%s"):format(bytestr(data.rtMemoryUsed))
	s[#s+1] = ("tex  memory:%s"):format(bytestr(data.textureMemoryUsed))
	s[#s+1] = ("vb   memory:%s"):format(bytestr(data.transientVbUsed))
	s[#s+1] = ("ib   memory:%s"):format(bytestr(data.transientIbUsed))
	s[#s+1] = ""

	local leaks = ms:leaks()
	if leaks and #leaks >= 0 then
		s[#s+1] = "-------------------"
		s[#s+1] = ("math3d leaks: %d"):format(#leaks)
	end
	
	return table.concat(s, "\t\n\t")
end

local function defer(f)
    local toclose = setmetatable({}, { __close = f })
    return function (_, w)
        if not w then
            return toclose
        end
    end, nil, nil, toclose
end

local function imgui_windows(...)
	imgui.windows.Begin(...)
	return defer(function()
		imgui.windows.End()
	end)
end

local event = world:sub {"mouse",nil,"MOVE"}
function m:ui_update()
	for a,b,c in event:unpack() do
		print(a,b,c)
	end
	local widget = imgui.widget
	for _ in imgui_windows("Test") do
		widget.Text(memory_info())
	end
end

