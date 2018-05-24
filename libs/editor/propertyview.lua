local log = log and log(...) or print


local propertyview = {}

require "iupluacontrols"
local eu = require "editor.util"
local treecontrol = require "editor.tree"

local propertytree = treecontrol.new()
propertytree.view.title = "Entity"
propertytree.view.expand = "YES"
propertytree.view.hidebuttons = "NO"



local property_detail = iup.matrixex {
	numcol=2, 
	numlin=2,
}


function property_detail:click_cb(lin, col, status)
	
end

local propterty_displaytabs = iup.tabs {
	property_detail,
}

propertyview.window = iup.split {
	propertytree.view,
    propterty_displaytabs,
}

function propertytree.view:selection_cb(id, status)
	if status == 0 then
		return 
	end
	
	local node = propertytree:find_node(id)
	local nodecontent = node.userdata
	if nodecontent then
		local ctype = type(nodecontent)
		local titleidx = 0
		if ctype == "table" then			
			property_detail:setcell(titleidx, 1, "key")
			property_detail:setcell(titleidx, 2, "value")

			local row_idx = 1
			for k, v in pairs(nodecontent) do			
				property_detail:setcell(row_idx, 1, k)
				local c = type(v) == "table" and "...table..." or tostring(v)
				property_detail:setcell(row_idx, 2, c)
				row_idx = row_idx + 1
			end
		else
			property_detail:setcell(titleidx, 1, "value")
			property_detail:setcell(titleidx, 2, nil)

			--local titlename = self["title" .. id]
			property_detail:setcell(1, 1, tostring(nodecontent))
		end

	end
end

function propertyview:build(htree)	
	self.origin_data = htree
	for k, v in pairs(htree) do
		local child = propertytree:add_child(k)
		child.userdata = v
	end
end


return propertyview

