--luacheck: ignore self
local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math = import_package "ant.math"
local point2d = math.point2d
local bgfx = require "bgfx"
local mu = math.util
local ms = math.stack
local fs = require "filesystem"

local computil = import_package "ant.render".components

local math_baselib = require "math3d.baselib"

local pickup_fb_viewid = 101
local pickup_blit_viewid = pickup_fb_viewid + 1

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

local function init_pickup_buffer(pickup_entity)
    local comp = pickup_entity.pickup
    --[@ init hardware resource
    local vr = pickup_entity.view_rect
	local w, h = vr.w, vr.h
	comp.blitdata = bgfx.memory_texture(w*h * 4)
    comp.pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    comp.pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({comp.pick_buffer, comp.pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")
	--@]
end

local function readback_render_data(pickup_entity)
    local comp = pickup_entity.pickup    
    bgfx.blit(pickup_blit_viewid, assert(comp.rb_buffer), 0, 0, assert(comp.pick_buffer))    
    return bgfx.read_texture(comp.rb_buffer, comp.blitdata)
end

local function which_entity_hitted(pickup_entity)
    local comp = pickup_entity.pickup
    local vr = pickup_entity.view_rect
	local w, h = vr.w, vr.h
	
	local cw, ch = 2, 2	
	local startidx = ((h - ch) * w + (w - cw)) * 0.5


	local found_eid = nil
	for ix = 1, cw do		
		for iy = 1, ch do 
			local cidx = startidx + (ix - 1) + (iy - 1) * w
			local rgba = comp.blitdata[cidx]
			if rgba ~= 0 then
				found_eid = unpackrgba_to_eid(rgba)
				break
			end
		end
	end

    return found_eid
end

local function update_viewinfo(e, clickpt) 
	local maincamera = world:first_entity("main_camera")  
	local cameracomp = maincamera.camera
	local mc_vr = maincamera.view_rect
	local w, h = mc_vr.w, mc_vr.h

	local result = math_baselib.screenpt_to_3d(
		{
			clickpt.x, clickpt.y, 0,
			clickpt.x, clickpt.y, 1
		}, cameracomp.frustum, ~cameracomp.eyepos, ~cameracomp.viewdir, {w=w, h=h})

	local pickupcamera = e.camera
	local eye, at = ms:vector(result[1]), ms:vector(result[2])

	pickupcamera.eyepos(eye)
	pickupcamera.viewdir(ms(at, eye, "-nP"))
end

-- update material system
local pickup_material_sys = ecs.system "pickup_material_system"

pickup_material_sys.depend "final_filter_system"
pickup_material_sys.dependby "entity_rendering"

function pickup_material_sys:update()
	for _, eid in world:each("pickup") do
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

			replace_material(filter.result, materials.opaticy)
			replace_material(filter.transparent_result, materials.transparent)
		end
	end
end

-- pickup_system
ecs.component "pickup_material"
	.opacity "material_content"
	.transparent "material_content"

ecs.component_alias("pickup_viewtag", "boolean")

local pickupcomp = ecs.component "pickup"
	.materials "pickup_material"

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

pickup_sys.depend "entity_rendering"

pickup_sys.dependby "end_frame"

local vr_w, vr_h = 8, 8
local default_frustum = {type="mat"}
mu.frustum_from_fov(default_frustum, 0.1, 100, 1, vr_w / vr_h)

local default_camera = {
	viewid = pickup_fb_viewid,
	eyepos = {0, 0, 0, 1},
	viewdir = {0, 0, 0, 0},
	frustum = default_frustum,
}

local default_primitive_filter = {
	view_tag  = "pickup_viewtag",
	filter_tag = "can_select",
	no_lighting = true,
}

local function enable_pickup(eid, enable)
	if enable then
		world:add_component(eid, "camera", default_camera)
		world:add_component(eid, "primitive_filter", default_primitive_filter)
		local e = world[eid]
		local camera = e.camera
		local comp = e.pickup
		bgfx.set_view_frame_buffer(camera.viewid, assert(comp.pick_fb))
	else
		world:remove_component(eid, "camera")
		world:remove_component(eid, "primitive_filter")
	end
end

local function add_pick_entity()
	local eid = world:create_entity {
		pickup = {
			materials = {
				opacity = {
					ref_path = {package = "ant.resources", filename = fs.path "pickup_opacity.material"}
				},
				transparent = {
					ref_path = {package = "ant.resources", filename = fs.path "pickup_transparent.material"}
				}
			},
		},		
		clear_component = {
			color = 0,
			depth = 1,
			stencil = 0,
		},		
		view_rect = {
			x = 0, y = 0,
			w = vr_w, h = vr_h,
		},
		name = "pickup",
		pickup_viewtag = true,		
	}

	init_pickup_buffer(world[eid])	
	return eid
end

function pickup_sys:init()	
	local pickup_eid = add_pick_entity()

	self.message.observers:add({
		mouse_click = function (_, b, p, x, y)
			if b == "LEFT" and p then
				local entity = world[pickup_eid]
				if entity then
					enable_pickup(pickup_eid, true)
					update_viewinfo(entity, point2d(x, y))					
					entity.pickup.ispicking = true
				end
			end
		end
	})
end

function pickup_sys:update()
	local stat = self.frame_stat
	for _, pickupeid in world:each("pickup") do
		local e = world[pickupeid]
		local pu_comp = e.pickup
		if pu_comp.ispicking then
			local reading_frame = pu_comp.reading_frame
			if reading_frame == nil then
				pu_comp.reading_frame = readback_render_data(e)
			else
				if stat.frame_num == reading_frame then
					local eid = which_entity_hitted(e)
					if eid then
						local name = assert(world[eid]).name
						print("pick entity id : ", eid, ", name : ", name)
					else
						print("not found any eid")
					end
		
					pu_comp.last_eid_hit = eid

					world:update_func("pickup")()
		
					enable_pickup(pickupeid, false)
					pu_comp.ispicking = nil
					pu_comp.reading_frame = nil					
				end	
			end
		end
	end
end
