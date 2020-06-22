--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathpkg 	= import_package "ant.math"
local mu, mc 	= mathpkg.util, mathpkg.constant
local math3d	= require "math3d"

local renderpkg = import_package "ant.render"
local fbmgr 	= renderpkg.fbmgr
local samplerutil= renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local assetmgr = import_package "ant.asset"

local bgfx 		= require "bgfx"

--update pickup view
local function enable_pickup(enable)
	local e = world:singleton_entity "pickup"
	e.visible = enable

	if not enable then
		e.pickup.nextstep = nil
	end
end

local function update_viewinfo(e, clickx, clicky) 
	local mq = world:singleton_entity "main_queue"
	local camera = world[mq.camera_eid].camera

	local pickupcamera = world[e.camera_eid].camera

	local rt = mq.render_target.viewport.rect

	local ndc2D = mu.pt2D_to_NDC({clickx, clicky}, rt)
	local eye, at = mu.NDC_near_far_pt(ndc2D)

	local vp = mu.view_proj(camera)
	local ivp = math3d.inverse(vp)
	eye = math3d.transformH(ivp, eye, 1)
	at = math3d.transformH(ivp, at, 1)
	pickupcamera.eyepos.v = eye
	pickupcamera.viewdir.v= math3d.normalize(math3d.sub(at, eye))
end


local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local function which_entity_hitted(blitdata, viewrect, elemsize)
	local ceil = math.ceil
	local x, y = viewrect.x or 0, viewrect.y or 0
	assert(x == 0 and y == 0)
	local w, h = viewrect.w, viewrect.h
	local hw, hh = w * 0.5, h * 0.5
	local center = {ceil(hw), ceil(hh)}

	assert(elemsize == 4)
	local step = w * 4

	local function found_eid(pt)
		local x, y = pt[1], pt[2]
		if  0 < x and x <= w and
			0 < y and y <= h then

			local offset = (pt[1]-1)*step+(pt[2]-1)*elemsize
			local feid = blitdata[offset+1]|
						blitdata[offset+2] << 8|
						blitdata[offset+3] << 16|
						blitdata[offset+4] << 24
			if feid ~= 0 and world[feid] then
				return feid
			end
		end
	end

	local feid = found_eid(center)
	if feid then
		return feid
	end

	local radius = 1
	local directions<const> = {
		{1, 0}, {0, 1}, {-1, 0}, {0, -1}
	}
	while radius <= hw and radius <= hh do
		local pt = {center[1] - radius, center[2] - radius}
		for i=1, 4 do
			local dir = directions[i]

			local range = radius * 2 + 1
			for j=1, range-1 do	
				feid = found_eid(pt)
				if feid then
					return feid
				end

				pt[1] = pt[1] + dir[1]
				pt[2] = pt[2] + dir[2]
			end
		end
		radius = radius + 1
	end
end

local pickup_sys = ecs.system "pickup_system"

local uid_cache = {}
local function get_properties(eid, fx)
	local p = uid_cache[eid]
	if p then
		return p
	end
	local imaterial = world:interface "ant.asset|imaterial"
	local v = world.component "vector" (packeid_as_rgba(eid))
	local u = fx.uniforms[1]
	assert(u.name == "u_id")
	p = {
		u_id = {
			value = v,
			handle = u.handle,
			type = u.type,
			set = imaterial.which_set_func(v)
		},
	}
	uid_cache[eid] = p
	return p
end

local function replace_material(result, material)
	local items = result.items
	for eid, item in pairs(items) do
		local ni = {}; for k, v in pairs(item) do ni[k] = v end
		ni.fx = material.fx
		ni.properties = get_properties(eid, material.fx)
		ni.state = material._state
		items[eid] = ni
	end
end


-- pickup_system
local bb = ecs.component "blit_buffer"

function bb:init()
	self.handle = bgfx.memory_texture(self.w*self.h * self.elemsize)
	self.rb_idx = fbmgr.create_rb {
		w = self.w,
		h = self.h,
		layers = 1,
		format = "RGBA8",
		flags = samplerutil.sampler_flag {
			BLIT="BLIT_AS_DST",
			BLIT_READBACK="BLIT_READBACK_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		}
	}
	self.blit_viewid = viewidmgr.get "pickup_blit"
	return self
end

local pu = ecs.component "pickup"

function pu:init()
	self.pickup_cache = {
		last_pick = -1,
		pick_ids = {},
	}
	return self
end


local pickup_buffer_w, pickup_buffer_h = 8, 8
local pickupviewid = viewidmgr.get "pickup"

local fb_renderbuffer_flag = samplerutil.sampler_flag {
	RT="RT_ON",
	MIN="POINT",
	MAG="POINT",
	U="CLAMP",
	V="CLAMP"
}

local function add_pick_entity()
	local cameraeid = world:create_entity {
		policy = {
			"ant.render|camera",
			"ant.general|name",
		},
		data = {
			camera = {
				viewdir = world.component "vector"(mc.T_ZAXIS),
				updir = world.component "vector"(mc.T_YAXIS),
				eyepos = world.component "vector"(mc.T_ZERO_PT),
				frustum = {
					type="mat", n=0.1, f=100, fov=0.5, aspect=pickup_buffer_w / pickup_buffer_h
				},
			},
			name = "camera.pickup"
		}
	}

	local fbidx = fbmgr.create {
		render_buffers = {
			fbmgr.create_rb {
				w = pickup_buffer_w,
				h = pickup_buffer_h,
				layers = 1,
				format = "RGBA8",
				flags = fb_renderbuffer_flag,
			},
			fbmgr.create_rb {
				w = pickup_buffer_w,
				h = pickup_buffer_h,
				layers = 1,
				format = "D24S8",
				flags = fb_renderbuffer_flag,
			}
		}
	}

	return world:create_entity {
		policy = {
			"ant.general|name",
			"ant.render|render_queue",
			"ant.objcontroller|pickup",
		},
		data = {
			pickup = world.component "pickup" {
				blit_buffer = world.component "blit_buffer" {
					w = pickup_buffer_w,
					h = pickup_buffer_h,
					elemsize = 4,
				},
			},
			camera_eid = cameraeid,
			render_target = world.component "render_target" {
				viewid = pickupviewid,
				view_mode = "s",
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
				fb_idx = fbidx,
			},
			primitive_filter = world.component "primitive_filter" {
				filter_type = "selectable"
			},
			name = "pickup_renderqueue",
			visible = false,
		}

	}
end

local opacity_material, translucent_material
local imaterial = world:interface "ant.asset|imaterial"

function pickup_sys:init()
	add_pick_entity()
	opacity_material = imaterial.load '/pkg/ant.resources/materials/pickup_opacity.material'
	translucent_material = imaterial.load '/pkg/ant.resources/materials/pickup_transparent.material'
end

function pickup_sys:refine_filter()
	local e = world:singleton_entity "pickup"
	if e.visible then
		local filter = e.primitive_filter

		local result = filter.result
		replace_material(result.opaticy, opacity_material)
		replace_material(result.translucent, translucent_material)
	end
end

local leftmousepress_mb = world:sub {"mouse", "LEFT"}
function pickup_sys:data_changed()
	for _,_,state,x,y in leftmousepress_mb:unpack() do
		if state == "DOWN" then
			enable_pickup(true)
			local pickupentity = world:singleton_entity "pickup"
			update_viewinfo(pickupentity, x, y)
			local pickupcomp = pickupentity.pickup
			pickupcomp.nextstep = "blit"
		end
	end
end

local function blit(blit_buffer, colorbuffer)
	local rb = fbmgr.get_rb(blit_buffer.rb_idx)
	local rbhandle = rb.handle
	
	bgfx.blit(blit_buffer.blit_viewid, rbhandle, 0, 0, assert(colorbuffer.handle))
	return bgfx.read_texture(rbhandle, blit_buffer.handle)
end

local function print_raw_buffer(rawbuffer)
	local data = rawbuffer.handle
	local elemsize = rawbuffer.elemsize
	local step = pickup_buffer_w * elemsize
	for i=1, pickup_buffer_w do
		local t = {tostring(i) .. ":"}
		for j=1, pickup_buffer_h do
			local idx = (i-1)*step+(j-1)*elemsize
			for ii=1, elemsize do
				t[#t+1] = data[idx+ii]
			end
		end

		print(table.concat(t, ' '))
	end
end

local function select_obj(pickup_com, blit_buffer, viewrect)
	--print_raw_buffer(blit_buffer)
	local selecteid = which_entity_hitted(blit_buffer.handle, viewrect, blit_buffer.elemsize)
	if selecteid and selecteid<100 then
		log.info("selecteid",selecteid)
		pickup_com.pickup_cache.last_pick = selecteid
		pickup_com.pickup_cache.pick_ids = {selecteid}
		local name = assert(world[selecteid]).name
		print("pick entity id : ", selecteid, ", name : ", name)
		-- world:update_func("after_pickup")()
		world:pub {"pickup",selecteid,pickup_com.pickup_cache.pick_ids}
	else
		pickup_com.pickup_cache.last_pick = nil
		pickup_com.pickup_cache.pick_ids = {}
		-- world:update_func("after_pickup")()
		world:pub {"pickup",nil,{}}
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

local function has_any_visible_set(results)
	for _, f in pairs(results) do
		if f.visible_set then
			return true
		end
	end
end

function pickup_sys:pickup()
	local pickupentity = world:singleton_entity "pickup"

	if pickupentity.visible then 
		local needcheck = has_any_visible_set(pickupentity.primitive_filter.result)
		local pickupcomp = pickupentity.pickup
		local nextstep = pickupcomp.nextstep
		if nextstep == "blit" and needcheck then
			local fb = fbmgr.get(pickupentity.render_target.fb_idx)
			local rb = fbmgr.get_rb(fb[1])
			blit(pickupcomp.blit_buffer, rb)
		elseif nextstep	== "select_obj" then
			if needcheck then
				select_obj(pickupcomp,pickupcomp.blit_buffer, pickupentity.render_target.viewport.rect)
			else
				world:pub {"pickup",nil,{}}
				print("not found any eid")
			end
			enable_pickup(false)
		end

		check_next_step(pickupcomp)
	end
end