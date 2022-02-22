local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid<const>					= 256
local bloom_chain_count<const>			= 4
local imgui_count<const>				= 16
local lightmap_ds_count<const>			= 10

local pool = {}

-- if we expect viewid is in order, we should mark here, and *NOT* use generate method to alloc viewid
local bindings = {}

local current_viewid = 1
local function alloc_id(name, count)
	count = count or 1
	local c = current_viewid

	local next_vid = c + count
	if next_vid > max_viewid then
		error(("not enough view id, max viewid: %d, have been alloced:%d"):format(max_viewid, current_viewid))
	end
	current_viewid = c + count
	for i=1, count do
		pool[c+i-1] = name
	end

	bindings[name] = {c, count}
end

alloc_id "csm_fb"
alloc_id "csm1"
alloc_id "csm2"
alloc_id "csm3"
alloc_id "csm4"
alloc_id "omni_Green"
alloc_id "omni_Yellow"
alloc_id "omni_Blue"
alloc_id "omni_Red"
alloc_id "ibl"
alloc_id "depth"
alloc_id "main_view"

--start postprocess
alloc_id "resolve"
alloc_id "copy_scene"
alloc_id "postprocess_obj"
alloc_id("bloom_ds", bloom_chain_count)
alloc_id("bloom_us", bloom_chain_count)
alloc_id "tonemapping"
--end postprocess

alloc_id("lightmap_ds", lightmap_ds_count)
alloc_id "lightmap_storage"
alloc_id "pickup"
alloc_id "pickup_blit"
alloc_id "effect_view"
alloc_id "uiruntime"
alloc_id("uieditor", imgui_count)

function viewid_pool.generate(name, count)
	alloc_id(name, count)
	return bindings[name][1]
end

function viewid_pool.all_bindings()
	return bindings
end

function viewid_pool.get(name)
	local b = bindings[name]
	if b then
		return b[1]
	end

	error(string.format("%s is not bind", name))
end

function viewid_pool.get_range(name)
	local b = bindings[name]
	return b[1], b[2]
end

return viewid_pool