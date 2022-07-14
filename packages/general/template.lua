local template = {}

local cache_meta = {}

local all = {}

function cache_meta:__index(k)
	local v = setmetatable({}, cache_meta)
	local keys = { table.unpack(all[self]) }
	keys[#keys+1] = k
	all[v] = keys
	self[k] = v
	return v
end

local root = setmetatable( {} , cache_meta )
all[root] = {}

template.keys = root

function template.format(fmt)
	return template.new(function(...) return string.format(fmt, ...) end)
end

function template.new(func)
	local meta = {}
	function meta:__index(keys)
		local s
		if type(keys) == "string" then
			s = func(keys)
		else
			s = func(table.unpack(all[keys]))
		end
		self[keys] = s
		return s
	end
	return setmetatable({}, meta)
end

return template

--[[

local template = require "template"
local keys = template.keys

local t = template.format "view_visible %s %s:absent render_object:in filter_material:in"
local t2 = template.format "view_visible %s:absent render_object:in filter_material:in"

assert(t[keys.a.b] == "view_visible a b:absent render_object:in filter_material:in")
assert(t2.xxx == "view_visible xxx:absent render_object:in filter_material:in")

]]
