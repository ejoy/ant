local log = log and log(...) or print

local hierarchyview = {}

hierarchyview.window = iup.tree {
    hidebuttons ="YES",
    hidelines   ="YES",
    title = "World",
}

function hierarchyview.window:selection_cb(id, status)
    
end

function hierarchyview:build(htree)
	local function build_hierarchy_view(htree)
		local r = {}
		for k, v in pairs(htree) do
			local vtype = type(v)
			if vtype == "table" then
				local t = build_hierarchy_view(v)
				t.branchname = k
				table.insert(r, t)
			elseif vtype == "string" then
				table.insert(r, v)
			end
		end

		return r
	end

	local uitree = build_hierarchy_view(htree)
	uitree.branchname = "root"
    iup.TreeAddNodes(self.window, uitree)
end

return hierarchyview