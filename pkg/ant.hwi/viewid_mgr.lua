local mgr = {}

local MAX_VIEWID<const>	= 256
local BINDINGS = {}
local VIEWID_NAMES = {}

local REMAPPING_LIST = {}

--viewid is base 0
local function add_view(name, afterview_idx)
	local id = #REMAPPING_LIST
	if id >= MAX_VIEWID then
		error(("not enough view id, max viewid: %d"):format(MAX_VIEWID))
	end

	local real_id = (afterview_idx and afterview_idx+1 or id)

	BINDINGS[name] = id
	VIEWID_NAMES[id] = name

	assert(#REMAPPING_LIST == id)
	table.insert(REMAPPING_LIST, real_id+1, id)
	return id
end

add_view "csm_fb"		-- 0
add_view "skinning"
add_view "csm1"
add_view "csm2"
add_view "csm3"
add_view "csm4"			-- 5
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
add_view "ibl"					--10
add_view "ibl_SH_readback"
add_view "pre_depth"
add_view "scene_depth"
add_view "depth_resolve"
add_view "depth_mipmap"			--15
add_view "ssao"
add_view "main_view"
add_view "outline"
add_view "velocity"
add_view "svblur"
add_view "shblur"
--start postprocess
add_view "postprocess_obj"
--add_view "blur"
add_view "blur_ds1"
add_view "blur_ds2"
add_view "blur_ds3"
add_view "blur_ds4"
add_view "blur_us1"
add_view "blur_us2"
add_view "blur_us3"
add_view "blur_us4"
add_view "vblur"
add_view "hblur"
--add_view "bloom"
add_view "bloom_ds1"
add_view "bloom_ds2"
add_view "bloom_ds3"
add_view "bloom_ds4"
add_view "bloom_us1"
add_view "bloom_us2"
add_view "bloom_us3"
add_view "bloom_us4"
add_view "tonemapping"
add_view "effect_view"
add_view "taa"
add_view "taa_copy"
add_view "taa_present"
add_view "fxaa"
add_view "fsr_resolve"
add_view "fsr_easu"
add_view "fsr_rcas"
add_view "swapchain"
--end postprocess

add_view "lightmap_storage"
add_view "pickup"
add_view "pickup_blit"			--25
add_view "mem_texture"
add_view "uiruntime"

local remapping_need_update = true

function mgr.generate(name, afterwho, count)
	local _ = nil == mgr.get(name) or error (("%s already defined"):format(name))

	count = count or 1
	local viewid = add_view(name, mgr.get(afterwho))
	for i=2, count do
		add_view(name, viewid)
	end

	remapping_need_update = true
	return viewid
end

function mgr.get(name)
	return BINDINGS[name]
end

function mgr.name(viewid)
	return VIEWID_NAMES[viewid]	--viewid base 0
end

local bgfx = require "bgfx"
function mgr.check_remapping()
	if remapping_need_update then
        bgfx.set_view_order(REMAPPING_LIST)
        for n, viewid in pairs(BINDINGS) do
            bgfx.set_view_name(viewid, n)
        end
		remapping_need_update = false
	end
end


--test
-- print "all viewid:"

-- local function print_viewids()
-- 	local viewids = {}
-- 	for viewid in pairs(VIEWID_NAMES) do
-- 		viewids[#viewids+1] = viewid
-- 	end

-- 	table.sort(viewids)

-- 	for _, viewid in ipairs(viewids) do
-- 		local viewname = VIEWID_NAMES[viewid]
-- 		print("viewname:", viewname, "viewid:", viewid, "binding:", BINDINGS[viewname])
-- 	end
-- end

-- print_viewids()

-- mgr.generate("main_view1", "main_view")

-- print "============================="

-- print_viewids()


-- local function print_rempping()
-- 	for idx, mviewid in ipairs(REMAPPING_LIST) do
-- 		local viewid = idx-1
-- 		local viewname = VIEWID_NAMES[mviewid]
-- 		print("viewname:", viewname, "viewid:", viewid, "mapping_viewid:", mviewid)
-- 	end
-- end

-- if mgr.need_update_remapping() then
-- 	print "============================="
-- 	print_rempping()
-- 	mgr.clear_remapping()
-- end

-- print "============================="
-- print("main_view:", mgr.get "main_view", "main_view1:", mgr.get "main_view1", "remapping main_view1:", REMAPPING_LIST[mgr.get "main_view1"])

-- if mgr.get(VIEWID_NAMES[#VIEWID_NAMES]) >= mgr.get "main_view1" then
-- 	error "Invalid in generate viewid"
-- end

return mgr