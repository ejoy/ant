local m = {}

local MATERIAL_INDICES = {}

local QUEUE_MATERIALS = {}

function m.material_index(queue_name)
	return QUEUE_MATERIALS[queue_name]
end

function m.material_indices()
    return MATERIAL_INDICES
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
	--qidx&midx is base 0
	local function register_queue(qn, midx, qmask)
		local _ = QUEUE_INDICES[qn] == nil or error (qn .. " already register")

		local qidx
		if qmask then
			for i=0, 63 do
				local testmask = i << 1
				if testmask == qmask&testmask then
					qidx = i
				end
			end
			if nil == qidx then
				error("Invalid queue mask: " .. qmask)
			end
		else
			qidx = NEXT_QUEUE_IDX
			if qidx >= 64 then
				error(("Max queue index is 64, %d is provided"):format(qidx))
			end
	
			NEXT_QUEUE_IDX = NEXT_QUEUE_IDX + 1
			qmask = (1 << qidx)
		end

		QUEUE_INDICES[qn] = qidx
		QUEUE_MASKS[qn] = qmask

		local _ = QUEUE_MATERIALS[qn] == nil or error (qn .. " material index already register")

		if midx >= 64 then
			error(("Max material index is 64, %d is provided"):format(midx))
		end
		QUEUE_MATERIALS[qn] = midx
        MATERIAL_INDICES[midx] = true
		return qidx
	end

	register_queue("main_queue", 			alloc_material())
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