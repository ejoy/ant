local math3d = require "math3d"
local mathpkg   = import_package "ant.math"
local mc = mathpkg.constant

local changes = {}

local function touch(obj, k, v)
	local raw = obj.__raw
	changes[raw.eid] = raw
	raw[k] = v
	obj.__newindex = raw
end

local function new(obj)
	local raw = {}
	raw.__index = raw
	raw.__newindex = touch
	for k,v in pairs(obj) do
		raw[k] = v
		obj[k] = nil
	end
	changes[raw.eid] = obj
	obj.__raw = raw
	return setmetatable(obj, raw)
end

local unmark = math3d.unmark
local marked_v = math3d.marked_vector
local marked_q = math3d.marked_quat
local yaw = { axis = mc.YAXIS }
local rad = math.rad

local function flush(w)
	for eid in pairs(changes) do
		w:access(eid, "entity2d", true)
	end
	
	for e in w:select "entity2d eid:in scene:update scene_needchange?out" do
		local obj = changes[e.eid]
		local srt = e.scene
		unmark(srt.r)
		unmark(srt.t)
		srt.t = marked_v(obj.x, 0.5, obj.y)
		yaw.r = rad(obj.r)
		srt.r = marked_q(yaw)
		obj.__newindex = touch
		e.scene_needchange = true
	end
	w:clear "entity2d"
	changes = {}
end

return {
	new = new,
	flush = flush,
}
