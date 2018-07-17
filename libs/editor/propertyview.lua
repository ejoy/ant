local log = log and log(...) or print

require "iupluacontrols"
local eu = require "editor.util"

local treecontrol = require "editor.tree"
local mv_control = require "editor.matrixview"

local propertyview = {}; propertyview.__index = propertyview

local function create_tree_branch(node, parent, treeview)
	local ntype = type(node)
	if ntype ~= "table" then
		return
	end

	local keys = eu.get_sort_keys(node)

	for _, k in ipairs(keys) do
		local v = node[k]
		local child = treeview:add_child(parent, k)
		child.userdata = v
	end
end

function propertyview:build(properties, extend_trees)
	local treeview = self.tree
	treeview:clear()

	local function init_property_tree(properties, treeview, extend_trees)
		create_tree_branch(properties, nil, treeview)

		if extend_trees then
			local function create_branch(properties, etree, parentnode)
				for k, v in pairs(etree) do
					local property = properties[k]
					local childnode = treeview:findchild_byname(parentnode or treeview, k)
					create_tree_branch(property, childnode, treeview)					
					create_branch(property, v, childnode)
				end
			end
			create_branch(properties, extend_trees, nil)
		end
	end

	init_property_tree(properties, treeview, extend_trees)
	
	treeview:clear_selections()
end

local function fill_matrixview(detail, node)
	local nodevalue = node.userdata
	if nodevalue == nil then
		return 
	end

	local ridx = 1
	if type(nodevalue) == "table" then
		detail:setcell(0, 1, "key")
		detail:setcell(0, 2, "value")
		local keys = eu.get_sort_keys(nodevalue)
		for _, k in ipairs(keys) do
			local v = nodevalue[k]
			detail:setcell(ridx, 1, k)				
			if type(v) == "table" then
				detail:setuserdata(ridx, 2, {node=node, name=k})					
			end

			detail:setcell(ridx, 2, tostring(v) or "nil")
			ridx = ridx + 1
		end
		detail:fit_col_content_size(1)
		ridx = ridx - 1

		detail:shrink(ridx, nil)
		detail:fit_col_content_size(2, 10)
	else
		detail:setcell(0, 1, "value")
		detail:shrink(1, 1)
		detail:setcell(1, 1, tostring(nodevalue) or "nil")
		detail:fit_col_content_size(1, 10)
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
			tree:select_node(selectnode)

			fill_matrixview(self, selectnode)
		end
	end

	function detail:value_edit_cb(lin, col, newstring)
		local tree = self.tree
		
		local function get_ud()
			local selnode = tree:get_selected_node()
			local ud = selnode.userdata
			if ud then				
				if col == 1 then
					local parentnode = tree:parent_node(selnode.id)
					return parentnode.userdata, selnode.name
				end
				assert(col == 2)
				return ud, self:getcell(lin, col - 1)
			end

			local parentnode = tree:parent_node(selnode.id)
			return assert(parentnode.userdata), selnode.name
		end

		local ud, elemname = get_ud()

		if ud then
			local function check_name_is_number(t, name)
				if #t > 0 then
					local n = tonumber(name)
					if n then
						return n
					end
				end
				return name
			end

			elemname = check_name_is_number(ud, elemname)

			local nodevaluetype = type(assert(ud[tonumber(elemname) or elemname]))
			if nodevaluetype == "string" then
				ud[elemname] = newstring
			elseif nodevaluetype == "number" then
				ud[elemname] = tonumber(newstring)
			elseif nodevaluetype == "boolean" then
				local mm = {
					['true'] = true,
					['True'] = true,
					['TRUE'] = true,
					['false'] = false,
					['False'] = false,
					['FALSE'] = false,
				}
				local newvalue = mm[newstring]				
				ud[elemname] = newvalue or (tonumber(newstring) ~= 0)				
			else
				iup.Message("Warning", 
					string.format("only support modify string/number/boolean, current type is : ", nodevaluetype))
			end
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

