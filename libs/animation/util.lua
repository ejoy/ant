local util = {}; util.__index = util

local animodule = require "hierarchy.animation"		
local asset = import_package "ant.asset"
-- for animation
function util.add_animation(comp, respath, weight, weighttype)
	weighttype = weighttype or "full"	-- can be 'full' or 'partial'

	local aniresult = assert(comp.aniresult)
	local numjoints = aniresult:count()
	table.insert(assert(comp.anilist), {
		weight=weight, 
		handle=asset.load(respath).handle, 
		ref_path=respath,
		type=weighttype,
		sampling_cache = animodule.new_sampling_cache(numjoints),
	})
end

function util.remove_animation(comp, aniidx)
	local anilist = assert(comp.anilist)
	if aniidx > #anilist then
		error(string.format("ani index out of range:%d-%d", aniidx, #anilist))
	end

	table.remove(anilist, aniidx)
end

function util.init_animation(comp, skeleton)
	local skehandle = assert(skeleton.assetinfo.handle)
	local numjoints = #skehandle
	comp.aniresult = animodule.new_ani_result(numjoints)
	comp.anilist = {}
end

function util.set_animation_weight(comp, aniidx, weight)
	local anilist = assert(comp.anilist)
	if aniidx > #anilist then
		error(string.format("ani index out of range:%d-%d", aniidx, #anilist))
	end

	anilist[aniidx].weight = weight
end

return util