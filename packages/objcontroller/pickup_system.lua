local ecs = ...
local world = ecs.world
local w = world.w

local mu 		= import_package "ant.math".util
local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"
local bgfx 		= require "bgfx"

local renderpkg = import_package "ant.render"
local fbmgr 	= renderpkg.fbmgr
local samplerutil= renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local icamera	= ecs.import.interface "ant.camera|camera"
local irender   = ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local pickup_materials = {}

local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local pickup_refs = {}
local max_pickupid = 0
local function genid()
	max_pickupid = max_pickupid + 1
	return max_pickupid
end

local function get_properties(id, fx)
	local v = math3d.ref(math3d.vector(packeid_as_rgba(id)))
	local u = fx.uniforms[1]
	assert(u.name == "u_id")
	return {
		u_id = {
			value = v,
			handle = u.handle,
			type = u.type,
			set = imaterial.property_set_func "u"
		}
	}
end

local function update_camera(pu_camera_ref, clickpt)
	local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
	local ndc2D = mu.pt2D_to_NDC(clickpt, mq.render_target.view_rect)
	local eye, at = mu.NDC_near_far_pt(ndc2D)

	local maincamera = icamera.find_camera(mq.camera_ref)
	local vp = maincamera.viewprojmat
	local ivp = math3d.inverse(vp)
	eye = math3d.transformH(ivp, eye, 1)
	at = math3d.transformH(ivp, at, 1)

	local camera = icamera.find_camera(pu_camera_ref)
	local viewdir = math3d.normalize(math3d.sub(at, eye))
	camera.viewmat = math3d.lookto(eye, viewdir, camera.updir)
	camera.projmat = math3d.projmat(camera.frustum)
	camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
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

	local function found_id(pt)
		local x, y = pt[1], pt[2]
		if  0 < x and x <= w and
			0 < y and y <= h then

			local offset = (pt[1]-1)*step+(pt[2]-1)*elemsize
			local id = blitdata[offset+1]|
						blitdata[offset+2] << 8|
						blitdata[offset+3] << 16|
						blitdata[offset+4] << 24
			if id ~= 0 then
				return id
			end
		end
	end

	local id = found_id(center)
	if id then
		return id
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
				id = found_id(pt)
				if id then
					return id
				end

				pt[1] = pt[1] + dir[1]
				pt[2] = pt[2] + dir[2]
			end
		end
		radius = radius + 1
	end
end

local pickup_sys = ecs.system "pickup_system"

local function blit_buffer_init(blit_buffer)
	blit_buffer.handle = bgfx.memory_texture(blit_buffer.w*blit_buffer.h * blit_buffer.elemsize)
	blit_buffer.rb_idx = fbmgr.create_rb {
		w = blit_buffer.w,
		h = blit_buffer.h,
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
	blit_buffer.blit_viewid = viewidmgr.get "pickup_blit"
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

local function create_pick_entity()
	local camera_ref = icamera.create {
		viewdir = mc.ZAXIS,
		updir = mc.YAXIS,
		eyepos = mc.ZERO_PT,
		frustum = {
			type="mat", n=0.1, f=100, fov=0.5, aspect=pickup_buffer_w / pickup_buffer_h
		},
		name = "camera.pickup",
	}

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

	ecs.create_entity {
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
			camera_ref = camera_ref,
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
			primitive_filter = {
				filter_type = "selectable",
				"opacity",
				"translucent",
			},
			cull_tag	= {},
			name 		= "pickup_queue",
			queue_name 	= "pickup_queue",
			pickup_queue= true,
			visible		= false,
			shadow_render_queue = {},
		}
	}
end

function pickup_sys:init()
	create_pick_entity()
	pickup_materials.opacity	= imaterial.load '/pkg/ant.resources/materials/pickup_opacity.material'
	pickup_materials.translucent= imaterial.load '/pkg/ant.resources/materials/pickup_transparent.material'
end

function pickup_sys:entity_init()
	for e in w:select "INIT pickup_queue pickup:in" do
		local pickup = e.pickup
		pickup.clickpt = {}
		blit_buffer_init(pickup.blit_buffer)
	end
end

local function open_pickup(x, y)
	local e = w:singleton("pickup_queue", "pickup:in")
	e.pickup.nextstep = "blit"
	e.pickup.clickpt[1] = x
	e.pickup.clickpt[2] = y
	e.visible = true
	w:sync("visible?out", e)
end

local function close_pickup()
	local e = w:singleton("pickup_queue", "pickup:in")
	e.pickup.nextstep = nil
	e.visible = false
	w:sync("visible?out", e)
end

local leftmousepress_mb = world:sub {"mouse", "LEFT"}
function pickup_sys:data_changed()
	for _,_,state,x,y in leftmousepress_mb:unpack() do
		if state == "DOWN" then
			open_pickup(x, y)
		end
	end
end

function pickup_sys:update_camera()
	for e in w:select "pickup_queue visible pickup:in camera_ref:in" do
		update_camera(e.camera_ref, e.pickup.clickpt)
		break
	end
end

local function blit(blit_buffer, render_target)
	local fb = fbmgr.get(render_target.fb_idx)
	local colorbuffer = fbmgr.get_rb(fb[1])
	local rb = fbmgr.get_rb(blit_buffer.rb_idx)
	local rbhandle = rb.handle
	bgfx.blit(blit_buffer.blit_viewid, rbhandle, 0, 0, assert(colorbuffer.handle))
	return bgfx.read_texture(rbhandle, blit_buffer.handle)
end

local function select_obj(blit_buffer, render_target)
	local viewrect = render_target.view_rect
	local selecteid = which_entity_hitted(blit_buffer.handle, viewrect, blit_buffer.elemsize)
	if selecteid then
		local e = pickup_refs[selecteid]
		if e then
			log.info("pick entity id: ", selecteid)
			world:pub {"pickup", e}
			return
		end
	end
	log.info("not found any eid")
	world:pub {"pickup"}
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
			blit(pc.blit_buffer, v.render_target)
		elseif nextstep	== "select_obj" then
			select_obj(pc.blit_buffer, v.render_target)
			close_pickup()
		end
		check_next_step(pc)
	end
end

function pickup_sys:end_filter()
	for e in w:select "filter_result:in render_object:in filter_material:out reference:in" do
		local fr = e.filter_result
		local st = e.render_object.fx.setting.surfacetype
		local fm = e.filter_material
		local qe = w:singleton("pickup_queue", "primitive_filter:in")
		for _, fn in ipairs(qe.primitive_filter) do
			if fr[fn] == true then
				local m = assert(pickup_materials[st])
				local state = e.render_object.state
				local id = genid()
				pickup_refs[id] = e.reference
				pickup_refs[e.reference] = id
				fm[fn] = {
					fx			= m.fx,
					properties	= get_properties(id, m.fx),
					state		= irender.check_primitive_mode_state(state, m.state),
				}
			elseif fr[fn] == false then
				fm[fn] = nil
				local id = pickup_refs[e.reference]
				pickup_refs[e.reference] = nil
				pickup_refs[id] = nil
			end
		end
	end
end
