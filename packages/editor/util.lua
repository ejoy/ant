--luacheck: globals
local util = {}

local counter = 0
function util.get_new_entity_counter()
	return counter + 1
end

function util.add_callbacks(ctrl, inst, funcs)
	for _, name in ipairs(funcs) do
		ctrl[name] = function (ih, ...)
			local cb = inst[name]
			if cb then
				cb(inst, ...)
			end
		end
	end
end
return util
