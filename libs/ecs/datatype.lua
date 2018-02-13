local math3d = require "math3d"

local available_type = {
	integer = 0,
	float = 0.0,
	boolean = false,
	string = "",
	entity = 0,	-- entity id
	asset = "", -- asset file path
	userdata = function() return {} end,
	vector = function() return math3d.ref "vector" end,
	matrix = function() return math3d.ref "matrix" end,
}

return function (t)
	for k,v in pairs(t) do
		assert(type(k) == "string", "Property name should be string")
		local ttype = type(v)
		if ttype == "table" then
			local default = available_type[v.type]
			assert(default ~= nil, "Invalid type")
			if v.default == nil then
				v.default = default
			end
		else
			local typename
			if ttype == "number" then
				typename = math.type(v)
			else
				assert(available_type[ttype] ~= nil)
				typename = ttype
			end
			v = { type = typename, default = v }
			t[k] = v
		end
		ttype = type(v.default)
		if ttype == "function" then
			v.default_func = v.default
			v.default = nil
		elseif ttype == "table" then
			local defobj = v.default
			for k,v in pairs(defobj) do
				assert(type(k) ~= "table" and type(v) ~= "table")
			end
			v.default = nil
			v.default_func = function()
				local ret = {}
				-- deepcopy default object
				for k,v in pairs(defobj) do
					ret[k] = v
				end
				return ret
			end
		end
	end
	return t
end
