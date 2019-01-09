-- luacheck: globals log
local log = log and log(...) or print

local treecontrol = require "controls.tree"

local hierarchyview = treecontrol.new {
	HIDEBUTTONS ="YES",
	HIDELINES   ="YES",	
	IMAGELEAF	="IMGLEAF",
	IMAGEBRANCHCOLLAPSED = "IMGLEAF",
	IMAGEBRANCHEXPANDED = "IMGLEAF"
}

local function ordered_pairs(t)
	local sort = {}
	for k in pairs(t) do
		sort[#sort+1] = k
	end
	table.sort(sort)
	local n = 1
	return function ()
		local k = sort[n]
		if k == nil then
			return
		end
		n = n + 1
		return k, t[k]
	end
end

function hierarchyview:build(htree, ud_table)		
	local function constrouct_treeview(tr, parent)
		for k, v in ordered_pairs(tr) do			
			local ktype = type(k)
			if ktype == "string" or ktype == "number" then
				local vtype = type(v)
				local function add_child(parent, name)
					local child = self:add_child(parent, name)
					local eid = assert(ud_table[name])
					child.eid = eid					
					return child
				end
				
				if vtype == "table" then
					local child = add_child(parent, k)
					constrouct_treeview(v, child)
				elseif vtype == "string" then
					add_child(parent, v)
				end
			else
				log("not support ktype : ", ktype)
			end
	
		end
	end

	self:clear()
	constrouct_treeview(htree, nil)	
	self:clear_selections()
end

function hierarchyview:select_nodename()
	return self.view["TITLE"]
end

return hierarchyview