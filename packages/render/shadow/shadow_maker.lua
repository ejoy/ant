local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local computil 	= require "components.util"

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local fs 		= require "filesystem"
local mathbaselib = require "math3d.baselib"

ecs.component "shadow"
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
	for i=1, transformed_boundings do
		local tb = transformed_boundings[i]
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
	scenebounding:transform(viewmat)

	local aabb = scenebounding:get "aabb"

	local lengthaxis = ms({0.5}, aabb.max, aabb.min, "-*T")
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
		material = {
			ref_path = fs.path "/pkg/ant.resources/depiction/shadow/mesh_cast_shadow.material"
		},
		shadow = {
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
		local mi = assetmgr.get_resource(material.ref_path)	-- must only one material content
		for _, p in ipairs(result) do
			p.material = mi
		end
	end

	local shadowmat = sm.shadow.material
	replace_material(results.opaque, 		shadowmat)
	replace_material(results.translucent, 	shadowmat)

	update_shadow_camera(sm.camera, world:first_entity "directional_light", sm.shadow.distance)
end

local debug_sm = ecs.system "debug_shadow_maker"
debug_sm.depend "shadow_maker11"
debug_sm.dependby "frustum_bounding_update"

function debug_sm:init()
	local qw, qh = 128,128
	computil.create_shadow_quad_entity(world, {x=0, y=0, w=qw, h=qh})
	
	local shadow_entity = world:first_entity "shadow"
	local _, _, vp = ms:view_proj(shadow_entity.camera, shadow_entity.camera.frustum)
	local frustum = mathbaselib.new_frustum(ms, vp)
	computil.create_frustum_entity(world, frustum, "shadow frustum")
end