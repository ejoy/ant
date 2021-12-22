local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid<const>					= 256
local bloom_chain_count<const>			= 4
local lightmap_ds_count<const>			= 10
local current_viewid = 1
local function alloc_id(count)
	count = count or 1
	local c = current_viewid
	current_viewid = c + count
	return c
end

-- if we expect viewid is in order, we should mark here, and *NOT* use generate method to alloc viewid
local bindings = {
	csm_fb		= alloc_id(),
	csm1 		= alloc_id(),
	csm2 		= alloc_id(),
	csm3 		= alloc_id(),
	csm4 		= alloc_id(),
	omni_Green	= alloc_id(),
	omni_Yellow = alloc_id(),
	omni_Blue	= alloc_id(),
	omni_Red	= alloc_id(),
	ibl			= alloc_id(),
	depth		= alloc_id(),
	main_view 	= alloc_id(),

	--start postprocess
	resolve		= alloc_id(),
	copy_scene	= alloc_id(),
	postprocess_obj= alloc_id(),
	bloom_ds	= alloc_id(bloom_chain_count),
	bloom_us	= alloc_id(bloom_chain_count),
	tonemapping = alloc_id(),
	--end postprocess

	lightmap_ds	= alloc_id(lightmap_ds_count),
	lightmap_storage=alloc_id(),
	pickup 		= alloc_id(),
	pickup_blit = alloc_id(),

	effect_view = alloc_id(),
	uiruntime	= alloc_id(),
	uieditor	= alloc_id(),
}

local pool = {}
for n, v in pairs(bindings) do
	if pool[v] then
		error(("duplicate viewid defined:%d"):format(v))
	end
	pool[v] = true
end

local function find_valid_viewid(afterviewid)
	local vid = afterviewid+1
	while pool[vid] ~= nil and vid < max_viewid do
		vid = vid + 1
	end
	return vid < max_viewid and vid or nil
end

function viewid_pool.check_range(name, range)
	for id=assert(bindings[name]), range do
		if pool[id] == nil then
			error(("viewid:%s, range:%d, is not continuous"):format(name, range))
		end
	end
end

function viewid_pool.generate(name, afterviewid)
	afterviewid = afterviewid or viewid_pool.get "main_view"
	local vid = find_valid_viewid(afterviewid)
	if vid then
		viewid_pool.bind(name, vid)
	end
	return vid
end

function viewid_pool.bind(name, viewid)
	if viewid < 0 or viewid > max_viewid then
		error("invalid viewid")
	end

	if pool[viewid] then
		error(("viewid:%d have been used"):format(viewid))
	end

	pool[viewid] = true
	bindings[name] = viewid
end

function viewid_pool.get(name)
	local viewid = bindings[name]
	if viewid then
		return viewid
	end

	error(string.format("%s is not bind", name))
end

return viewid_pool