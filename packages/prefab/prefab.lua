local datalist = require "datalist"
local fs = require "filesystem"
local cr = import_package "ant.compile_resource"

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

local function command(w, set, name, ...)
	local iom = w:interface "ant.objcontroller|obj_motion"
	local iani = w:interface "ant.animation|animation"
	--assert(name == "play_animation")
	if name == "autoplay" then
		for _, eid in ipairs(set) do
			iani.play(eid, ...)
		end
	elseif name == "play" then
		for _, eid in ipairs(set) do
			iani.play(eid, ...)
			iani.pause(eid, true)
		end
	elseif name == "time" then
		for _, eid in ipairs(set) do
			iani.set_time(eid, ...)
		end
	elseif name == "duration" then
		for _, eid in ipairs(set) do
			return iani.get_duration(eid)
		end
	elseif name == "set_position" then
		for _, eid in ipairs(set) do
			iom.set_position(eid, ...)
		end
	elseif name == "set_rotation" then
		for _, eid in ipairs(set) do
			iom.set_rotation(eid, ...)
		end
	elseif name == "set_scale" then
		for _, eid in ipairs(set) do
			iom.set_scale(eid, ...)
		end
	elseif name == "get_position" then
		for _, eid in ipairs(set) do
			return iom.get_position(eid)
		end
	elseif name == "get_rotation" then
		for _, eid in ipairs(set) do
			return iom.get_rotation(eid)
		end
	elseif name == "get_scale" then
		for _, eid in ipairs(set) do
			return iom.get_scale(eid)
		end
	end
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
			assert(fs.loadfile(script, "t", env))(ant)
		end
	end
	return p
end

function world:prefab_event(prefab, name, ...)
	return prefab.event[name](...)
end

return world
