local util = {}; util.__index = util

local animodule = require "hierarchy.animation"		
local asset = import_package "ant.asset"
local timer = import_package "ant.timer"
-- for animation
function util.add_animation(comp, pkgname, respath, weight, weighttype)
	weighttype = weighttype or "full"	-- can be 'full' or 'partial'
	local aniresult = assert(comp.aniresult)
	local numjoints = aniresult:count()	
	table.insert(assert(comp.anilist), {
		weight=weight, 
		handle=asset.load(pkgname, respath).handle, 
		ref_path={package=pkgname, filename=respath},
		weighttype=weighttype,
		sampling_cache = animodule.new_sampling_cache(numjoints),
		scale = 1,		
		start_counter=0,
		name = "",
		ratio = 0,
		looptimes=0,
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

function util.play_animation(comp, pose)
	local current = timer.get_sys_counter()
	local anilist = comp.anilist

	for _, aniref in ipairs(assert(pose.anilist)) do
		local ani = assert(anilist[aniref.idx])
		ani.start_counter = current
	end
end

return util