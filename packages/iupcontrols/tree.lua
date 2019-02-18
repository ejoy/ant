
local ctrlutil = require "util"

require "iuplua"

local tree = {}	; tree.__index = tree

local function new_item(name,tree_view)
	return setmetatable(
		{
			parent = nil,
			name = name,
		},{
			__index = function(tb,key)
				if key == "id" then
					return tree_view:GetId(tb)
				end
			end
		}
	)
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
		local kind = view["KIND" .. lastid]
		if kind == "LEAF" then
			-- change leaf to branch
			view["INSERTBRANCH" .. lastid] = parent.name
			view["DELNODE" .. lastid] = "SELECTED"
			view:SetUserId(lastid ,parent)
		end
		view["ADDLEAF" .. lastid] = child.name
		view:SetUserId(lastid + 1,child)
	else
		local last_node = parent[n]
		local lastid = assert(last_node.id)		
		view["INSERTLEAF" .. lastid] = child.name
		view:SetUserId(view["NEXT" .. (lastid or 0 )],child)

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

function tree:findchild_byid(ctrlid)
	if ctrlid == self.id then
		return self
	else
		local child = self.view:GetUserId(ctrlid)
		return child
	end
end

function tree:isbranch(node)
	local id = node.id
	local kind = self.view["KIND" .. id]
	return kind:upper() == "BRANCH"
end

function tree:findchild_byname(parent, name)
	for _, n in ipairs(parent) do
		if n.name == name then
			return n
		end
	end

	return nil
end

function tree:add_child(parent, name)	
	if parent == nil then
		parent = self
	end
	if name == nil then   
		name = parent
		parent = self
	end

	local child = new_item(name,self.view)
	-- already map to tree
	if not mapped(self, parent) then
		table.insert(parent, child)
		child.parent = parent
	else
		add_child(self, parent, child, #parent)

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
	local item = new_item(name,self.view)
	item.parent = sibling.parent
	local index = sibling_index(sibling)
	table.insert(sibling.parent, index , item)
	if mapped(self, sibling) then
		if index == 1 then
			-- first child
			self.view["ADDLEAF"..sibling.parent.id] = item.name
			self.view:SetUserId(sibling.id-1,item)
		else
			local insert_id = "INSERTLEAF" .. self.view["PREVIOUS" .. sibling.id]
			self.view[insert_id] = item.name
			self.view:SetUserId(sibling.id-1,item)

		end
		---why a new item has children?
		for _, c in ipairs(item) do
			add_child(self,item,c)
		end
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

function tree:del_id(id)
	local node = self:findchild_byid(id)
	if node then
		return self:del(node)
	end
end

function tree:del(item)
	local mapped = mapped(self, item)
	remove_item(item)
	if mapped then
		self.view["DELNODE" .. item.id] = "SELECTED"
	end
end

function tree:remove_child(item)
	local temp = {}
	for _,n in ipairs(item) do
		table.insert(temp,n)
	end
	for _,child in ipairs(temp) do
		self:del(child)
	end
end

function tree:clear()
	self.view.DELNODE0 = "ALL"
	
	local count = #self
	for i=1, count do
		self[i] = nil
	end
end

function tree:clear_selections()
	local view = self.view
	if view.MARKMODE == "MULTIPLE" then
		view.MARK = "CLEARALL"
	else
		view.VALUE = "CLEAR"
	end
end

function tree:select_node(node)
	local id = node.id
	local view = self.view	
	view["MARKED" .. id] = "YES"
end

function tree:get_selected_node()
	local view = self.view
	local id = view["VALUE"]
	if id then
		return self:findchild_byid(tonumber(id))
	end

	return nil
end

function tree:node_name(id)
	local view = self.view
	return view["TITLE" .. id]
end

function tree:parent(id)
	local view = self.view
	return view["PARENT" .. id]
end

function tree:parent_node(id)
	local pid = assert(tonumber(self:parent(id)))
	return self:findchild_byid(pid)
end

local function create_view(config)
	local param = {ADDROOT = "NO"}
	if config then
		for k, v in pairs(config) do
			param[k] = v
		end
	end
	return iup.tree(param)	
end

function tree.new(config)
	local c = ctrlutil.create_ctrl_wrapper(function ()
		return create_view(config)
	end, tree)

	c.id = -1	
	return c
end

return tree
