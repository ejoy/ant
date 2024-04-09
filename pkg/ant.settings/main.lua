local fs = require "filesystem"
local serialize = import_package "ant.serialize"

local function split(s)
	local r = {}
	s:match "^/?(.-)/?$":gsub('[^/]*', function (w) r[#r+1] = w end)
	return r
end

local function get_internal(t, sp, n)
	if n >= #sp then
		return t
	end
	local node = t[sp[n]]
	if type(node) ~= 'table' then
		return
	end
	return get_internal(node, sp, n+1)
end

local function merge(root, tbl)
	for k,v in pairs(tbl) do
		if root[k] == nil then
			root[k] = v
		else
			local oldv = root[k]
			if type(v) == "table" then
				assert(type(oldv) == "table")
				merge(oldv, v)
			else
				assert(type(oldv) ~= "table")
			end
		end
	end
end

local function create(paths)
	local root = {}
	for _, path in ipairs(paths) do
		if fs.exists(path) then
			merge(root, assert(serialize.load(path)))
		end
	end
	local obj = {}
	function obj:get(key)
		local sp = split(key)
		local t = get_internal(root, sp, 1)
		if t then
			local k = sp[#sp]
			return t[k]
		end
	end
	return obj
end

return create {
	"/settings.ant",
	"/graphic_settings.ant",
	"/pkg/ant.settings/default/graphic_settings.ant",
	"/pkg/ant.settings/default/general_settings.ant",
}
