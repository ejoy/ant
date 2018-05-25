local log = log and log(...) or print

require "iupluacontrols"

local treecontrol = require "editor.tree"
local mv_control = require "editor.matrixview"

local propertyview = {}; propertyview.__index = propertyview

local function create_tree_branch(node, parent, ptree)
	local ntype = type(node)
	if ntype ~= "table" then
		return
	end

	for k, v in pairs(node) do
		local child = ptree:add_child(parent, k)
		child.userdata = v
	end
end

function propertyview:build(htree)
	local ptree = self.tree
	ptree:clear()

	create_tree_branch(htree, nil, ptree)
	ptree:clear_selections()
end

local function fill_matrixview(detail, node)
	local nodevalue = node.userdata
	if nodevalue then
		local ctype = type(nodevalue)
		local titleidx = 0		
		if ctype == "table" then
			local numlin = 0
			for _ in pairs(nodevalue) do
				numlin = numlin + 1
			end

			detail:resize(2, numlin)
			
			detail:setcell(titleidx, 1, "key")
			detail:setcell(titleidx, 2, "value")

			local ridx = 1
			for k, v in pairs(nodevalue) do								
				detail:setcell(ridx, 1, k)
				local vtype = type(v)
				if vtype == "table" then
					detail:setuserdata(ridx, 2, {node=node, name=k})					
					detail:setcell(ridx, 2, "...table...")					
				else
					detail:setcell(ridx, 2, tostring(v))					
				end
				ridx = ridx + 1
			end
		else
			detail.NUMCOL = 1
			detail:setcell(titleidx, 1, "value")				
			
			detail:setcell(1, 1, tostring(nodevalue))
		end
	end
end


local function create_property_tree(config)
	local tree = treecontrol.new(config)	
	function tree:selection_cb(id, status)
		if status == 0 or self.detail == nil then
			return 
		end
	
		local node = self:findchild_byid(id)
		fill_matrixview(self.detail, node)
	end

	function tree:executeleaf_cb(id)
		local child = self:findchild_byid(id)
		local nodevalue = child.userdata
		if nodevalue then
			tree.view.ADDEXPANDED = "YES"
			create_tree_branch(nodevalue, child, self)
		end
	end

	return tree
end

local function create_detailview(config)
	local detail = mv_control.new(config)

	function detail:click_cb(lin, col, status)			
		local isleftbtn = status:sub(3, 3) == '1'
		local isdbclick = status:sub(6, 6) == 'D'

		if not isleftbtn or not isdbclick then
			return 
		end
		
		local tree = self.tree
		if tree == nil then
			return 
		end

		local ud = self:getuserdata(lin, col)
		if ud then
			local node = ud.node
			if not tree:isbranch(node) then
				create_tree_branch(node.userdata, node, tree)
			end

			tree:clear_selections()
			local selectnode = tree:findchild_byname(node, ud.name)
			tree:selection_node(selectnode)

			fill_matrixview(self, selectnode)
		end
	end

	return detail
end

function propertyview.new(config)
	local detailview = create_detailview(config.detail)
	local tree = create_property_tree(config.tree)
	tree.detail = detailview
	detailview.tree = tree

	local tabs = iup.tabs {
		detailview.view,
	}

	tabs.TABTITLE0 = "Detail"

	local window = iup.split {
		tree.view,
		tabs,
	}

	return setmetatable(
		{
			window=window,
			tree=tree,
			detail=detailview
		}, 
		propertyview
	)
	
end

return propertyview

