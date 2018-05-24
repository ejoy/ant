local log = log and log(...) or print

require "iupluacontrols"

local treecontrol = require "editor.tree"

local propertyview = {}; propertyview.__index = propertyview

function propertyview:build(htree)		
	local ptree = self.tree
	ptree:clear()

	for k, v in pairs(htree) do
		local child = ptree:add_child(k)
		child.userdata = v
	end

	ptree:clear_selections()
end

local function create_property_tree(config)
	local tree = treecontrol.new(config)	
	function tree:selection_cb(id, status)
		if status == 0 or self.detail == nil then
			return 
		end
	
		local node = self:find_node(id)
		local nodevalue = node.userdata
		if nodevalue then
			local ctype = type(nodevalue)
			local titleidx = 0
			local detail = self.detail.view
			if ctype == "table" then
				detail.NUMCOL = 2
				local numlin = 0
				for _ in pairs(nodevalue) do
					numlin = numlin + 1
				end

				detail.NUMLIN = numlin
				detail:setcell(titleidx, 1, "key")
				detail:setcell(titleidx, 2, "value")

				local ridx = 1
				for k, v in pairs(nodevalue) do								
					detail:setcell(ridx, 1, k)
					local c = type(v) == "table" and "...table..." or tostring(v)
					detail:setcell(ridx, 2, c)
					ridx = ridx + 1
				end
			else
				detail.NUMCOL = 1
				detail:setcell(titleidx, 1, "value")				
				
				detail:setcell(1, 1, tostring(nodevalue))
			end
		end
	end

	return tree
end

local function create_detailview(config)
	local param = {
		numcol=1, numlin=1,
		TITLE="Detail",
	}
	if config then
		for k, v in pairs(config) do
			param[k] = v
		end
	end

	local detail = {}
	detail.view = iup.matrix(param)
	
	function detail.view:click_cb(lin, col, status)
		
	end

	return detail
end

function propertyview.new(config)
	local detailview = create_detailview(config.detail)
	local tree = create_property_tree(config.tree)
	tree.detail = detailview

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

