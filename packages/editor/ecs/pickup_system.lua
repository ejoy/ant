--luacheck: ignore self
local ecs = ...
local world = ecs.world




ecs.import "inputmgr"

local math = import_package "math"
local point2d = math.point2d
local bgfx = require "bgfx"
local mu = math.util
local ms = math.stack
local fs = require "filesystem"

local asset = require "asset"

local math_baselib = require "math3d.baselib"

local pickup_fb_viewid = 101
local pickup_blit_viewid = pickup_fb_viewid + 1

local function deep_copy(t)
	if type(t) == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

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

local function init_pickup_materials()
	local mname = "pickup.material"
	local normal_material = asset.load(fs.path(mname))
	normal_material.name = mname

	local transparent_material = deep_copy(normal_material)
	transparent_material.surface_type.transparency = "transparent"
	transparent_material.name = ""

	local state = transparent_material.state
	state.WRITE_MASK = "RGBA"
	state.DEPTH_TEST = "ALWAYS"

	return {
		opaticy = normal_material,
		transparent = transparent_material,
	}
end

local function init_pickup_buffer(pickup_entity)
    local comp = pickup_entity.pickup
    --[@ init hardware resource
    local vr = pickup_entity.view_rect
    local w, h = vr.w, vr.h
    comp.pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    comp.pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({comp.pick_buffer, comp.pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")
    --@]

	bgfx.set_view_frame_buffer(pickup_entity.viewid, assert(comp.pick_fb))
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
	local mc_vr = maincamera.view_rect
	local w, h = mc_vr.w, mc_vr.h
	
	local pos = ms(maincamera.position, "T")
	local rot = ms(maincamera.rotation, "T")
	local pt3d = math_baselib.screenpt_to_3d(
		{
			clickpt.x, clickpt.y, 0,
			clickpt.x, clickpt.y, 1
		}, maincamera.frustum, pos, rot, {w=w, h=h})

	local eye, at = {pt3d[1], pt3d[2], pt3d[3]}, {pt3d[4], pt3d[5], pt3d[6]}
	local dir = ms(at, eye, "-nT")

	ms(assert(e.position), eye, "=")
	ms(assert(e.rotation), dir, "D=")

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

			for _, elem in ipairs{
					{result=filter.result, material=materials.opaticy},
					{result=filter.transparent_result, material=materials.transparent},
				} do
				local result = elem.result 
				local material = elem.material
				if result then
					for _, item in ipairs(result) do
						item.material = material
						item.properties = {
							u_id = {type="color", value=packeid_as_rgba(assert(item.eid))}
						}
					end
				end
			end
		end
	end
end

-- pickup_system
ecs.component_struct "pickup"{}

local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "frame_stat"
pickup_sys.singleton "message"

pickup_sys.depend "entity_rendering"

pickup_sys.dependby "end_frame"

local function add_primitive_filter(eid)
	world:add_component(eid, "primitive_filter")
	local e = world[eid]
	local filter = e.primitive_filter	
	filter.no_lighting = true
	filter.filter_select = true
end

local function remove_primitive_filter(eid)
	world:remove_component(eid, "primitive_filter")
end

local function add_pick_entity()
	local eid = world:new_entity("pickup", 
	"clear_component", 
	"viewid",
	"view_rect", 
	"position", "rotation", 
	"frustum", 
	"name")        
	local entity = assert(world[eid])
	entity.viewid = pickup_fb_viewid
	entity.name = "pickup"

	local cc = entity.clear_component
	cc.color = 0

	local vr = entity.view_rect
	vr.w = 8
	vr.h = 8

	local comp = entity.pickup
	comp.blitdata = bgfx.memory_texture(vr.w*vr.h * 4)
	comp.materials = init_pickup_materials()

	init_pickup_buffer(entity)	

	local frustum = entity.frustum
	mu.frustum_from_fov(frustum, 0.1, 100, 1, vr.w / vr.h)

	local pos = entity.position
	local rot = entity.rotation
	ms(pos, {0, 0, 0, 1}, "=")
	ms(rot, {0, 0, 0, 0}, "=")
	
	return eid
end

function pickup_sys:init()	
	local pickup_eid = add_pick_entity()

	self.message.observers:add({
		mouse_click = function (_, b, p, x, y)
			if b == "LEFT" and p then
				local entity = world[pickup_eid]
				if entity then
					update_viewinfo(entity, point2d(x, y))
					add_primitive_filter(pickup_eid)
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
					world:change_component(pickupeid, "pickup")
					world.notify()
		
					remove_primitive_filter(pickupeid)
					pu_comp.ispicking = nil
					pu_comp.reading_frame = nil					
				end	
			end
		end
	end
end
