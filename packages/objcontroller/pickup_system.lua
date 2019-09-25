--luacheck: ignore self
local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"
ecs.import "ant.scene"
local lua_math = math
local mathpkg 	= import_package "ant.math"
local point2d 	= mathpkg.point2d
local ms 		= mathpkg.stack

local filterutil = import_package "ant.scene".filterutil

local renderpkg = import_package "ant.render"
local computil 	= renderpkg.components
local renderutil= renderpkg.util
local viewidmgr = renderpkg.viewidmgr
local camerautil= renderpkg.camera
local compdefault=renderpkg.default
local assetmgr = import_package "ant.asset".mgr

local bgfx 		= require "bgfx"
local fs 		= require "filesystem"
local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

function traverse_from_center( blitdata,w,h )
	assert(w==h)
    local function incr(v2a,v2b)
        for i = 1,#v2a do
            v2a[i] =  v2a[i] +   v2b[i]
        end
    end
    -- local function dosth(v2)
    --     log.info_a("trav:",v2)
    -- end
    local start_move = {1,-1}
    local move_count=nil
    local step_incr = 2
    local step = {
        {-1,0},
        {0,1},
        {1,0},
        {0,-1}
    }
    if w%2==0 then
        move_count = 1
    else
        move_count = 0
    end
    local  cur_pos = {lua_math.floor(w/2)-1,lua_math.floor(w/2)}
    log.trace_a(cur_pos)
    local found_eid = nil
    while true do
        incr(cur_pos,start_move)
        if cur_pos[2]<0 then
            break
        end
        if move_count >0 then
            for i = 1,4 do
                for j = 1,move_count do
                    incr(cur_pos,step[i])
                    found_eid = blitdata[cur_pos[1]*w+cur_pos[2]]
                    if found_eid ~= 0 then
                        return found_eid
                    end
                end
            end
        end
        move_count = move_count + step_incr
    end
end

local function which_entity_hitted(blitdata, viewrect)
	return traverse_from_center(blitdata,viewrect.w,viewrect.h)
end

local function update_viewinfo(e, clickpt) 
	local mq = world:first_entity "main_queue"
	local cameracomp = camerautil.get_camera(world, mq.camera_tag)
	local eye, at = ms:screenpt_to_3d(
		cameracomp, mq.render_target.viewport.rect,
		{clickpt.x, clickpt.y, 0,},
		{clickpt.x, clickpt.y, 1,})

	local pickupcamera = camerautil.get_camera(world, e.camera_tag)
	pickupcamera.eyepos(eye)
	pickupcamera.viewdir(ms(at, eye, "-nP"))
end

-- update material system
local pickup_material_sys = ecs.system "pickup_material_system"
pickup_material_sys.depend "primitive_filter_system"
pickup_material_sys.dependby "render_system"

local function replace_material(result, material)
	if result then
		for _, item in ipairs(result) do
			local mi = assetmgr.get_resource(material.ref_path)
			item.material = mi
			if item.properties == nil then
				item.properties = {}
			end
			if item.properties.uniforms == nil then
				item.properties.uniforms = {}
			end
			item.properties.uniforms.u_id = {type="color", name = "select eid", value=packeid_as_rgba(assert(item.eid))}
		end
	end
end

local function recover_material(result)
	if result then
		for i=1, result.cacheidx-1 do
			local item = result[i]
			local uniforms = assert(item.properties.uniforms)
			uniforms.u_id = nil
		end
	end
end

local function recover_filter(filter)
	local result = filter.result
	recover_material(result.opaticy)
	recover_material(result.translucent)
end

function pickup_material_sys:update()
	local e = world:first_entity "pickup"
	if e then
		local filter = e.primitive_filter

		local material = e.material
		local result = filter.result
		replace_material(result.opaticy, material[0])
		replace_material(result.translucent, material[1])
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

ecs.component_alias("blit_viewid", "viewid") 
ecs.component "blit_buffer" {depend = "blit_viewid"}
	.raw_buffer "raw_buffer"
	.render_buffer "render_buffer"

ecs.component_alias("pickup_viewtag", "boolean")

--pick_ids:array of pick_eid
--last_pick:last pick id when mult pick supported
ecs.component "pickup_cache"
	.last_pick "int" (-1)
	.pick_ids "int[]"

ecs.component "pickup"
	.blit_buffer "blit_buffer"
	.blit_viewid "blit_viewid"
	.pickup_cache "pickup_cache"

local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "frame_stat"
pickup_sys.singleton "message"

pickup_sys.depend "pickup_material_system"
pickup_sys.dependby "end_frame"

local pickup_buffer_w, pickup_buffer_h = 8, 8
local pickupviewid = viewidmgr.get "pickup"

local function add_pick_entity()
	local fb_renderbuffer_flag = renderutil.generate_sampler_flag {
		RT="RT_ON",
		MIN="POINT",
		MAG="POINT",
		U="CLAMP",
		V="CLAMP"
	}

	local pickupcamera = camerautil.get_camera(world, "pickup")
	if pickupcamera == nil then
		camerautil.bind_camera(world, "pickup", {
			type = "pickup",
			viewdir = {0, 0, 1, 0},
			updir = {0, 1, 0, 0},
			eyepos = {0, 0, 0, 1},
			frustum = {
				type="mat", n=0.1, f=1000, fov=1, aspect=pickup_buffer_w / pickup_buffer_h
			},
		})
	end

	return world:create_entity {
		material = {
			{ref_path = fs.path '/pkg/ant.resources/depiction/materials/pickup_opacity.material'},
			{ref_path = fs.path '/pkg/ant.resources/depiction/materials/pickup_transparent.material'},
		},
		view_mode = "s",
		pickup = {
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
			blit_viewid = viewidmgr.get("pickup_blit"),
			pickup_cache = {
				last_pick = -1,
				pick_ids = {},
			},
		},
		camera_tag = "pickup", 
		render_target = {
			viewport = {
				rect = {
					x = 0, y = 0, w = pickup_buffer_w, h = pickup_buffer_h,
				},
				clear_state = {
					color = 0,
					depth = 1,
					stencil = 0,
					clear = "all"
				},
			},
			frame_buffer = {
				render_buffers = {
					{
						w = pickup_buffer_w,
						h = pickup_buffer_h,
						layers = 1,
						format = "RGBA8",
						flags = fb_renderbuffer_flag,
					},
					{
						w = pickup_buffer_w,
						h = pickup_buffer_h,
						layers = 1,
						format = "D24S8",
						flags = fb_renderbuffer_flag,
					}
				}
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
		mouse = function (_, x, y, what, state)
			if what == "LEFT" and state == "DOWN" then
				local eid = enable_pickup(true)
				local entity = world[eid]
				update_viewinfo(entity, point2d(x, y))
				entity.pickup.nextstep = "blit"
			end
		end
	})
end

local function blit(blitviewid, blit_buffer, colorbuffer)		
	local rb = blit_buffer.render_buffer.handle
	
	bgfx.blit(blitviewid, rb, 0, 0, assert(colorbuffer.handle))
	return bgfx.read_texture(rb, blit_buffer.raw_buffer.handle)	
end

local function print_raw_buffer(rawbuffer)
	local data = rawbuffer.handle
	for i=1, pickup_buffer_w do
		print("line:", i)
		local t = {}
		for j=1, pickup_buffer_h do
			t[#t+1] = data[(i-1)*pickup_buffer_w + j-1]
		end

		print(table.concat(t, ' '))
	end
end

local function select_obj(pickup_com,blit_buffer, viewrect)
	local selecteid = which_entity_hitted(blit_buffer.raw_buffer.handle, viewrect)
	if selecteid then
		log.info("selecteid",selecteid)
		pickup_com.pickup_cache.last_pick = selecteid
		pickup_com.pickup_cache.pick_ids = {selecteid}
		local name = assert(world[selecteid]).name
		print("pick entity id : ", selecteid, ", name : ", name)
		world:update_func("pickup")()
	else
		pickup_com.pickup_cache.last_pick = nil
		pickup_com.pickup_cache.pick_ids = {}
		world:update_func("pickup")()
		print("not found any eid")
	end
end

local state_list = {
	blit = "wait",
	wait = "select_obj",	
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
			blit(pickupcomp.blit_viewid, pickupcomp.blit_buffer, pickupentity.render_target.frame_buffer.render_buffers[1])
		elseif nextstep	== "select_obj" then
			recover_filter(pickupentity.primitive_filter)
			select_obj(pickupcomp,pickupcomp.blit_buffer, pickupentity.render_target.viewport.rect)
			--print_raw_buffer(pickupcomp.blit_buffer.raw_buffer)
			enable_pickup(false)
		end

		check_next_step(pickupcomp)
	end
end