local util = {}

function util.get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys, function (lhs, rhs) return tostring(lhs) > tostring(rhs) end)
	return keys
end

return util