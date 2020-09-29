local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid<const>				 = 256
local shadow_csm_start_viewid<const> = 1
local max_uieditor<const>			 = 32

local bindings = {
	csm1 		= shadow_csm_start_viewid + 0,
	csm2 		= shadow_csm_start_viewid + 1,
	csm3 		= shadow_csm_start_viewid + 2,
	csm4 		= shadow_csm_start_viewid + 3,
	depth		= 29,
	main_view 	= 30,
	pickup 		= 31,
	pickup_blit = 32,

	uiruntime	= max_viewid - max_uieditor - 3,
	blit		= max_viewid - max_uieditor - 2,

	uieditor	= max_viewid - max_uieditor - 1,
}

local pool = {}
for _, v in pairs(bindings) do
	pool[v] = true
end

local function find_valid_viewid(afterviewid)
	local vid = afterviewid+1
	while pool[vid] ~= nil and vid < max_viewid do
		vid = vid + 1
	end
	return vid < max_viewid and vid or nil
end

local function alloc_viewids(num, basename, afterviewid)
	local vids = {}
	local vid = afterviewid
	for i=1, num do
		vid = find_valid_viewid(vid)
		if vid then
			local n			= basename .. i
			bindings[n]		= vid
			pool[vid]		= true
			vids[#vids+1]	= vid
		else
			error("not enough viewid")
		end
	end

	return vids
end

alloc_viewids(30, "postprocess", 100)

viewid_pool.alloc_viewids = alloc_viewids

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