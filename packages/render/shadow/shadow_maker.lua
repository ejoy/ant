local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local computil 	= require "components.util"

local geodrawer = import_package "ant.geometry".drawer

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"
local mathbaselib = require "math3d.baselib"

ecs.component "shadow"
	.material "material"
	.shadowmap_with "int" (1024)
	.shadowmap_height "int" (1024)

local maker_camera = ecs.system "shadowmaker_camera"
maker_camera.depend "primitive_filter_system"
maker_camera.dependby "filter_properties"
	
--TODO, this "update" function can be changed as "postinit" function
-- just only listening new/delete/modify any objects boundings

local function calc_scene_bounding()
	local sb = mathbaselib.new_bounding(ms)
	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)
	for _, tb in ipairs(transformed_boundings) do
		sb:merge(tb)
	end
	return sb
end

function maker_camera:update()
	local sm = world:first_entity "shadow"
	local dl = world:first_entity "directional_light"
	local camera = sm.camera
	local scenebounding = calc_scene_bounding()
	
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
				ref_path = fs.path "/pkg/ant.resources/depiction/shadow/mesh_cast_shadow.material"
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
				n = -100, f = 100,
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

ecs.tag "mesh_bounding_debug"
ecs.tag "frustum_debug"
local debug_sm = ecs.system "debug_shadow_maker"
debug_sm.depend "shadow_maker11"
debug_sm.dependby "frustum_bounding_update"

function debug_sm:init()
	local qw, qh = 128,128
	local eidshadow = computil.create_shadow_quad_entity(world, {x=0, y=0, w=qw, h=qh})
	local shadow_entity = world[eidshadow]

	local _, _, vp = ms:view_proj(shadow_entity.camera, shadow_entity.camera.frustum)
	local frustum = mathbaselib.new_frustum(ms, vp)
	computil.create_frustum_entity(world, frustum, "shadow frustum")
end

local function update_bounding_mesh()
	local boundingdebug = world:first_entity "mesh_bounding_debug"
	local desc = {
		vb = {"fffd"}, ib = {},
		primitives = {},
	}
	
	for _, eid in world:each "can_render" do
		local e = world[eid]
		if e.can_render and e.can_cast then
			local meshhandle = assetmgr.get_mesh(e.rendermesh.reskey).handle

			local startvb = #desc.vb - 1
			local startib = #desc.ib
			geodrawer.draw_aabb_box(meshhandle.bounding.aabb, 0xff8f0000, ms:srtmat(e.transform), desc)

			local endvb = #desc.vb - 1
			local endib = #desc.ib
			desc.primitives[#desc.primitives+1] = {
				start_vertex=startvb, num_vertices=(endvb-startvb) / 4,
				start_index=startib, num_indices=endib-startib,
			}
		end
	end
	
	local meshhandle = assetmgr.get_mesh(boundingdebug.rendermesh.reskey).handle
	local group = meshhandle.groups[1]
	group.primitives = desc.primitives
	bgfx.update(group.vb.handles[1], 0, desc.vb)
	bgfx.update(group.ib.handle, 0, desc.ib)

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

local frustum_bounding_update = ecs.system "frustum_bounding_update"
function frustum_bounding_update:update()
	local frsutum_bounding = world:first_entity "frustum_debug"
	local shadow = world:first_entity "shadow"
	local shadowcamera = shadow.camera
	frsutum_bounding.transform.watcher.t = shadowcamera.eyepos
	frsutum_bounding.transform.watcher.r = ms(shadowcamera.viewdir, "DT")
end