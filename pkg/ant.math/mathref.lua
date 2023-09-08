local math3d = require "math3d"

local ref = math3d.ref

local t = setmetatable({}, {__mode = "kv"})
local traceback = debug.traceback

function math3d.ref(...)
	local o = ref(...)
	t[o] = traceback()
	return o
end

function math3d.countref()
	local r = {}
	for k,v in pairs(t) do
		local n = r[v] or 0
		r[v] = n + 1
	end
	local list = {}
	local n = 1
	for k,v in pairs(r) do
		list[n] = string.format("%05d %s", v, k)
		n = n + 1
	end
	table.sort(list)
	return list
end

