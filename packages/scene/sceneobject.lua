local ecs = ...
local world = ecs.world

local all_objects = {}

local object = {}
object.__index = object

function object:__tostring()
	local eid = self.eid
	local name
	if eid == 0 then
		name = "ROOT"
	elseif eid then
		name = tostring(eid)
	else
		name = "INVALID"
	end

	return "[Scene:" .. name .. "]"
end

local function create_object(eid, parent)
	return {
		parent = parent,
		eid = eid,
		children = {},
	}
end

function object:create(eid)
	assert(all_objects[eid] == nil)
	local obj = setmetatable(create_object(eid, self), object)
	world:pub { "component_changed", "parent", eid }
	table.insert(self.children, obj)
	all_objects[eid] = obj
	return obj
end

local function remove_from_parent(parent, obj)
	for idx, child in ipairs(parent.children) do
		if child == obj then
			table.remove(parent.children, idx)
			return
		end
	end
	error "Not found in parent's children"
end

function object:mount(parent)
	remove_from_parent(parent, self)
	self.parent = parent
	table.insert(parent.children, self)
	world:pub { "component_changed" , "parent" , self.id }
end

function object:remove()
	remove_from_parent(parent, self)
	self.parent = nil
	world:pub { "scene_removed", self.eid }
end

----- define interface sceneobject
local m = ecs.interface "sceneobject"
local ROOT = create_object(0, nil)

function m.root()
	return ROOT
end

-- call by message "scene_removed"
local remove_mb = world:sub { "scene_removed" }
function m.clear()
	for _, eid in remove_mb:unpack() do
		all_objects[eid] = nil
	end
end

function m.find_object(eid)
	return all_objects[eid]
end
