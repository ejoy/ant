local antfw = {}

local preinit = {}

function antfw.init_all()
	for _, f in ipairs(preinit) do
		f()
	end
	preinit = nil
end

local action = {}

setmetatable(antfw, {
	__newindex = function(_,k,v)
		local a = assert(action[k])
		a(v)
	end
})

function action.init(f)
	if preinit then
		table.insert(preinit, f)
	else
		f()
	end
end

return antfw
