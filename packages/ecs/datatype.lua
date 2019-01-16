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
}

local function gen_value(v)
	local ttype = type(v)
	local typename = nil
	local default = nil
	local save = nil
	local load = nil

	local function get_default_type(default)			
		if default ~= nil then
			local tt = type(default)
			if tt == "number" then
				return math.type(default)
			end
			return tt
		end

		error("need define type or set default value")
	end
	
	if ttype == "table" then
		typename = v.type or get_default_type(v.default)
		default = v.default
		save = v.save
		load = v.load
	else
		typename = get_default_type(v)
		default = v
		save = default_save
		load = default_load
	end

	local default_value = available_type[typename]
	assert(default_value ~= nil, string.format("Invaild type! typename : %s", typename))

	return { 
		type 	= typename, 
		default = default or default_value.default, 
		save 	= save or default_value.save,
		load 	= load or default_value.load,
	}	
end

local function gen_default(v)
	local ttype = type(v.default)
	if ttype == "function" then
		v.default_func = v.default
		v.default = nil
	elseif ttype == "table" then
		local defobj = v.default
		local function check_defobj(defobj)
			for k,v in pairs(defobj) do
				if type(v) == "table" then
					check_defobj(v)
				end
				assert(type(k) ~= "table")
			end
		end
		check_defobj(defobj)

		local function deep_copy(obj)
			local t = {}
			for k, v in pairs(obj) do
				if type(v) == "table" then
					local tt = deep_copy(v)
					t[k] = tt
				else
					t[k] = v
				end
			end
			return t
		end

		v.default = nil
		v.default_func = function()
			return deep_copy(defobj)
		end
	end
end

return function (c)
	local t = c.typeinfo
	if t.struct then
		t = t.struct
		for k,v in pairs(t) do
			assert(type(k) == "string", "Property name should be string")
			v = gen_value(v)
			t[k] = v
			gen_default(v)
		end
	else
		t = gen_value(t)
		c.typeinfo = t
		gen_default(t)
	end
	return t
end
