local util = {}

function util.get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys, function (lhs, rhs) return tostring(lhs) > tostring(rhs) end)
	return keys
end

function util.ordered_pairs(t)
	local keys = util.get_sort_keys(t)
	local function n(set, idx)
		idx = idx + 1
		local key = set[idx]
		return t[key]
	end
	
	return n, keys, 0
end


local counter = 0
function util.get_new_entity_counter()
	return counter + 1
end

function util.get_cursor_pos()
	local cursorpos = iup.GetGlobal("CURSORPOS")
	return cursorpos:match("(%d+)x(%d+)")
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