local adapter = {}; adapter.__index = adapter

local bindings = {}

function adapter.bind(name, binding)
	if not bindings[name] then
		binding()
		bindings[name] = true
	end
end

return adapter