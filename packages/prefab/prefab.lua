local datalist = require "datalist"
local fs = require "filesystem"
local cr = import_package "ant.compile_resource"
local math3d = require "math3d"

local world = {}

function world:init()
	self.prefab_instance = world.prefab_instance
	self.prefab_event = world.prefab_event
end

local function getTemplate(filename)
	return datalist.parse(cr.read_file(filename))
end

local function absolutePath(path, base)
	return fs.absolute(fs.path(path), fs.path(base):remove_filename())
end

local cmd_handle

local function command(w, set, name, ...)
	local iom = w:interface "ant.objcontroller|obj_motion"
	local iani = w:interface "ant.animation|animation"
	
	if not cmd_handle then
		cmd_handle = {
			autoplay = iani.play,
			play = function(eid, ...)
				local ieff = w:interface "ant.effekseer|effekseer_playback"
				if w[eid].effekseer then
					ieff.play(eid, ...)
				else
					iani.play(eid, ...)
					iani.pause(eid, true)
				end
			end,
			time 			= iani.set_time,
			set_clips 		= iani.set_clips,
			set_events 		= iani.set_events,
			get_collider    = iani.get_collider,
			duration 		= iani.get_duration,
			set_position 	= iom.set_position,
			set_rotation 	= function(eid, r)
				iom.set_rotation(eid, math3d.quaternion{math.rad(r[1]), math.rad(r[2]), math.rad(r[3])})
			end,
			set_scale 		= iom.set_scale,
			get_position 	= iom.get_position,
			get_rotation 	= function(eid)
				local quat = iom.get_rotation(eid)
				local rad = math3d.totable(math3d.quat2euler(quat))
				return { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
			end,
			get_scale 		= iom.get_scale
		}
	end
	--assert(name == "play_animation")
	local ret
	for _, eid in ipairs(set) do
		if cmd_handle[name] then
			ret = cmd_handle[name](eid, ...)
		else
			print("can't find command handle : ", name)
		end
	end
	return ret
end

local function createProxy(w, set)
	return setmetatable({}, {__index=function (self, name)
		local f = function (_,...) return command(w, set, name, ...) end
		self[name] = f
		return f
	end})
end

local function createEmptyProxy()
	local function f() end
	return setmetatable({}, {__index=function ()
		return f
	end})
end

local function addTag(dict, tag, eid)
	if dict[tag] then
		table.insert(dict[tag], eid)
	else
		dict[tag] = {eid}
	end
end

local function createTagDictionary(w, prefab)
	local dict = {['*']={}}
	for _, eid in ipairs(prefab) do
		if type(eid) == "number" then
			local entity = w[eid]
			local tag = entity.tag
			if tag then
				if type(tag) == "table" then
					for _, tag_ in ipairs(tag) do
						addTag(dict, tag_, eid)
					end
				else
					addTag(dict, tag, eid)
				end
			end
			table.insert(dict['*'], eid)
		end
	end
	local proxy = {}
	for k, v in pairs(dict) do
		proxy[k] = createProxy(w, v)
	end
	local empty = createEmptyProxy()
	return setmetatable(proxy, {__index=function (self, v)
		self[v] = empty
		return empty
	end})
end

function world:prefab_instance(filename)
	local prefab = self:instance(filename)
	local w = self
	local p = {event={}}
	local dict = createTagDictionary(w, prefab)
	local env = {}
	local ant = {
		event = p.event,
		tag = function (v)
			return dict[v]
		end
	}
	for _, v in ipairs(getTemplate(filename)) do
		if v.script then
			local script = absolutePath(v.script, filename)
			assert(fs.loadfile(script, "bt", env))(ant)
		end
	end
	return p
end

function world:prefab_event(prefab, name, ...)
	return prefab.event[name](...)
end

return world
