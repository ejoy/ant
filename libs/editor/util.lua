local util = {}

function util.get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys, function (lhs, rhs) return tostring(lhs) > tostring(rhs) end)
	return keys
end


local counter = 0
function util.get_new_entity_counter()
	return counter + 1
end

function util.get_cursor_pos()
	local cursorpos = iup.GetGlobal("CURSORPOS")
	return cursorpos:match("(%d+)x(%d+)")
end

return util