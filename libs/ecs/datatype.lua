local math3d = require "math3d"

local function math3d_value_save(v, arg)
	assert(type(v) == "userdata")
	local ms = arg.math_stack
	local t = ms(v, "T")
	assert(type(t) == "table" and t.type ~= nil)
	return t
end

local function get_math3d_value_load(typename)
	return function(s, arg)
		if s.type == nil then
			error "vector load function invalid format"
		end

		if s.type ~= 1 and s.type ~= 2 then
			error "vector load function need vector type"
		end


		local v = math3d.ref(typename)
		local ms = arg.math_stack
		ms(v, s, "=")
		return v
	end
end

local function empty_func() 
	assert(false) 
	return nil 
end

local function default_save(v) return v end
local function default_load(v) return v end

local available_type = {
	integer = {default = 0,},
	float 	= {default = 0.0,},
	boolean = {default = false,},
	string 	= {default = ""},				
	entity 	= {default = 0},	-- entity id
	asset 	= {default = "", save = default_save, load = default_load}, -- asset file path
	userdata = { default = function() return {} end,
				save = empty_func,
				load = empty_func,},
	vector = { default = function() return math3d.ref "vector" end,
				save = math3d_value_save,
				load = get_math3d_value_load("vector"), },
	matrix = { default = function() return math3d.ref "matrix" end,
				save = math3d_value_save,
				load = get_math3d_value_load("matrix"), },
}

local function gen_value(v)
	local ttype = type(v)
	local typename = nil
	local default = nil
	local save = nil
	local load = nil
	
	if ttype == "table" then
		typename = v.type
		default = v.default
		save = v.save
		load = v.load
	else
		typename = ttype == "number" and math.type(v) or ttype				
		default = v
		save = default_save
		load = default_load
	end

	local default_value = available_type[typename]
	assert(default_value ~= nil, "Invaild type!")

	return { 
		type 	= typename, 
		default = default and default or default_value.default, 
		save 	= save and save or default_value.save,
		load 	= load and load or default_value.load,
	}	
end

return function (t)
	for k,v in pairs(t) do
		assert(type(k) == "string", "Property name should be string")
		v = gen_value(v)
		t[k] = v

		local ttype = type(v.default)
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
