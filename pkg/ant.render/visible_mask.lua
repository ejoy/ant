local ecs = ...
local world = ecs.world
local w = world.w

local queuemgr = ecs.require "queue_mgr"
local Q	= world:clibs "render.queue"

local ivm = {}

local MASK_MAPPER<const> = {
	main_view = {
		set = function (vidx, v)
			Q.set(vidx, queuemgr.queue_index "main_queue", v)
			Q.set(vidx, queuemgr.queue_index "pre_depth_queue", v)
		end,
		check = function (vidx)
			return Q.check(vidx, "main_queue") and Q.check(vidx, "pre_depth_queue")
		end,
	},
	selectable = {
		set = function (vidx, v)
			Q.set(vidx, queuemgr.queue_index "pickup_queue", v)
		end,
		check = function (vidx)
			return Q.check(vidx, queuemgr.queue_index "pickup_queue")
		end,
	},
	cast_shadow = {
		set = function (vidx, v)
			Q.set(vidx, queuemgr.queue_index "csm1_queue", v)
			Q.set(vidx, queuemgr.queue_index "csm2_queue", v)
			Q.set(vidx, queuemgr.queue_index "csm3_queue", v)
			Q.set(vidx, queuemgr.queue_index "csm4_queue", v)
		end,
		check = function (vidx)
			return	Q.check(vidx, queuemgr.queue_index "csm1_queue") and
					Q.check(vidx, queuemgr.queue_index "csm2_queue") and
					Q.check(vidx, queuemgr.queue_index "csm3_queue") and
					Q.check(vidx, queuemgr.queue_index "csm4_queue")
		end,
	},
	outline = {
		set = function(vidx, v)
			Q.set(vidx, queuemgr.queue_index "outline_queue", v)
		end,
		check = function (vidx)
			return Q.check(vidx, queuemgr.queue_index "outline_queue")
		end
	},
}

local DEFAULT_MASK<const> = {
	set = function (vidx, v, qn)
		Q.set(vidx, queuemgr.queue_index(qn), v)
	end,
	check = function (vidx, qn)
		local qidx = queuemgr.queue_index(qn) or error(("Invalid queue_name:%s"):format(qn))
		return Q.check(vidx, qidx)
	end,
}

local function set_masks(vidx, names, v)
	for n in names:gmatch "[%w_]+" do
		local P = MASK_MAPPER[n] or DEFAULT_MASK
		P.set(vidx, v, n)
	end
end

local function check_mask(vidx, name)
	local P = MASK_MAPPER[name] or DEFAULT_MASK
	return P.check(vidx, name)
end

ivm.set_masks_by_idx	= set_masks
ivm.check_by_idx 		= check_mask

function ivm.set_masks(e, names, v)
	w:extend(e, "render_object:in")
	set_masks(e.render_object.visible_idx, names, v)
end

function ivm.check(e, name)
	w:extend(e, "render_object:in")
	return check_mask(e.render_object.visible_idx, name)
end

return ivm
