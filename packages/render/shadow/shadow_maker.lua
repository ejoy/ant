local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local mathbaselib = require "math3d.baselib"

local viewidmgr = require "viewid_mgr"
local renderutil = require "util"
local computil = require "components.util"
local fs = require "filesystem"
local geodrawer = import_package "ant.geometry".drawer
local declmgr = require "vertexdecl_mgr"
local bgfx = require "bgfx"

ecs.component "shadow"
	.material "material_content"
	.shadowmap_with "int" (1024)
	.shadowmap_height "int" (1024)

local maker_camera = ecs.system "shadowmaker_camera"
maker_camera.depend "primitive_filter_system"
maker_camera.dependby "filter_properties"
	
--TODO, this "update" function can be changed as "postinit" function
-- just only listening new/delete/modify any objects boundings
function maker_camera:update()
	local sm = world:first_entity "shadow"
	local dl = world:first_entity "directional_light"
	local camera = sm.camera
	local scenebounding = sm.primitive_filter.scenebounding
	local sphere = scenebounding.sphere

	ms(camera.viewdir, dl.rotation, "dn=")	
	ms(camera.eyepos, sphere.center, {sphere.radius}, camera.viewdir, "i*+=")
	
	local viewmat = ms(camera.eyepos, camera.viewdir, camera.updir, ms.lookfrom3, "P")
	local aabb_vs = mathbaselib.transform_aabb(ms, viewmat, scenebounding.aabb)
	local lengthaxis = ms({0.5}, aabb_vs.max, aabb_vs.min, "-*T")
	local frustum = camera.frustum
	--assert(frustum.ortho)

	local half_w, half_h = lengthaxis[1], lengthaxis[2]
	frustum.l, frustum.r = -half_w, half_w
	frustum.t, frustum.b = half_h, -half_h
end
	

local sm = ecs.system "shadow_maker11"
sm.depend "primitive_filter_system"
sm.depend "shadowmaker_camera"
sm.dependby "render_system"

function sm:init()	
	local sm_width, sm_height = 1024, 1024
	--local half_sm_width, half_sm_height = sm_width * 0.5, sm_height * 0.5
	world:create_entity {
		shadow = {
			material = {
				ref_path = fs.path "//ant.resources/depiction/shadow/mesh_cast_shadow.material"
			},
			shaodwmap_width = sm_width,
			shadowmap_height = sm_height,
			shadow_distance = 10,
		},
		viewid = viewidmgr.get "shadow_maker",
		primitive_filter = {
			view_tag = "main_view",
			filter_tag = "can_cast",
		},
		camera = {
			type = "shadow",
			eyepos = {0, 0, 0, 1},
			viewdir = {0, 0, 1, 0},
			updir = {0, 1, 0, 0},
			frustum = {
				ortho = true,
				l = -2, r = 2,
				t = 2, b = -2,
				n = 0, f = 100,
			},
		},
		render_target = {
			viewport = {
				rect = {x=0, y=0, w=sm_width, h=sm_height},
				clear_state = {
					color = 0,
					depth = 1,
					stencil = 0,
					clear = "depth",
				}
			},
			frame_buffer = {
				render_buffers = {
					{
						format = "D16F",
						w=sm_width,
						h=sm_height,
						layers=1,
						flags=renderutil.generate_sampler_flag{
							RT="RT_ON",
							MIN="LINEAR",
							MAG="LINEAR",
							U="CLAMP",
							V="CLAMP",
							COMPARE="COMPARE_LEQUAL",
							BOARD_COLOR="0",
						},
					}
				}
			}
		},
		name = "direction light shadow maker",		
	}
end

local function update_shadow_camera(camera, directionallight, distance)
	ms(camera.viewdir, directionallight.rotation, "din=")
	ms(camera.eyepos, {0, 0, 0, 1}, camera.viewdir, {distance}, "*+=")
end

function sm:update()
	local sm = world:first_entity "shadow"

	local filter = sm.primitive_filter
	local results = filter.result
	local function replace_material(result, material)
		for _, p in ipairs(result) do
			p.material = material
		end
	end

	local shadowmat = sm.shadow.material.materialinfo
	replace_material(results.opaque, 		shadowmat)
	replace_material(results.translucent, 	shadowmat)

	update_shadow_camera(sm.camera, world:first_entity "directional_light", sm.shadow.distance)
end

ecs.tag "bounding_debug"
local debug_sm = ecs.system "debug_shadow_maker"
debug_sm.depend "shadow_maker11"

local function get_bounding_decl()
	return declmgr.get("p3|c40niu")
end

local function create_bounding_mesh_entity()
	local eid = world:create_entity {
		mesh = {},
		material = computil.assign_material(fs.path "//ant.resources" / "depiction"/ "line.material"),
		transform = mu.identity_transform(),
		name = "bounding_debug",
		can_render = false,
		main_view = true,
		bounding_debug = true,
	}
	world[eid].mesh.assetinfo = computil.create_dynamic_mesh_handle(get_bounding_decl().handle, 1024*10, 1024*10)
end

function debug_sm:init()
	local qw, qh = 128,128
	computil.create_shadow_quad_entity(world, {x=0, y=0, w=qw, h=qh})
	create_bounding_mesh_entity()
end

local function update_bounding_mesh()
	local boundingdebug = world:first_entity "bounding_debug"
	local desc = {
		vb = {"fffd"}, ib = {},
		primitives = {},
	}
	
	for _, eid in world:each "can_render" do
		local e = world[eid]
		if e.can_render and e.can_cast then
			local meshhandle = e.mesh.assetinfo.handle

			local startvb = #desc.vb - 1
			local startib = #desc.ib
			geodrawer.draw_aabb_box(meshhandle.bounding.aabb, 0x0000f0ff, ms:srtmat(e.transform), desc)

			local endvb = #desc.vb - 1
			local endib = #desc.ib
			desc.primitives[#desc.primitives+1] = {
				start_vertex=startvb, num_vertices=(endvb-startvb) / 4,
				start_index=startib, num_indices=endib-startib,
			}
		end
	end

	local meshhandle = boundingdebug.mesh.assetinfo.handle
	local group = meshhandle.groups[1]
	group.primitives = desc.primitives
	local vbhandle = group.vb.handles[1]
	local ibhandle = group.ib.handle

	local decl = get_bounding_decl()
	local vb, ib = desc.vb, desc.ib
	local numvertex = #desc.vb / 4
	local vbsize = decl.stride * numvertex
	local numib = #desc.ib
	local ibsize = numib * 2 -- 16 bit index = 2 bytes
	bgfx.update(vbhandle, 0, vb)
	bgfx.update(ibhandle, 0, ib)

	boundingdebug.can_render = true
end

function debug_sm:post_init()
	local function has_new_render_entity()
		for _ in world:each_new "can_render" do
			return true
		end
	end
	if has_new_render_entity() then
		update_bounding_mesh()
	end

	local function has_new_directional_light()
		for _ in world:each_new "directional_light" do
			return true
		end
	end

	if has_new_directional_light() then

	end
end

function debug_sm:delete()
	local function check_has_entity_removed()
		for _ in world:each_removed "can_render" do
			return true
		end
	end

	if check_has_entity_removed() then
		update_bounding_mesh()
	end
end