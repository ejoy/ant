local m = {}

local MATERIAL_INDICES = {}

function m.material_index(queue_name)
	return MATERIAL_INDICES[queue_name]
end

local QUEUE_INDICES, QUEUE_MASKS = {}, {}
do
	local NEXT_QUEUE_IDX = 0
	--qidx&midx is base 0
	local function register_queue(qn, midx)
		assert(QUEUE_INDICES[qn] == nil, qn .. " already register")
		local qidx = NEXT_QUEUE_IDX
		if qidx >= 64 then
			error(("Max queue index is 64, %d is provided"):format(qidx))
		end

		NEXT_QUEUE_IDX = NEXT_QUEUE_IDX + 1

		QUEUE_INDICES[qn] = qidx
		QUEUE_MASKS[qn] = (1 << qidx)

		assert(MATERIAL_INDICES[qn] == nil, qn .. " material index already register")

		if midx >= 64 then
			error(("Max material index is 64, %d is provided"):format(midx))
		end
		MATERIAL_INDICES[qn] = midx
		return qidx
	end

	register_queue("main_queue", 			0)
	register_queue("pre_depth_queue", 		1)
	register_queue("pickup_queue", 			2)
	register_queue("csm1_queue", 			3)
	register_queue("csm2_queue", 			3)
	register_queue("csm3_queue", 			3)
	register_queue("csm4_queue", 			3)
	register_queue("bake_lightmap_queue",	4)

	m.register_queue = register_queue
end

function m.queue_index(qn)
    --TODO: init in some system
	if QUEUE_INDICES[qn] == nil then
		m.register_queue(qn, 0)
	end
	return assert(QUEUE_INDICES[qn])
end

function m.queue_mask(qn)
    --TODO: init in some system
	if QUEUE_MASKS[qn] == nil then
		m.register_queue(qn, 0)
	end
	return assert(QUEUE_MASKS[qn])
end

return m