local adapter = {}; adapter.__index = adapter

local bindings = {}
local binded = {}

function adapter.bind(name, binding)
	assert(bindings[name] == nil, string.format("%s already binded", name))
	bindings[name] = assert(binding)
end

function adapter.bind_math_adapter()
	for k, b in pairs(bindings) do
		if binded[k] == nil then
			b()
			binded[k] = true
		end
	end

	bindings = {}
end

return adapter