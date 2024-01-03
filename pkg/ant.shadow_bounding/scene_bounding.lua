local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local Q         = world:clibs "render.queue"

local queuemgr	= ecs.require "ant.render|queue_mgr"
local irq		= ecs.require "ant.render|render_system.renderqueue"

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

local function build_znzf(objaabb, zn, zf)
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

	local zn, zf = math.maxinteger, -math.maxinteger
	local Cv = C.camera.viewmat
	local PSC, PSR = math3d.aabb(), math3d.aabb()

	local function merge_obj_PSC_PSR(obj, receiveshadow, castshadow, bounding)
		if obj_visible(obj, mqidx) then
			if receiveshadow then
				local sceneaabb = bounding.scene_aabb
				if mc.NULL ~= sceneaabb then
					zn, zf = build_znzf(math3d.aabb_transform(Cv, sceneaabb), zn, zf)
					PSR = math3d.aabb_merge(PSR, sceneaabb)
				end
			end
	
			if castshadow then
				local sceneaabb = bounding.scene_aabb
				if mc.NULL ~= sceneaabb then
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

	sb.zn, sb.zf = math.max(C.camera.frustum.n, zn), math.min(C.camera.frustum.f, zf)
	sb.nearHit, sb.farHit = nearHit, farHit

	sb.PSR, sb.PSC = math3d.marked_aabb(PSR), math3d.marked_aabb(PSC)
end

function sb_sys:update_camera_bounding()
	local C
    if BOUNDING_NEED_UPDATE or w:check "scene_changed scene bounding" then
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