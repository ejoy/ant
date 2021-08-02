--luacheck: ignore self
local ecs = ...
local world = ecs.world
local w = world.w

local mu 		= import_package "ant.math".util
local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"

local renderpkg = import_package "ant.render"
local fbmgr 	= renderpkg.fbmgr
local samplerutil= renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local bgfx 		= require "bgfx"

local icamera	= world:interface "ant.camera|camera"

--update pickup view
local function enable_pickup(enable)
	local e = world:singleton_entity "pickup"
	e.visible = enable
	e.pickup.nextstep = enable and "blit" or nil

	for v in w:select "pickup_filter visible?out" do
		v.visible = enable
	end
end

local function update_camera(pu_cameraeid, clickpt)
	for mq in w:select "main_queue camera_eid:in render_target:in" do	--main queue must visible
		local ndc2D = mu.pt2D_to_NDC(clickpt, mq.render_target.view_rect)
		local eye, at = mu.NDC_near_far_pt(ndc2D)
	
		local maincamera = icamera.find_camera(mq.camera_eid)
		local vp = maincamera.viewprojmat
		local ivp = math3d.inverse(vp)
		eye = math3d.transformH(ivp, eye, 1)
		at = math3d.transformH(ivp, at, 1)
	
		local camera = icamera.find_camera(pu_cameraeid)
		local viewdir = math3d.normalize(math3d.sub(at, eye))
		camera.viewmat = math3d.lookto(eye, viewdir, camera.updir)
		camera.projmat = math3d.projmat(camera.frustum)
		camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
		break
	end
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

local function blit_buffer_init(self)
	self.handle = bgfx.memory_texture(self.w*self.h * self.elemsize)
	self.rb_idx = fbmgr.create_rb {
		w = self.w,
		h = self.h,
		layers = 1,
		format = "RGBA8",
		flags = samplerutil.sampler_flag {
			BLIT="BLIT_READWRITE",
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
	self.blit_buffer = blit_buffer_init(self.blit_buffer)
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

local icamera = world:interface "ant.camera|camera"

local function create_pick_entity()
	local cameraeid = icamera.create({
		viewdir = mc.ZAXIS,
		updir = mc.YAXIS,
		eyepos = mc.ZERO_PT,
		frustum = {
			type="mat", n=0.1, f=100, fov=0.5, aspect=pickup_buffer_w / pickup_buffer_h
		},
		name = "camera.pickup",
	}, true)

	local fbidx = fbmgr.create {
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

	world:luaecs_create_entity{
		policy = {
			"ant.scene|primitive_filter",
		},
		data = {
			primitive_filter = {
				filter_type = "selectable",
			},
			pickup_queue_opacity = true,
		}
	}

	world:luaecs_create_entity{
		policy = {
			"ant.scene|primitive_filter",
		},
		data = {
			primitive_filter = {
				filter_type = "selectable",
			},
			pickup_queue_translucent = true,
		}
	}

	world:luaecs_create_entity {
		policy = {
			"ant.general|name",
			"ant.render|render_queue",
			"ant.render|cull",
			"ant.objcontroller|pickup",
		},
		data = {
			pickup = {
				blit_buffer = {
					w = pickup_buffer_w,
					h = pickup_buffer_h,
					elemsize = 4,
				},
			},
			camera_eid = cameraeid,
			render_target = {
				viewid = pickupviewid,
				view_mode = "s",
				view_rect = {
					x = 0, y = 0, w = pickup_buffer_w, h = pickup_buffer_h,
				},
				clear_state = {
					color = 0,
					depth = 1,
					stencil = 0,
					clear = "CDS"
				},
				fb_idx = fbidx,
			},
			filter_names = {
				"pickup_queue_opacity",
				"pickup_queue_translucent",
			},
			cull_tag = {
				"pickup_queue_opacity_cull",
				"pickup_queue_translucent_cull",
			},
			name 		= "pickup_queue",
			queue_name 	= "pickup_queue",
			pickup_queue= true,
			INIT		= true,
			visible = false,
		}

	}
end

function pickup_sys:init()
	create_pick_entity()
end

local leftmousepress_mb = world:sub {"mouse", "LEFT"}
local clickpt = {}
function pickup_sys:data_changed()
	for _,_,state,x,y in leftmousepress_mb:unpack() do
		if state == "DOWN" then
			enable_pickup(true)
			clickpt[1], clickpt[2] = x, y
		end
	end
end

function pickup_sys:update_camera()
    for v in w:select "pickup_queue visible camera_eid:in" do
		update_camera(v.camear_eid, clickpt)
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
		world:pub {"pickup",selecteid,pickup_com.pickup_cache.pick_ids}
	else
		pickup_com.pickup_cache.last_pick = nil
		pickup_com.pickup_cache.pick_ids = {}
		world:pub {"pickup",nil,{}}
		print("not found any eid")
	end
end

local state_list = {
	blit = "wait",
	wait = "select_obj",
}

local function check_next_step(pc)
	pc.nextstep = state_list[pc.nextstep]
end

function pickup_sys:pickup()
	for v in w:select "pickup_queue visible pickup:in render_target:in" do
		local pc = v.pickup
		local nextstep = pc.nextstep
		if nextstep == "blit" then
			local fb = fbmgr.get(v.render_target.fb_idx)
			local rb = fbmgr.get_rb(fb[1])
			blit(pc.blit_buffer, rb)
		elseif nextstep	== "select_obj" then
			select_obj(pc, pc.blit_buffer, v.render_target.view_rect)
			enable_pickup(false)
		end

		check_next_step(pc)
	end
end
