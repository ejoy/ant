local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid = 256

--1~99
local shadow_csm_start_viewid = 1
local bindings = {
	csm1 = shadow_csm_start_viewid + 0,
	csm2 = shadow_csm_start_viewid + 1,
	csm3 = shadow_csm_start_viewid + 2,
	csm4 = shadow_csm_start_viewid + 3,
	main_view = 30,
	pickup = 31,
	pickup_blit = 32
}
local freeidx = 100

local pool = {}
for _, v in pairs(bindings) do
	pool[v] = true
end


function viewid_pool.generate(name)
	if freeidx >= 256 then
		--to do, need release function for not used viewid to mark which view id released
		return error("not enougth view id to alloc")
	end

	local vid = freeidx
	freeidx = freeidx + 1

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