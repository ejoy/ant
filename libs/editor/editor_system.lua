local ecs = ...
local world = ecs.world

local editor_mainwin = require "editor.window"

local editor_sys = ecs.system "editor_system"
editor_sys.singleton "math_stack"
editor_sys.depend "end_frame"

local function build_hierarchy_tree()
	local htree = {}
	local ud_table = {}
	local eidin_hierarchy = {}   

    for _, eid in world:each("main_camera") do
        assert(not eidin_hierarchy[eid])
        eidin_hierarchy[eid] = true
        local e = world[eid]
		local ename = e.name
		local name = ename and ename.n or "main_camera"
		ud_table[name] = eid
        table.insert(htree, name)
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
					ud_table[child.name] = ceid
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
		ud_table[name] = eid
    end

    for _, eid in world:each("render") do
        if not eidin_hierarchy[eid] then
            local e = world[eid]
            if e.render.visible then
				local ename = e.name
				local name = ename and ename.n or "entity"
				table.insert(htree, name)
				ud_table[name] = eid
            end
        end
	end
	
	return htree, ud_table
end

local function build_entity_tree(eid)
	local e = assert(world[eid])

	local function build_elem_tree(tr, filter)
		local t = {}
		for k, v in pairs(tr) do
			local ignore = filter and filter[k] or nil
			if not ignore then
				local ktype = type(k)
				if ktype == "string" or ktype == "number" then
					local vtype = type(v)
					if vtype == "table" then
						local r = build_elem_tree(v, filter)
						t[k] = r
					elseif vtype == "function" or vtype == "cfunction" then
						t[k] = "...function..."
					elseif vtype == "userdata" or vtype == "luserdata" then						
						t[k] = tostring(v) or "...userdata..."
					elseif vtype == "string" then
						t[k] = v
					elseif vtype == "number" or  vtype == "boolean" then
						t[k] = tostring(v)
					else
						dprint("not support value type : ", vtype, ", key is : ", k)
					end
				else
					dprint("not support key type : ", ktype)
				end
			else
				t[k] = v
			end
		end

		return t
	end
	local tr = {}
	for cname, v in pairs(e) do
		local etr = build_elem_tree(v)
		tr[cname] = etr
	end

	return tr
end

function editor_sys:init()
	local hv = editor_mainwin.hierarchyview
	hv.world = world
	local htree, ud_table = build_hierarchy_tree()
	hv:build(htree, ud_table)

	local pv = editor_mainwin.propertyview
	pv.world = world
	local ms = self.math_stack
	function hv.window:selection_cb(id, status)
		if status == 1 then
			local node = self:findchild_byid(id)
			if node then
				local eid = node.eid
				local ptree = build_entity_tree(eid)
				pv:build(ptree)
			end
		end
	end
end