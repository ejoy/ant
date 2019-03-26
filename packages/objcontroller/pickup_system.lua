--luacheck: ignore self
local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math = import_package "ant.math"
local point2d = math.point2d
local bgfx = require "bgfx"
local ms = math.stack
local fs = require "filesystem"

local filterutil = import_package "ant.scene".filterutil

local renderpkg = import_package "ant.render"
local computil = renderpkg.components
local renderutil = renderpkg.util
local viewidmgr = renderpkg.viewidmgr

local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local function unpackrgba_to_eid(rgba)
    local r =  rgba & 0x000000ff
    local g = (rgba & 0x0000ff00) >> 8
    local b = (rgba & 0x00ff0000) >> 16
    local a = (rgba & 0xff000000) >> 24
    
    return r + g + b + a
end

local function which_entity_hitted(blitdata, viewrect)    
	local w, h = viewrect.w, viewrect.h
	
	local cw, ch = 2, 2	
	local startidx = ((h - ch) * w + (w - cw)) * 0.5

	local found_eid = nil
	for ix = 1, cw do		
		for iy = 1, ch do 
			local cidx = startidx + (ix - 1) + (iy - 1) * w
			local rgba = blitdata[cidx]
			if rgba ~= 0 then
				found_eid = unpackrgba_to_eid(rgba)
				break
			end
		end
	end

    return found_eid
end

local function update_viewinfo(e, clickpt) 
	local maincamera = world:first_entity "main_camera"
	local cameracomp = maincamera.camera
	local eye, at = ms:screenpt_to_3d(
		cameracomp, maincamera.viewport.rect,
		{clickpt.x, clickpt.y, 0,},
		{clickpt.x, clickpt.y, 1,})

	local pickupcamera = e.camera
	pickupcamera.eyepos(eye)
	pickupcamera.viewdir(ms(at, eye, "-nP"))
end

-- update material system
local pickup_material_sys = ecs.system "pickup_material_system"
pickup_material_sys.depend "primitive_filter_system"
pickup_material_sys.dependby "render_system"

function pickup_material_sys:update()
	for _, eid in world:each "pickup" do
		local e = world[eid]
		local filter = e.primitive_filter
		if filter then
			local materials = e.pickup.materials

			local function replace_material(result, material)
				if result then
					for _, item in ipairs(result) do
						item.material = material
						item.properties = {
							u_id = {type="color", value=packeid_as_rgba(assert(item.eid))}
						}
					end
				end
			end

			local result = filter.result
			replace_material(result.opaque, materials.opaque)
			replace_material(filter.translucent, result.translucent)
		end
	end
end

-- pickup_system
local rb = ecs.component "raw_buffer"
	.w "real" (1)
	.h "real" (1)
	.elemsize "int" (4)
function rb:init()
	self.handle = bgfx.memory_texture(self.w*self.h * self.elemsize)
	return self
end

ecs.component "blit_buffer"
	.raw_buffer "raw_buffer"
	.render_buffer "render_buffer"

ecs.component_alias("blit_viewid", "viewid") {depend = "blit_buffer"}

ecs.component "pickup_material"
	.opaque 		"material_content"
	.translucent 	"material_content"

ecs.component_alias("pickup_viewtag", "boolean")

local pickupcomp = ecs.component "pickup"
	.materials "pickup_material"
	.blit_buffer "blit_buffer"
	.blit_viewid "blit_viewid"

function pickupcomp:init()
	local materials = self.materials
	local opacity = materials.opacity
	if opacity then
		computil.create_material(opacity)		
	end

	local transparent = materials.transparent
	if transparent then
		computil.create_material(transparent)
	end

	return self
end

local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "frame_stat"
pickup_sys.singleton "message"

pickup_sys.depend "pickup_material_system"
pickup_sys.dependby "end_frame"

local pickup_buffer_w, pickup_buffer_h = 8, 8
local pickupviewid = viewidmgr.get("pickup")

local function add_pick_entity()
	local fb_renderbuffer_flag = renderutil.generate_sampler_flag {
		RT="RT_ON",
		MIN="POINT",
		MAG="POINT",
		U="CLAMP",
		V="CLAMP"
	}

	return world:create_entity {
		pickup = {
			materials = {
				opaque = {
					ref_path = fs.path '//ant.resources/pickup_opacity.material'
				},
				translucent = {
					ref_path = fs.path '//ant.resources/pickup_transparent.material'
				}
			},
			blit_buffer = {
				raw_buffer = {
					w = pickup_buffer_w,
					h = pickup_buffer_h,
					elemsize = 4,
				},
				render_buffer = {
					w = pickup_buffer_w,
					h = pickup_buffer_h,
					layers = 1,
					format = "RGBA8",
					flags = renderutil.generate_sampler_flag {
						BLIT="BLIT_AS_DST",
						BLIT_READBACK="BLIT_READBACK_ON",
						MIN="POINT",
						MAG="POINT",
						U="CLAMP",
						V="CLAMP",
					}
				},
			},
			blit_viewid = viewidmgr.get("pickup_blit")
		},	
		viewport = {
			rect = {
				x = 0, y = 0, w = pickup_buffer_w, h = pickup_buffer_h,
			},
			clear_state = {
				color = 0,
				depth = 1,
				stencil = 0,
			},
		},
		camera = {
			type = "pickup",
			viewdir = {0, 0, 1, 0},
			updir = {0, 1, 0, 0},
			eyepos = {0, 0, 0, 1},
			frustum = {
				type="mat", n=0.1, f=100, fov=1, aspect=pickup_buffer_w / pickup_buffer_h
			},
		},
		render_target = {
			frame_buffers = {
				{
					color = {
						w = pickup_buffer_w,
						h = pickup_buffer_h,
						layers = 1,
						format = "RGBA8",
						flags = fb_renderbuffer_flag,
					},
					depth = {
						w = pickup_buffer_w,
						h = pickup_buffer_h,
						layers = 1,
						format = "D24S8",
						flags = fb_renderbuffer_flag,
					},
				},
			}
		},		
		viewid = pickupviewid,
		primitive_filter = filterutil.create_primitve_filter("main_view", "can_select"),
		name = "pickup_renderqueue",
		pickup_viewtag = true,
	}
end

local function enable_pickup(enable)
	world:enable_system("pickup_system", enable)
	if enable then
		return add_pick_entity()
	end

	local eid = world:first_entity_id "pickup"
	world:remove_entity(eid)
end

function pickup_sys:init()	
	--local pickup_eid = add_pick_entity()

	self.message.observers:add({
		mouse_click = function (_, b, p, x, y)
			if b == "LEFT" and p then
				local eid = enable_pickup(true)
				local entity = world[eid]
				update_viewinfo(entity, point2d(x, y))
				entity.pickup.nextstep = "blit"
			end
		end
	})
end

local function blit(blitviewid, blit_buffer, framebuffer)		
	local rb = blit_buffer.render_buffer.handle
	
	bgfx.blit(blitviewid, rb, 0, 0, assert(framebuffer.color.handle))
	return bgfx.read_texture(rb, blit_buffer.raw_buffer.handle)
end

local function select_obj(blit_buffer, viewrect)
	local selecteid = which_entity_hitted(blit_buffer.raw_buffer.handle, viewrect)
	if selecteid then
		local name = assert(world[selecteid]).name
		print("pick entity id : ", selecteid, ", name : ", name)
	else
		print("not found any eid")
	end

	world:update_func("pickup")(selecteid)
end

local state_list = {
	blit = "wait",
	wait = "select_obj"
}

local function check_next_step(pickupcomp)
	pickupcomp.nextstep = state_list[pickupcomp.nextstep]
end

function pickup_sys:update()
	local pickupentity = world:first_entity "pickup"
	if pickupentity then
		local pickupcomp = pickupentity.pickup
		local nextstep = pickupcomp.nextstep
		if nextstep == "blit" then
			blit(pickupcomp.blit_viewid, pickupcomp.blit_buffer, pickupentity.render_target.frame_buffers[1])
		elseif nextstep	== "select_obj" then
			select_obj(pickupcomp.blit_buffer, pickupentity.viewport.rect)
			enable_pickup(false)
		end

		check_next_step(pickupcomp)
	end
end