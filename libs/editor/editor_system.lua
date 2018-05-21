local ecs = ...
local world = ecs.world

local editor_mainwin = require "editor.window"

local editor_sys = ecs.system "editor_system"
editor_sys.singleton "math_stack"
editor_sys.depend "end_frame"

local function build_hierarchy_tree()
	local htree = {}
	local eidin_hierarchy = {}   

    for _, eid in world:each("main_camera") do
        assert(not eidin_hierarchy[eid])
        eidin_hierarchy[eid] = true
        local e = world[eid]
        local ename = e.name
        table.insert(htree, ename and ename.n or "main_camera")
    end

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
                        t[child.name] = ct                        
                    else
                        table.insert(t, child.name)
                    end
                end

            end
            return t
        end

        local t = build_hierarchy_entity_tree(hierarchy_tree, name_mapper)        
        local ename = e.name
		local name = ename and ename.n or "hierarchy_entity"
		htree[name] = t
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
	
	return htree
end

function editor_sys:init()
	local hv = editor_mainwin.hierarchyview
	local htree = build_hierarchy_tree()
    hv:build(htree)
end

function editor_sys.notify:hierarchyview_selection(set)
    local hv = editor_mainwin.hierarchyview
    local htree = hv.window
    
    --editor_mainwin.
end

function editor_sys.notify:hierarchyview_deselection(set)

end