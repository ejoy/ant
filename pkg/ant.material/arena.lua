local arena = require "render.material.arena"

local M = {}

M._arena = arena.arena()
M._name = {}
M.material = {}

function M.init(attrib)
	local lookup = {}
	local n = 1
	for k,v in pairs(attrib) do
		assert(type(k) == "string")
		lookup[k] = n
		arena.system_attrib(M._arena, n, v)
		n = n + 1
	end
	M._system = lookup
end

local _nameid = 1
local function nameid_gen(o, k)
	local id = M._name[k]
	if id == nil then
		id = _nameid
		_nameid = _nameid + 1
		M._name[k] = id
		assert(_nameid < 0x10000)
		o[k] = id
	end
	return id
end

local nameid = setmetatable({}, { __index = nameid_gen })

local function convert_system_id(system)
	local lut = assert(M._system)
	local r = {}
	for i, v in ipairs(system) do
		local id = lut[v]
		if not id then
			error ( tostring(v) .. " is not a system attrib" )
		end
		r[i] = id
	end
	return r
end

local function convert_attrib_id(attrib)
	local r = {}
	for k,v in pairs(attrib) do
		r[nameid[k]] = v
	end
	return r
end

function M.material_load(name, state, stencil, prog, system, attrib)
	assert(M.material[name] == nil)
	local m = arena.material(M._arena, state, stencil, prog
		, convert_system_id(system)
		, convert_attrib_id(attrib))
	M.material[name] = m
	return m
end

return M
