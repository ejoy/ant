local point3d = {} point3d.__index = point3d
function point3d.new(x, y, z)
	return setmetatable({x=x, y=y, z=z}, point3d)
end

setmetatable(point3d, {__call = function (t, ...)return point3d.new(...) end})

function point3d:__add(rhs)
	return point3d(self.x + rhs.x, self.y + rhs.y, self.z + rhs.z)
end

function point3d:__sub(rhs)
	return point3d(self.x - rhs.x, self.y - rhs.y, self.z - rhs.z)
end

function point3d:__mul(factor)
	return point3d(self.x * factor, self.y * factor, self.z * factor)
end

local function threshold_value()
	return 1e-6
end

local function is_equal(n0, n1, threshold)
	local diff = n1 - n0
	threshold = threshold or threshold_value()
	return -threshold < diff or diff < threshold
end

function point3d:__eql(rhs)
	return is_equal(self.x, rhs.x) and is_equal(self.y, rhs.y) and is_equal(self.z, rhs.z)
end

function point3d:dot(rhs)
	return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z
end

function point3d:length()	
	local slen = self:slength()
	return math.sqrt(slen)
end

function point3d:slength()
	return self:dot(self)
end

local taabb = {} taabb.__index = taabb

function taabb.new(min, max)
	local t = setmetatable({min=point3d(0, 0, 0), max=point3d(0, 0, 0)}, taabb)
	t:merge_point(min)
	t:merge_point(max)

	return t
end

setmetatable(taabb, {__call = function (t, ...)return taabb.new(...) end})

function taabb:corners()
	local min, max = self.min, self.max
	local diff = max - min
	local accu = max + min
	local center = accu * 0.5
	local ext = diff * 0.5

	return {
		ltn = center + point3d(-ext.x, ext.y, -ext.z),
		rtn = center + point3d(ext.x, ext.y, -ext.z),
		ltf = center + point3d(-ext.x, ext.y, ext.z),
		rtf = max,

		lbn = min,
		rbn = center + point3d(ext.x, -ext.y, -ext.z),
		lbf = center + point3d(-ext.x, -ext.y, ext.z),
		rbf = center + point3d(ext.x, -ext.y, ext.z),
	}
end

function taabb:center()
	local min, max = self.min, self.max
	return (max - min) * 0.5
end

function taabb:diagonal_radius()
	local min, max = self.min, self.max
	local diff = max - min
	return diff:length() * 0.5
end

function taabb:isvalid()	
	return self.min ~= self.max
end

function taabb:length()	
	local min, max = self.min, self.max
	local len = max.x - min.x
	return len
end

function taabb:encapsulate(other)
	return self:contain_point(other.min) and self:contain_point(other.max)
end

function taabb:contain_point(pt)
	local min, max = self.min, self.max
	return 
		(min.x <= pt.x and pt.x <= max.x) and
		(min.y <= pt.y and pt.y <= max.y) and
		(min.z <= pt.z and pt.z <= max.z)
end

function taabb:merge_point(pt)
	local min, max = self.min, self.max
	self.min.x = math.min(pt.x, min.x)
	self.min.y = math.min(pt.y, min.y)
	self.min.z = math.min(pt.z, min.z)

	self.max.x = math.max(pt.x, max.x)
	self.max.y = math.max(pt.y, max.y)
	self.max.z = math.max(pt.z, max.z)
end

function taabb:merge(other)
	self:merge_point(other.min)
	self:merge_point(other.max)
end

local function split(aabb)
	local center = aabb:center()	
	local corners = aabb:corners()

	return {
		ltn = taabb.new(center, corners.ltn),
		rtn = taabb.new(center, corners.rtn),
		ltf = taabb.new(center, corners.ltf),
		rtf = taabb.new(center, corners.rtf),

		lbn = taabb.new(center, corners.lbn),
		rbn = taabb.new(center, corners.rbn),
		lbf = taabb.new(center, corners.lbf),
		rbf = taabb.new(center, corners.rbf),
	}
end

local ocnode = {} ocnode.__index = ocnode

function ocnode.new(aabb, maxobj, depth)
	return setmetatable({aabb=aabb, maxobj=maxobj, depth=depth or 1}, ocnode)
end

function ocnode:split()	
	local aabb = self.aabb
	local aabb_children = split(aabb)
	local children = {}
	for name, caabb in pairs(aabb_children) do
		children[name] = ocnode.new(caabb, self.maxobj, self.depth + 1)
	end
	return children
end

local function find_child_name(direction)
	local name = ((direction.x > 0) and "l" or "r")
	name = name .. ((direction.y > 0) and "b" or "t")
	name = name .. ((direction.z > 0) and "n" or "f")
	
	return name
end

function ocnode:add(obj, maxdepth)
	local aabb = self.aabb
	if not aabb:encapsulate(obj.aabb) then
		return false
	end

	if self.objs == nil then
		self.objs = {}
		table.insert(self.objs, obj)
	else
		local objs = self.objs
		local numobj = #objs
		assert(numobj >= 1)

		if numobj < self.maxobj or self.depth >= maxdepth then
			table.insert(objs, obj)
		else
			local function insert_tochild(obj)
				local direction = self.aabb:center() - obj.aabb:center()
				local cname = find_child_name(direction)
				local cnode = assert(self.childname[cname])
				return cnode:add(obj, maxdepth)				
			end

			if self.children == nil then
				self.children = self:split()
				for _, o in ipairs(objs) do					
					if insert_tochild(o) then
						table.remove(objs, o)
					end
				end
			end
	
			if not insert_tochild(obj) then
				table.insert(objs, obj)
			end
		end
	end

	return true
end

function ocnode:print(depth)
	local objs = self.objs
	local tabs = ""
	for _=1, depth do
		tabs = tabs .. "\t"
	end

	if objs then
		for _, obj in ipairs(objs) do
			print(tabs .. "name : ", obj.name, ", depth : ", depth)
		end
	end

	local children = self.children
	if children then
		for spacename, cnode in pairs(children) do
			if cnode.objs then
				print(tabs .. "spacename : ", spacename)
			end
			cnode:print(depth + 1)
		end
	end
end

local octree = {} octree.__index = octree

--[[
	rootaabb = all entity in world aabb merge together
	maxobj_pernode = per child node max object threshold, 
					if threshold is reach, will try to add child node and insert new object to child node
	maxdepth = max depth denote max tree hierarchy, if max depth is reach, no more hierarchy will spawn
	looseness = loose octree factor, if looseness = nil or 1, this octree is a normal octree, otherwise a loose octree
]]
function octree.new(rootaabb, maxobj_pernode, maxdepth, looseness)
	maxobj_pernode = maxobj_pernode or 3
	return setmetatable({
		rootnode = ocnode.new(rootaabb or taabb.new(point3d(0, 0, 0), point3d(0, 0, 0)), maxobj_pernode),
		maxobj_pernode = maxobj_pernode,
		maxdepth = maxdepth or 3,
		looseness = looseness or 1,
	}, octree)
end

function octree:add(obj)
	local rootnode = self.rootnode
	while not rootnode:add(obj, self.maxdepth) do
		local direction = obj.aabb:center() - rootnode.aabb:center()
		self:grow(direction)
		assert(rootnode ~= self.rootnode)
		rootnode = self.rootnode
	end
end

function octree:grow(direction)
	local oldroot = self.rootnode
	local aabb = oldroot.aabb
	local len = aabb:length()
	local center = aabb:center()
	local half_newlen = len

	local normalize_dir = point3d(direction.x > 0 and 1 or -1, direction.y > 0 and 1 or -1, direction.z > 0 and 1 or -1)

	local newcenter = center + normalize_dir * half_newlen

	local newaabb = taabb.new(	newcenter + point3d(-half_newlen, -half_newlen, -half_newlen), 
								newcenter + point3d(half_newlen, half_newlen, half_newlen))

	local newrootnode = ocnode.new(newaabb, self.maxobj, self.maxdepth)
	local children = newrootnode:split()

	if oldroot.children or (oldroot.objs and #oldroot.objs ~= 0) then
		local childname = find_child_name(direction)
		children[childname] = oldroot
		newrootnode.children = children
	end
	self.rootnode = newrootnode
end

function octree:print_scene()
	local rootnode = self.rootnode
	if rootnode then
		rootnode:print(1)
	end
end

function test()
	local objects = {
		{name="obj0", aabb=taabb.new(point3d(0, 0, 0), point3d(5, 5, 5))},
		{name="obj1", aabb=taabb.new(point3d(1, 1, 1), point3d(3, 3, 3))},
		{name="obj2", aabb=taabb.new(point3d(-1, 4, 5), point3d(1, 6, 9))},
	}

	local t = octree.new(objects[1].aabb)

	for _, o in ipairs(objects) do
		t:add(o)
	end

	t:print_scene()
end

test()
