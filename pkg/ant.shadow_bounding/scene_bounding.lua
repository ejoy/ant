local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local Q         = world:clibs "render.queue"

local queuemgr	= ecs.require "ant.render|queue_mgr"
local irq		= ecs.require "ant.render|renderqueue"
local ishadow	= ecs.require "ant.render|shadow.shadow_system"
local BOUNDING_NEED_UPDATE = true

local sb_sys = ecs.system "scene_bounding_system"
function sb_sys:entity_init()
    if not BOUNDING_NEED_UPDATE then
        BOUNDING_NEED_UPDATE = w:check "INIT scene bounding"
    end
end

function sb_sys:entity_remove()
    if not BOUNDING_NEED_UPDATE then
        BOUNDING_NEED_UPDATE = w:first "REMOVED scene bounding" 
    end
end

local function build_nearfar(objaabb, zn, zf)
	local n, f = mu.aabb_minmax_index(objaabb, 3)
	return math.min(zn, n), math.max(zf, f)
end

local function obj_visible(obj, queue_index)
	return Q.check(obj.visible_idx, queue_index) and (not Q.check(obj.cull_idx, queue_index))
end

--TODO: read from setting file
local nearHit, farHit = 1, 100

local function build_scene_info(C, sb)
	local mqidx = queuemgr.queue_index "main_queue"

	local F = C.camera.frustum
	local zn, zf = math.maxinteger, -math.maxinteger
	local PSR_ln, PSR_lf = math.maxinteger, -math.maxinteger
	local PSC_ln, PSC_lf = math.maxinteger, -math.maxinteger

	local Lv = sb.light_info.Lv
	local Cv = C.camera.viewmat
	local PSC, PSR = math3d.aabb(), math3d.aabb()

	local function merge_obj_PSC_PSR(obj, receiveshadow, castshadow, bounding)
		if obj_visible(obj, mqidx) then
			local aabbLS
			if receiveshadow then
				local sceneaabb = bounding.scene_aabb
				if mc.NULL ~= sceneaabb then
					zn, zf = build_nearfar(math3d.aabb_transform(Cv, sceneaabb), zn, zf)
					if Lv then
						aabbLS = math3d.aabb_transform(Lv, sceneaabb)
						PSR_ln, PSR_lf = build_nearfar(aabbLS, PSR_ln, PSR_lf)
					end

					PSR = math3d.aabb_merge(PSR, sceneaabb)
				end
			end
	
			if castshadow then
				local sceneaabb = bounding.scene_aabb
				if mc.NULL ~= sceneaabb then
					if nil == aabbLS and Lv then
						aabbLS =  math3d.aabb_transform(Lv, sceneaabb)
					end
					if aabbLS then
						PSC_ln, PSC_lf = build_nearfar(aabbLS, PSC_ln, PSC_lf)
					end
					PSC = math3d.aabb_merge(PSC, sceneaabb)
				end
			end
		end
	end

	for e in w:select "render_object_visible render_object:in bounding:in receive_shadow?in cast_shadow?in" do
		merge_obj_PSC_PSR(e.render_object, e.receive_shadow, e.cast_shadow, e.bounding)
	end

	for e in w:select "hitch_visible hitch:in bounding:in receive_shadow?in cast_shadow?in" do
		merge_obj_PSC_PSR(e.hitch, e.receive_shadow, e.cast_shadow, e.bounding)
	end

	local si = sb.scene_info
	if math3d.aabb_isvalid(PSC) then
		si.PSC = PSC
	end

	if math3d.aabb_isvalid(PSR) then
		si.zn, si.zf = math.max(zn, F.n), math.min(zf, F.f)
	else
		si.zn, si.zf = F.n, F.f
		PSR = math3d.minmax(math3d.frustum_points(C.camera.viewprojmat))
	end

	si.PSR_ln, si.PSR_lf = PSR_ln, PSR_lf
	si.PSC_ln, si.PSC_lf = PSC_ln, PSC_lf
	si.nearHit, si.farHit = nearHit, farHit

	si.PSR = PSR
end

function sb_sys:update_camera_bounding()
	local changed, C = ishadow.shadow_changed()
    if BOUNDING_NEED_UPDATE or changed then
		C = irq.main_camera_entity()
	end

	C = C or irq.main_camera_changed()
	if C then
		w:extend(C, "scene:in camera:in")
		local sbe = w:first "shadow_bounding:in"
		build_scene_info(C, sbe.shadow_bounding)
		BOUNDING_NEED_UPDATE = false
	end
end