local ecs = ...
local world = ecs.world
local w = world.w

local mu 		= import_package "ant.math".util
local R         = world:clibs "render.render_material"
local math3d	= require "math3d"
local bgfx 		= require "bgfx"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"
local renderpkg = import_package "ant.render"
local fbmgr 	= renderpkg.fbmgr
local sampler	= renderpkg.sampler

local assetmgr  = import_package "ant.asset"

local RM		= ecs.require "ant.material|material"

local hwi		= import_package "ant.hwi"

local queuemgr  = ecs.require "ant.render|queue_mgr"

local INV_Z<const> = true
local INF_F<const> = true
local pickup_material, pickup_skin_material

local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local function find_camera(id)
	local e <close> = world:entity(id, "camera:in")
	return e.camera
end

local function cvt_clickpt(pt, ratio)
	if ratio == nil or ratio == 1 then
		return pt
	end

	return {
		mu.cvt_size(pt[1], ratio),
		mu.cvt_size(pt[2], ratio),
	}
end

local function update_camera(pu_camera_ref, clickpt)
	local mq = w:first "main_queue camera_ref:in render_target:in"
	local main_vr = mq.render_target.view_rect

	local ndc2D = mu.pt2D_to_NDC(cvt_clickpt(clickpt, main_vr.ratio), main_vr)
	local eye, at = mu.NDC_near_far_pt(ndc2D)

	if INV_Z then
		eye, at = at, eye
	end

	local mqc = world:entity(mq.camera_ref, "camera:in")
	local maincamera = mqc.camera
	local vp = maincamera.viewprojmat
	local ivp = math3d.inverse(vp)
	eye = math3d.transformH(ivp, eye, 1)
	at = math3d.transformH(ivp, at, 1)

	local pqc<close> = world:entity(pu_camera_ref, "camera:in camera_changed?out")
	pqc.camera_changed = true
	local camera = pqc.camera
	local viewdir = math3d.normalize(math3d.sub(at, eye))
	camera.viewmat.m	= math3d.lookto(eye, viewdir, camera.updir)
	camera.projmat.m	= math3d.projmat(camera.frustum, INV_Z)
	camera.infprojmat.m = math3d.projmat(camera.frustum, INV_Z, INF_F)
	camera.viewprojmat.m= math3d.mul(camera.projmat, camera.viewmat)
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

local blit_viewid<const> = hwi.viewid_get "pickup_blit"
local pickupviewid<const> = hwi.viewid_get "pickup"

local function blit_buffer_init(blit_buffer)
	blit_buffer.handle = bgfx.memory_texture(blit_buffer.w*blit_buffer.h * blit_buffer.elemsize)
	blit_buffer.rb_idx = fbmgr.create_rb {
		w = blit_buffer.w,
		h = blit_buffer.h,
		layers = 1,
		format = "RGBA8",
		flags = sampler {
			BLIT="BLIT_AS_DST|BLIT_READBACK_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		}
	}
end

local pickup_buffer_w<const>, pickup_buffer_h<const> = 8, 8
local fb_renderbuffer_flag<const> = sampler {
	RT="RT_ON",
	MIN="POINT",
	MAG="POINT",
	U="CLAMP",
	V="CLAMP"
}

local function create_pick_entity()
	local camera_ref = world:create_entity{
		policy = {
			"ant.camera|camera",
		},
		data = {
			scene = {},
			camera = {
				frustum = {
					type="mat", n=0.2, f=1000, fov=0.5, aspect=pickup_buffer_w / pickup_buffer_h
				},
			},
			camera_depend = true,
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
			format = "D16F",
			flags = fb_renderbuffer_flag,
		}})

	world:create_entity {
		policy = {
			"ant.render|render_queue",
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
				view_rect = {
					x = 0, y = 0, w = pickup_buffer_w, h = pickup_buffer_h,
				},
				clear_state = {
					color = 0,
					depth = 0,
					clear = "CD"
				},
				fb_idx = fbidx,
			},
			queue_name 	= "pickup_queue",
			pickup_queue= true,
			visible		= false,
		}
	}
end

function pickup_sys:init()
	create_pick_entity()
	pickup_material			= assetmgr.resource '/pkg/ant.objcontroller/pickup/assets/pickup_opacity.material'
	pickup_skin_material	= assetmgr.resource '/pkg/ant.objcontroller/pickup/assets/pickup_opacity_skin.material'
end

function pickup_sys:entity_init()
	for e in w:select "INIT pickup_queue pickup:in" do
		local pickup = e.pickup
		pickup.clickpt = {-1, -1}
		blit_buffer_init(pickup.blit_buffer)
	end
end

local function open_pickup(x, y, cb)
	local e = w:first "pickup_queue pickup:in visible?out"
	e.pickup.nextstep = "blit"
	e.pickup.clickpt[1] = x
	e.pickup.clickpt[2] = y
	e.pickup.picked_callback = cb
	e.visible = true
	w:submit(e)
end

local function close_pickup()
	local e = w:first "pickup_queue pickup:in visible?out"
	e.pickup.nextstep = nil
	e.visible = false
	w:submit(e)
end

function pickup_sys:update_camera_depend()
	local puq = w:first "pickup_queue visible pickup:in camera_ref:in"
	if puq then
		update_camera(puq.camera_ref, puq.pickup.clickpt)
		-- if cw_enable then
		-- 	local main_camera <close> = world:entity(irq.main_camera())
		-- 	local mc_viewmat = main_camera.camera.viewmat
		-- 	local mc_inv_viewmat = math3d.inverse(mc_viewmat)
		-- 	for _, pm in pairs(pickup_materials) do
		--		pm.u_viewcamera_viewmat = mc_viewmat
		--		pm.u_viewcamera_inv_viewmat = mc_inv_viewmat
		-- 	end
		-- end
	end
end

local function blit(blit_buffer, render_target)
	local rb = fbmgr.get_rb(blit_buffer.rb_idx)
	local rbhandle = rb.handle
	bgfx.blit(blit_viewid, rbhandle, 0, 0, assert(fbmgr.get_rb(render_target.fb_idx, 1).handle))
	return bgfx.read_texture(rbhandle, blit_buffer.handle)
end

local function select_obj(pc, render_target)
	local blit_buffer = pc.blit_buffer
	local viewrect = render_target.view_rect
	local eid = which_entity_hitted(blit_buffer.handle, viewrect, blit_buffer.elemsize)
	if eid then
		log.info("pick entity id: ", eid)
	else
		log.info("not found any eid")
	end
	pc.picked_callback = nil
	world:pub {"pickup", eid, pc.clickpt[1], pc.clickpt[2]}
end

local state_list = {
	blit = "wait",
	wait = "select_obj",
}

local function check_next_step(pc)
	pc.nextstep = state_list[pc.nextstep]
end

function pickup_sys:pickup()
	local puq = w:first "pickup_queue visible pickup:in render_target:in"
	if puq then
		local pc = puq.pickup
		local nextstep = pc.nextstep
		if nextstep == "blit" then
			blit(pc.blit_buffer, puq.render_target)
		elseif nextstep == "select_obj" then
			select_obj(pc, puq.render_target)
			close_pickup()
		end
		check_next_step(pc)
	end
end

local function which_material(e)
	--NOTE: pickup system not supprt draw indirect, or we need pickup program generate from material compile??
	w:extend(e, "skinning?in")
    return e.skinning and pickup_skin_material or pickup_material
end

local function create_pickup_state(srcstate, dststate)
	local s, d = bgfx.parse_state(srcstate), bgfx.parse_state(dststate)
	d.PT, d.CULL = s.PT, s.CULL
	return bgfx.make_state(d)
end

function pickup_sys:update_filter()
	for e in w:select "filter_result visible_state:in render_object:update filter_material:in eid:in" do
		if e.visible_state["pickup_queue"] then
			local ro = e.render_object
			local fm = e.filter_material

			local dstres = which_material(e)

			local mi = RM.create_instance(dstres.object)
			assert(not fm.main_queue:isnull())
			mi:set_state(create_pickup_state(fm.main_queue:get_state(), dstres.state))
			mi.u_id = math3d.vector(packeid_as_rgba(e.eid))
			fm["pickup_queue"] = mi

			R.set(ro.rm_idx, queuemgr.material_index "pickup_queue", mi:ptr())
		end
	end
end

local ipu = {}
function ipu.pick(x, y, cb)
	open_pickup(x, y, cb)
end
return ipu
