local setting	= import_package "ant.settings"

local ics = {}
local SPLIT_NUM		= setting:get "graphic/shadow/split_num"
local SPLIT_RATIOS	= setting:get "graphic/shadow/split_ratios"
local SPLIT_LAMADA	= setting:get "graphic/shadow/split_lamada"

if SPLIT_RATIOS then
	if nil ~= SPLIT_NUM then
		if SPLIT_NUM ~= #SPLIT_RATIOS then
			error(("split_num:%d is not equal SHADOW_CFG.split_ratios number"):format(SPLIT_NUM, #SPLIT_RATIOS))
		end
	else
		SPLIT_NUM = #SPLIT_RATIOS
	end

	if #SPLIT_RATIOS > 4 then
		error(("max csm split num should lower than 4, %d is defined"):format(#SPLIT_RATIOS))
	end
else
	if nil == SPLIT_NUM then
		error "'split_ratios' or 'split_num' must be defined"
	end

	log.info("'split_ratios' is not define, use log split algrithom")
end

function ics.uniform()
	local positions = {1.0}
	for c=1, SPLIT_NUM-1 do
		positions[#positions+1] = c / SPLIT_NUM
	end
	return positions
end

local function log_split(num, c, n, f)
	local base = f/n
	local e =  c/num
	return ((n * (base ^ e))-n) / (f-n)
end

--near&far are view camera's  near & far
function ics.log(near, far)
	local positions = {1.0}
	for c=1, SPLIT_NUM-1 do
		positions[#positions+1] = log_split(c, near, far)
	end
	return positions
end

local function calc_split_positions(near, far)
	local positions = {1.0}
	local lambda = SPLIT_LAMADA
	for c=1, SPLIT_NUM-1 do
		local us = c / SPLIT_NUM
		local ls = log_split(SPLIT_NUM, c, near, far)
		positions[c] = lambda * ls + (1.0 - lambda) * us
	end
	return positions
end

local function split_positions_to_ratios(positions)
	local ratios = {}
	local start = 0.0
	for i=1, #positions do
		ratios[#ratios+1] = {start, positions[i]}
		start = positions[i]
	end

	return ratios
end

local function calc_viewspace_z(n, f, r)
	return n + (f-n) * r
end

local function create_sub_viewfrustum(zn, zf, sr, viewfrustum)
	return {
		n = calc_viewspace_z(zn, zf, sr[1]),
		f = calc_viewspace_z(zn, zf, sr[2]),
		fov = assert(viewfrustum.fov),
		aspect = assert(viewfrustum.aspect),
	}
end

function ics.split_viewfrustum(zn, zf, viewfrustum)
	local f = {}
	local ratios = SPLIT_RATIOS or split_positions_to_ratios(calc_split_positions(zn, zf))
	for _, r in ipairs(ratios) do
		f[#f+1] = create_sub_viewfrustum(zn, zf, r, viewfrustum)
	end

	return f
end

ics.split_num = SPLIT_NUM

return ics
