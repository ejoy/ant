local log = log and log(...) or print

local hierarchyview = {}

hierarchyview.window = iup.tree {
    hidebuttons ="YES",
    hidelines   ="YES",
    title = "World",
}

function hierarchyview:build(world)
    local tree = assert(hierarchyview.window)

    local eidin_hierarchy = {}
    local htree = {}

    local function build_entity_tree(eid)
        local t = {}
        local e = world[eid]
        local ename = e.name.n
        t.branchname = ename and ename or "entity"
        local comp_list = world:component_list(eid)
        for _, n in ipairs(comp_list) do
            table.insert(t, n)
        end
        return t
    end

    for _, eid in world:each("editable_hierarchy") do
        eidin_hierarchy[eid] = true
        local e = world[eid]
        local ename = e.name.n
        htree.branchname = ename and ename or "hierarchy_entity"

        local hierarchy_tree = e.editable_hierarchy.root
        local name_mapper = e.hierarchy_name_mapper
        local function build_hierarchy_entity_tree(ehierarchy, name_mapper)
            local t = {}
            local num = #ehierarchy
            for i=1, num do
                local child = ehierarchy[i]
                local cnum = #child
                if cnum ~= 0 then
                    local ct = build_hierarchy_entity_tree(child)
                    ct.branchname = child.name
                    table.insert(t, ct)
                else
                    local node_eid = name_mapper[child.name]
                    if node_eid then
                        local nodetree = build_entity_tree(node_eid)
                        table.insert(t, nodetree)
                    else
                        log(string.format("not found child node in name mapper, name is : %s", child.name))
                        
                    end
                end
            end        
        end

        local t = build_hierarchy_entity_tree(hierarchy_tree)

        table.insert(htree, t)
    end

    for _, eid in world:each("render") do
        local t = build_entity_tree(eid)
        table.insert(htree, t)
    end

    iup.TreeAddNodes(self.window, htree)
end

return hierarchyview