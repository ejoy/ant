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
	changes[raw.eid] = raw
	obj.__raw = raw
	return setmetatable(obj, raw)
end

local unmark = math3d.unmark
local marked_v = math3d.marked_vector
local marked_q = math3d.marked_quat
local yaw = { axis = mc.YAXIS }
local rad = math.rad

local coord_x = 0
local coord_y = 0

local function flush_scene(w)
	local dirty
	for eid in pairs(changes) do
		w:access(eid, "entity2d", true)
		dirty = true
	end
	
	if not dirty then
		return
	end
	
	for e in w:select "entity2d eid:in scene:update scene_needchange?out" do
		local obj = changes[e.eid]
		local srt = e.scene
		unmark(srt.r)
		unmark(srt.t)
		local scale = obj.s
		if scale then
			unmark(srt.s)
			srt.s = marked_v(scale, scale, scale)
		end
		srt.t = marked_v(obj.x - coord_x, obj.z or 0, - obj.y + coord_y)
		yaw.r = rad(obj.r or 0)
		srt.r = marked_q(yaw)
		obj.__newindex = touch
		e.scene_needchange = true
	end
	w:clear "entity2d"
	changes = {}
end

local material_changes = {}

local function material_touch(obj, k, v)
	local raw = obj.__raw
	material_changes[raw._list] = raw
	raw[k] = v
	obj.__newindex = raw
end

local function material_new(list)
	local raw = {
		_list = list,
		emissive = 0,
	}
	raw.__index = raw
	raw.__newindex = material_touch
	local obj = { __raw = raw }
	material_changes[raw._list] = raw
	return setmetatable(obj, raw)
end

local function material(world, list)
	local rlist = {}
	local n = 0
	for _, eid in ipairs(list) do
		 local e <close> = world:entity(eid, "filter_material?in")
		 -- find render objects
		 if e.filter_material then
			n = n + 1
			rlist[n] = eid
		 end
	end
	return material_new(rlist)
end

local function num2vec(v)
	if not v or v == 0 then
		return mc.ZERO
	else
		local a = (v >> 24 & 0xff)
		if a ==  0 then
			a = 1
		else
			a = a / 255
		end
		return math3d.vector((v >> 16 & 0xff) / 255, (v >> 8 & 0xff) / 255, (v & 0xff) / 255, a)
	end
end

local function flush_material(w)
	local dirty
	local cache = {}
	for list, obj in pairs(material_changes) do
		local d = {
			emissive = num2vec(obj.emissive),
			color = num2vec(obj.color),
			visible = obj.visible,
		}
		for i = 1, #list do
			local eid = list[i]
			w:access(eid, "entity2d", true)
			cache[eid] = d
		end
		obj.__newindex = material_touch
		dirty = true
	end
	
	if not dirty then
		return
	end
	
	for e in w:select "entity2d eid:in filter_material:in visible?out" do
		local obj = cache[e.eid]
		local fm = e.filter_material[0]	-- 0 is DEFAULT_MATERIAL_IDX
		fm.u_emissive_factor = obj.emissive
		fm.u_basecolor_factor = obj.color
		e.visible = obj.visible
	end
	w:clear "entity2d"
	material_changes = {}
end

local function flush(world)
	local w = world.w
	flush_scene(w)
	flush_material(w)
end

return {
	set_coord = function(x,y)
		coord_x, coord_y = x, y
	end,
	get_coord = function(x,y)
		return x + coord_x,  - y + coord_y
	end,
	new = new,
	flush = flush,
	material = material,
}
