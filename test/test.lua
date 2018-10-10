local function data_extractor(part)
	local type_mapper = {
		f = "f", u = "I1",
		S = "i2",
	}
	local fmt = type_mapper[part.elem_type]
	for i=2, part.elem_count do
		fmt = fmt .. fmt
	end
	
	local offset = 0
	return function()		
		offset = 1
		
		return 
	end
end

local func = upvalue_func()
local dd = func()

local func1 = upvalue_func()
local dd1 = func1()


local function get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys, function (lhs, rhs) return tostring(lhs) < tostring(rhs) end)
	return keys
end

local function ordered_pairs(t)
	local keys = get_sort_keys(t)
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




local tt = {
	kit = "chen",
	xin = "ying",
}

for k, v in ordered_pairs(tt) do
	print(k, v)
end


