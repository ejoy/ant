local viewid_pool = {}

local max_viewid<const>					= 256
local bindings = {}
local viewid_names = {}

local remapping_id_list = {}

--viewid is base 0
local function add_view(name, afterview_idx)
	local id = #remapping_id_list
	if id >= max_viewid then
		error(("not enough view id, max viewid: %d"):format(max_viewid))
	end

	local real_id = (afterview_idx and afterview_idx+1 or id)

	bindings[name] = id
	viewid_names[id] = name
	
	assert(#remapping_id_list == id)
	remapping_id_list[id+1] = real_id
	return id
end

add_view "csm_fb"
add_view "skinning"
add_view "csm1"
add_view "csm2"
add_view "csm3"
add_view "csm4"
--TODO: vblur and hblur can use only 1 viewid
add_view "vblur"
add_view "hblur"
-- NOTE: omni shadowmap is not use right now
-- add_view "omni_Green"
-- add_view "omni_Yellow"
-- add_view "omni_Blue"
-- add_view "omni_Red"
add_view "panorama2cubmap"
add_view "panorama2cubmapMips"
add_view "ibl"
add_view "ibl_SH_readback"
add_view "pre_depth"
add_view "scene_depth"
add_view "depth_resolve"
add_view "depth_mipmap"
add_view "ssao"
add_view "main_view"

--start postprocess
add_view "postprocess_obj"		--26
add_view "bloom"
add_view "effect_view"
add_view "tonemapping"
add_view "fxaa"
--end postprocess

add_view "lightmap_storage"
add_view "pickup"
add_view "pickup_blit"
add_view "uiruntime"

local remapping_need_update = true

function viewid_pool.generate(name, afterwho, count)
	assert(nil == viewid_pool.get(name), ("%s already defined"):format(name))

	count = count or 1
	local viewid = add_view(name, viewid_pool.get(afterwho))
	for i=2, count do
		add_view(name, viewid)
	end

	remapping_need_update = true
	return viewid
end

function viewid_pool.all_bindings()
	return bindings
end

function viewid_pool.clear_remapping()
	remapping_need_update = false
end

function viewid_pool.need_update_remapping()
	return remapping_need_update
end

function viewid_pool.remapping()
	return remapping_id_list
end

function viewid_pool.get(name)
	return bindings[name]
end

function viewid_pool.viewname(viewid)
	return viewid_names[viewid]	--viewid base 0
end

--test
-- print "all viewid:"

-- local function print_viewids()
-- 	for viewid, viewname in ipairs(viewid_names) do
-- 		print("viewname:", viewname, "viewid:", viewid, "binding:", bindings[viewname])
-- 	end
-- end

-- print_viewids()

-- viewid_pool.generate("main_view1", "main_view")

-- print_viewids()


-- local function print_rempping()
-- 	for viewid, mviewid in pairs(remapping_id_list) do
-- 		local viewname = viewid_names[viewid]
-- 		print("viewname:", viewname, "viewid:", viewid, "mapping_viewid:", mviewid)
-- 	end
-- end

-- if viewid_pool.remapping_changed() then
-- 	print_rempping()
-- 	viewid_pool.clear_remapping_changed()
-- end

-- print("main_view:", viewid_pool.get "main_view", "main_view1:", viewid_pool.get "main_view1", "remapping main_view1:", remapping_id_list[viewid_pool.get "main_view1"])
-- if viewid_pool.get(viewid_names[#viewid_names]) >= viewid_pool.get "main_view1" then
-- 	error "Invalid in generate viewid"
-- end

return viewid_pool