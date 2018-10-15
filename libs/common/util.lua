local util = {}; util.__index = util

function util.deep_copy(t)
	if type(t) == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = type(v) == "table" and util.deep_copy(v) or v		
		end
		return tmp
	end

	return t
end

function util.get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys, function (lhs, rhs) return tostring(lhs) < tostring(rhs) end)
	return keys
end

function util.ordered_pairs(t)
	local keys = util.get_sort_keys(t)
	local idx = 0
	local function n(set)
		idx = idx + 1
		if idx <= #set then
			local key = set[idx]
			return key, t[key]
		end		
	end
	
	return n, keys, 0
end

return util