local log = log and log(...) or print

local hierarchyview = {}

hierarchyview.window = iup.tree {
    hidebuttons ="YES",
    hidelines   ="YES",
    title = "World",
}

function hierarchyview:build(world)
    local eidin_hierarchy = {}
    local htree = {}

    htree.branchname = world.name or "World"

    for _, eid in world:each("editable_hierarchy") do
        eidin_hierarchy[eid] = true
        local e = world[eid]
    
        local hierarchy_tree = e.editable_hierarchy.root
        local name_mapper = e.hierarchy_name_mapper.v
        local function build_hierarchy_entity_tree(ehierarchy, name_mapper)
            local t = {}
            local num = #ehierarchy
            for i=1, num do
                local child = ehierarchy[i]
                local childnum = #child
                local ceid = name_mapper[child.name]
                if ceid then
                    eidin_hierarchy[ceid] = true

                    if childnum ~= 0 then
                        local ct = build_hierarchy_entity_tree(child, name_mapper)
                        ct.branchname = child.name
                        table.insert(t, ct)
                    else
                        table.insert(t, child.name)
                    end
                end

            end
            return t
        end

        local t = build_hierarchy_entity_tree(hierarchy_tree, name_mapper)        
        local ename = e.name
        t.branchname = ename and ename.n or "hierarchy_entity"

        table.insert(htree, t)
    end

    for _, eid in world:each("render") do
        if not eidin_hierarchy[eid] then
            local e = world[eid]
            if e.render.visible then
                local ename = e.name                   
                table.insert(htree, ename and ename.n or "entity")
            end
        end
    end

    iup.TreeAddNodes(self.window, htree)
end

return hierarchyview