local ecs = ...
local world = ecs.world

local ms = import_package "ant.math".stack
local mathbaselib = require "math3d.baselib"

local viewidmgr = require "viewid_mgr"
local renderutil = require "util"
local fs = require "filesystem"

ecs.component "shadow"
	.material "material_content"
	.shadowmap_with "int" (1024)
	.shadowmap_height "int" (1024)

local sm = ecs.system "shadow_maker11"
sm.depend "primitive_filter_system"
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
				n = -10000, f = 10000,
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
	local qw, qh = 256,256
	renderutil.create_shadow_quad_entity(world, {x=0, y=0, w=qw, h=qh})
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


local maker_camera = ecs.system "shadowmaker_camera"
maker_camera.dependby "shadow_maker11"
maker_camera.depend "primitive_fiter_system"

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
	
	local viewmat = ms:lookfrom3(camera.eyepos, camera.viewdir, camera.updir)
	local aabb_vs = mathbaselib.transform_aabb(ms, viewmat, scenebounding.aabb)
	local lengthaxis = ms({0.5}, aabb_vs.max, aabb_vs.min, "-*T")
	local frustum = camera.frustum
	assert(frustum.ortho)

	local half_w, half_h = lengthaxis[1], lengthaxis[2]
	frustum.l, frustum.r = -half_w, half_w
	frustum.t, frustum.b = half_h, -half_h
end