local viewid_pool = {}; viewid_pool.__index = viewid_pool

local max_viewid = 256

local bindings = {
	shadow_beg = 1,
	shadow1 = 1,
	shadow2 = 2,
	shadow3 = 3,
	shadow4 = 4,
	shadow_end = 4,

	main_view = 30,
	pickup = 31,
}

local pool = {}
for _, v in pairs(bindings) do
	pool[v] = true
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