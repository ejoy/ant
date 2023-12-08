local ecs = ...
assert(ecs.world)

local m = {}
local QUEUE_MATERIALS = {}

function m.material_index(queue_name)
	return QUEUE_MATERIALS[queue_name]
end

local QUEUE_INDICES, QUEUE_MASKS = {}, {}
do
	local NEXT_QUEUE_IDX = 0
	local NEXT_MATERIAL_IDX = 0

	local function alloc_material()
		local idx = NEXT_MATERIAL_IDX
		NEXT_MATERIAL_IDX = NEXT_MATERIAL_IDX + 1
		return idx
	end

	local DEFAULT_MATERIAL_IDX<const> = alloc_material()
	--qidx&midx is base 0
	local function register_queue(qn, midx)
		local _ = QUEUE_INDICES[qn] == nil or error (qn .. " already register")

		local qidx = NEXT_QUEUE_IDX
		if qidx >= 64 then
			error(("Max queue index is 64, %d is provided"):format(qidx))
		end

		NEXT_QUEUE_IDX = NEXT_QUEUE_IDX + 1

		QUEUE_INDICES[qn] = qidx
		QUEUE_MASKS[qn] = (1 << qidx)

		local _ = QUEUE_MATERIALS[qn] == nil or error (qn .. " material index already register")

		midx = midx or DEFAULT_MATERIAL_IDX
		if midx >= 64 then
			error(("Max material index is 64, %d is provided"):format(midx))
		end
		QUEUE_MATERIALS[qn] = midx
		return qidx
	end

	register_queue("main_queue", 			DEFAULT_MATERIAL_IDX)
	register_queue("pre_depth_queue", 		alloc_material())
	register_queue("pickup_queue", 			alloc_material())
	local shadow_material_idx	= alloc_material()
	register_queue("csm1_queue", 			shadow_material_idx)
	register_queue("csm2_queue", 			shadow_material_idx)
	register_queue("csm3_queue", 			shadow_material_idx)
	register_queue("csm4_queue", 			shadow_material_idx)
	register_queue("bake_lightmap_queue",	alloc_material())

	m.alloc_material = alloc_material
	m.register_queue = register_queue
end

function m.has(qn)
	return QUEUE_INDICES[qn]
end

function m.queue_index(qn)
	return assert(QUEUE_INDICES[qn])
end

function m.queue_mask(qn)
	return assert(QUEUE_MASKS[qn])
end

return m