local tree = {}	; tree.__index = tree

local function new_item(name)
	return {
		parent = nil,
		name = name,
		id = nil,
	}
end

local function mapped(tree, node)
	if node == tree then
		return tree
	end
	local parent = node.parent
	if parent == nil then
		assert(node.view == nil)
		return false
	else
		return mapped(tree, parent)
	end
end

local function add_child(self, parent, child, n)
	local view = self.view
	n = n or #parent
	if n == 0 then
		-- no children
		local lastid = assert(parent.id)
		if view["KIND" .. lastid] == "LEAF" then
			-- change leaf to branch
			view["INSERTBRANCH" .. lastid] = parent.name
			view["DELNODE" .. lastid] = "SELECTED"
		end
		view["ADDLEAF" .. lastid] = child.name
		child.id = lastid + 1
	else
		local lastid = assert(parent[n].id)
		view["INSERTLEAF" .. lastid] = child.name
		child.id = view["NEXT" .. lastid]
	end

	child.parent = parent
	parent[n+1] = child
	for idx, c in ipairs(child) do
		add_child(self,child, c, idx-1)
	end
end

function tree:print()
	local count = self.view.COUNT
	local view = self.view
	for i=0, count-1 do
		local t = view["USERDATA" .. i]
		print(i, t.name, t.id)
	end
end

local function remap(view, root, id)
	for _,node in ipairs(root) do
		view["USERDATA" .. id] = node
		node.id = id
		id = id + 1
		for _, child in ipairs(node) do
			id = remap(view, node, id)
		end
	end
	return id
end

local function remap_tree(self)
	remap(self.view, self, 0)
end

function tree:add_child(parent, name)
	if name == nil then
		name = parent
		parent = self
	end
	local child = new_item(name)
	-- already map to tree
	if not mapped(self, parent) then
		table.insert(parent, child)
		child.parent = parent
	else
		add_child(self, parent, child, #parent)
		remap_tree(self)
	end
	return child
end

local function sibling_index(item)
	local parent = assert(item.parent)
	for idx, c in ipairs(parent) do
		if c == item then
			return idx
		end
	end
end

function tree:insert_sibling(sibling, name)
	local item = new_item(name)
	item.parent = sibling.parent
	local index = sibling_index(sibling)
	table.insert(sibling.parent, index , item)
	if mapped(self, sibling) then
		if index == 1 then
			-- first child
			self.view["ADDLEAF"..sibling.parent.id] = item.name
		else
			local insert_id = "INSERTLEAF" .. self.view["PREVIOUS" .. sibling.id]
			self.view[insert_id] = item.name
		end
		for _, c in ipairs(item) do
			add_child(self,item,c)
		end
		remap_tree(self)
	end
	return item
end

local function remove_item(item)
	local parent = assert(item.parent)
	item.parent = nil
	for idx, c in ipairs(parent) do
		if c == item then
			table.remove(parent, idx)
			return
		end
	end
end

function tree:del(item)
	local mapped = mapped(self, item)
	remove_item(item)
	if mapped then
		self.view["DELNODE" .. item.id] = "SELECTED"
		remap_tree(self)
	end
end

function tree.new()
	local view = iup.tree {
--		SHOWDRAGDROP = "yes",
--		SHOWRENAME = "yes",
		ADDROOT = "no",
	}

	return setmetatable({
		view = view,
		id = -1,
	}, tree)
end

return tree
