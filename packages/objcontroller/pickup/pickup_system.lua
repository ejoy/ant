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

local irender   = ecs.import.interface "ant.render|irender"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local setting 	= import_package "ant.settings".setting
local curve_world = setting:data().graphic.curve_world
local cw_enable = curve_world.enable

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

local function get_properties(id, properties)
	local p = {
		u_id = setmetatable({
			value = math3d.ref(math3d.vector(packeid_as_rgba(id)))
		},
		{__index=properties.u_id}),
	}

	if curve_world.enable then
		p.u_viewcamera_viewmat 		= properties.u_viewcamera_viewmat
		p.u_viewcamera_inv_viewmat 	= properties.u_viewcamera_inv_viewmat
		p.u_curveworld_param 		= properties.u_curveworld_param
	end
	return p
end

local function find_camera(id)
	local e = world:entity(id)
	return e.camera
end

local function update_camera(pu_camera_ref, clickpt)
	local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
	local ndc2D = mu.pt2D_to_NDC(clickpt, mq.render_target.view_rect)
	local eye, at = mu.NDC_near_far_pt(ndc2D)

	local maincamera = find_camera(mq.camera_ref)
	local vp = maincamera.viewprojmat
	local ivp = math3d.inverse(vp)
	eye = math3d.transformH(ivp, eye, 1)
	at = math3d.transformH(ivp, at, 1)

	local camera = find_camera(pu_camera_ref)
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

local pickup_buffer_w<const>, pickup_buffer_h<const> = 8, 8
local pickupviewid<const> = viewidmgr.get "pickup"

local fb_renderbuffer_flag<const> = samplerutil.sampler_flag {
	RT="RT_ON",
	MIN="POINT",
	MAG="POINT",
	U="CLAMP",
	V="CLAMP"
}

local function create_pick_entity()
	local camera_ref = ecs.create_entity{
		policy = {
			"ant.camera|camera",
			"ant.general|name"
		},
		data = {
			scene = {srt={}},
			camera = {
				frustum = {
					type="mat", n=1, f=1000, fov=0.5, aspect=pickup_buffer_w / pickup_buffer_h
				},
			},
			name = "camera.pickup",
		}
	}

	local fbidx = fbmgr.create(
		{rbidx=fbmgr.create_rb {
			w = pickup_buffer_w,
			h = pickup_buffer_h,
			layers = 1,
			format = "RGBA8",
			flags = fb_renderbuffer_flag,
		}},
		{rbidx=fbmgr.create_rb {
			w = pickup_buffer_w,
			h = pickup_buffer_h,
			layers = 1,
			format = "D24S8",
			flags = fb_renderbuffer_flag,
		}})

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
			visible		= true,
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
		pickup.clickpt = {-1, -1}
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

local leftmouse_mb = world:sub {"mouse", "LEFT"}
local function remap_xy(x, y)
	local tmq = w:singleton("tonemapping_queue", "render_target:in")
	local vr = tmq.render_target.view_rect
	return x-vr.x, y-vr.y
end
function pickup_sys:data_changed()
	for _,_,state,x,y in leftmouse_mb:unpack() do
		if state == "DOWN" then
			open_pickup(remap_xy(x, y))
		end
	end
end

function pickup_sys:update_camera()
	for e in w:select "pickup_queue visible pickup:in camera_ref:in" do
		update_camera(e.camera_ref, e.pickup.clickpt)
		if cw_enable then
			local main_camera = world:entity(irq.main_camera())
			local mc_viewmat = main_camera.camera.viewmat
			local mc_inv_viewmat = math3d.inverse(mc_viewmat)
			for _, pm in pairs(pickup_materials) do
				imaterial.set_property_directly(pm.properties, "u_viewcamera_viewmat", mc_viewmat)
				imaterial.set_property_directly(pm.properties, "u_viewcamera_inv_viewmat", mc_inv_viewmat)
			end
		end
	end
end

local function blit(blit_buffer, render_target)
	local rb = fbmgr.get_rb(blit_buffer.rb_idx)
	local rbhandle = rb.handle
	bgfx.blit(blit_buffer.blit_viewid, rbhandle, 0, 0, assert(fbmgr.get_rb(render_target.fb_idx, 1).handle))
	return bgfx.read_texture(rbhandle, blit_buffer.handle)
end

local function select_obj(blit_buffer, render_target)
	local viewrect = render_target.view_rect
	local selecteid = which_entity_hitted(blit_buffer.handle, viewrect, blit_buffer.elemsize)
	if selecteid then
		local id = pickup_refs[selecteid]
		if id then
			local e = world:entity(id)
			log.info("pick entity id: ", id, e.name)
			world:pub {"pickup", id}
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
		elseif nextstep == "select_obj" then
			select_obj(pc.blit_buffer, v.render_target)
			close_pickup()
		end
		check_next_step(pc)
	end
end

local function remove_ref(id)
	local _id = pickup_refs[id]
	pickup_refs[id] = nil
	if _id then
		pickup_refs[_id] = nil
	end
end

function pickup_sys:end_filter()
	for e in w:select "filter_result:in render_object:in filter_material:out id:in" do
		local fr = e.filter_result
		local st = e.render_object.fx.setting.surfacetype
		local fm = e.filter_material
		local qe = w:singleton("pickup_queue", "primitive_filter:in")
		for _, fn in ipairs(qe.primitive_filter) do
			if fr[fn] == true then
				local m = assert(pickup_materials[st])
				local state = e.render_object.state
				local id = genid()
				pickup_refs[id] = e.id
				pickup_refs[e.id] = id
				fm[fn] = {
					fx			= m.fx,
					properties	= get_properties(id, m.properties),
					state		= irender.check_primitive_mode_state(state, m.state),
				}
			elseif fr[fn] == false then
				fm[fn] = nil
				remove_ref(e.id)
			end
		end
	end
end

function pickup_sys:entity_remove()
	for e in w:select "REMOVED id:in" do
		remove_ref(e.id)
	end
end
