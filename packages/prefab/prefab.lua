
local ecs = ...
local iom 	= ecs.import.interface "ant.objcontroller|obj_motion"
local iani 	= ecs.import.interface "ant.animation|animation"
local ieff 	= ecs.import.interface "ant.effekseer|effekseer_playback"
local iss 	= ecs.import.interface "ant.scene|iscenespace"
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
	local findAnimation = function(eid)
		for e in w:select "eid:in" do
			if e.eid == eid then
				w.w:sync("animation:in", e)
				return e.animation
			end
		end
	end
	local findAnimClips = function(eid)
		for e in w:select "eid:in" do
			if e.eid == eid then
				w.w:sync("anim_clips:in", e)
				return e.anim_clips
			end
		end
	end
	local do_remove_all
	do_remove_all = function(eid)
		if type(eid) == "table" then
			for _, e in ipairs(eid) do
				do_remove_all(e)
			end
		else
			w:remove_entity(eid)
		end
	end
	if not cmd_handle then
		cmd_handle = {
			get_eid = function(eid)
				return eid
			end,
			link = function(eid, ceid)
				w[ceid].parent = eid
			end,
			set_parent = function(eid, peid)
				--w[eid].parent = peid
				iss.set_parent(eid, peid)
			end,
			get_parent = function(eid)
				return w[eid].parent
			end,
			play_effect = function(eid, loop, manual)
				if w[eid].effekseer then
					ieff.play(eid, loop or false)
					ieff.pause(eid, manual or false)
				end
			end,
			play_anim = function(eid, anim_state)
				if w[eid].eid then
					iani.play(eid, anim_state)
				else
					w:pub {"AnimationEvent", "play", eid, anim_state}
				end
			end,
			play_clip = function(eid, anim_state)
				if w[eid].eid then
					iani.play_clip(eid, anim_state)
				else
					w:pub {"AnimationEvent", "play_clip", eid, anim_state}
				end
			end,
			play_group = function(eid, anim_state)
				if w[eid].eid then
					iani.play_group(eid, anim_state)
				else
					w:pub {"AnimationEvent", "play_group", eid, anim_state}
				end
			end,
			stop = function(eid, name)
				if w[eid].effekseer then
					ieff.stop(eid)
				end
			end,
			speed = function(eid, ...)
				if w[eid].effekseer then
					ieff.set_speed(eid, ...)
				else
					iani.set_speed(eid, ...)
				end
			end,
			get_time = iani.get_time,
			step = function(eid, ...)
				if w[eid].eid then
					for e in w.w:select "eid:in" do
						if e.eid == eid then
							w.w:sync("_animation:in", e)
							iani.step(e._animation._current, ...)
						end
					end
				else
					w:pub {"AnimationEvent", "step", eid, ...}
				end
			end,
			time = function(eid, ...)
				if w[eid].effekseer then
					ieff.set_time(eid, ...)
				else
					if w[eid].eid then
						iani.set_time(eid, ...)
					else
						w:pub {"AnimationEvent", "set_time", eid, ...}
					end
				end
			end,
			clip_time = function(eid, ...)
				if w[eid].effekseer then
					--ieff.set_time(eid, ...)
				else
					iani.set_clip_time(eid, ...)
				end
			end,
			group_time = function(eid, ...)
				if w[eid].effekseer then
					--ieff.set_time(eid, ...)
				else
					iani.set_group_time(eid, ...)
				end
			end,
			set_clips 		= iani.set_clips,
			get_clips		= iani.get_clips,
			get_collider    = iani.get_collider,
			duration = function(eid, ...)
				return iani.get_duration(eid)
			end,
			clip_duration = function(eid, ...)
				return iani.get_clip_duration(eid, ...)
			end,
			group_duration = function(eid, ...)
				return iani.get_group_duration(eid, ...)
			end,
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
			get_scale 		= iom.get_scale,
			remove_all		= do_remove_all
		}
	end
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
		end
		table.insert(dict['*'], eid)
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
	--load clips
	local clips_filename = string.sub(filename, 1, -8) .. ".clips";
	if fs.exists(fs.path(clips_filename)) then
		local path = fs.path(clips_filename)
		local f = assert(fs.open(path))
		local data = f:read "a"
		f:close()
		--self:prefab_event(p, "set_clips", "*", datalist.parse(data))
		self:pub {"SetClipsEvent", p, "*", datalist.parse(data)}
	end
	return p
end

function world:prefab_event(prefab, name, ...)
	return prefab.event[name](...)
end

return world
