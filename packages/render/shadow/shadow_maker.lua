local ecs = ...
local world = ecs.world

local ms = import_package "ant.math".stack

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
	local sampleflags = renderutil.generate_sampler_flag{
		RT="RT_ON",
		MIN="LINEAR",
		MAG="LINEAR",
		U="CLAMP",
		V="CLAMP",
	}
	sampleflags = sampleflags .. "c0"	--border color=0
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
				}
			},
			frame_buffer = {
				render_buffers = {
					{
						format = "RGBA8",
						w=sm_width,
						h=sm_height,
						layers=1,
						flags=sampleflags,
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