local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid = 256

--1~99
local shadow_csm_start_viewid = 1
local bindings = {
	csm1 		= shadow_csm_start_viewid + 0,
	csm2 		= shadow_csm_start_viewid + 1,
	csm3 		= shadow_csm_start_viewid + 2,
	csm4 		= shadow_csm_start_viewid + 3,
	main_view 	= 30,
	pickup 		= 31,
	pickup_blit = 32,

	uiruntime	= max_viewid - 3,
	blit		= max_viewid - 2,
	uieditor	= max_viewid - 1,
}

local freeidx = 100

local function alloc_postprocess_viewids(num)
    local name = "postprocess"
	for i=1, num do
		local n = name .. i
		bindings[n] = freeidx
		freeidx = freeidx + 1
    end
end

alloc_postprocess_viewids(30)

local pool = {}
for _, v in pairs(bindings) do
	pool[v] = true
end

function viewid_pool.generate(name, afterviewid)
	if freeidx >= 256 then
		--to do, need release function for not used viewid to mark which view id released
		return error("not enougth view id to alloc")
	end

	local vid
	if afterviewid then
		vid = afterviewid + 1
		while viewid_pool.get(vid) ~= nil and vid < max_viewid do
			vid = vid + 1
		end
		if vid == max_viewid then
			error(string.format("want a viewid after:%d, but not enough viewid to alloc", afterviewid))
		end
	else
		vid = freeidx
		freeidx = freeidx + 1
	end

	viewid_pool.bind(name, vid)
	return vid
end

function viewid_pool.bind(name, viewid)
	if viewid < 0 or viewid > max_viewid then
		error("invalid viewid")
	end

	if pool[viewid] then
		error(string.format("viewid:%d have been used", viewid))
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