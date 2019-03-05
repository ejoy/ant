local util = {}; util.__index = util

local ms = import_package "ant.math" .stack

local handlers = {	
	parent = function (comp, value)
		comp.parent = value
	end,
	s = function (comp, value)
		ms(comp.s, value, "=")
	end,
	r = function (comp, value)
		ms(comp.r, value, "=")
	end,
	t = function (comp, value)
		ms(comp.t, value, "=")
	end,
	base = function (comp, value)
		ms(comp.base, value, "=")
	end,
}

function util.handle_transform(events, comp)
	for event, value in pairs(events) do
		local handler = handlers[event]
		if handler then
			handler(comp, value)
		else
			print('handler is not default in transform:', event)
		end
	end
end

return util