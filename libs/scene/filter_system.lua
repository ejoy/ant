local ecs = ...
local world = ecs.world

local mu = require "math.util"

--- hierarchy update system -----------------------------
local hierarchy_update_sys = ecs.system "hierarchy_update_system"

hierarchy_update_sys.singleton "math_stack"

local function update_child_srt(ms, e, srt, node)
    local rot = ms({type="q", table.unpack(node.r)}, "eT")
    rot[1], rot[2] = rot[2], rot[1]

    local localsrt = mu.srt(ms, node.s, rot, node.t);
    local s, r, t = ms(localsrt, srt, "*~PPP");

    ms(e.scale.v, s, "=", e.rotation.v, r, "=", e.position.v, t, "=")
end

function hierarchy_update_sys:update()
    local ms = self.math_stack
    for _, h_eid in world:each("hierarchy") do
        local h_entity = assert(world[h_eid])
        local hierarchy = h_entity.hierarchy
        
        if not hierarchy.dirty then
            return 
        end            
        hierarchy.dirty = false

        local rootsrt = mu.srt_from_entity(ms, h_entity)
        local builddata = hierarchy.builddata

        local mapper = h_entity.hierarchy_name_mapper.v
        for _, node in ipairs(builddata) do
            local name = node.name
            local c_eid = mapper[name]                
            local c_entity = world[c_eid]
            if c_entity then
                update_child_srt(ms, c_entity, rootsrt, node)
            else
                error(string.format("not found entity by hierarchy name mapper, name is : %s", name))
            end
        end
    end  
end

local function push_primitive_in_filter(ms, eid, filter)
    local e = world[eid]
    local render = e.render

    if render == nil or not render.visible then
        return 
    end

    local rinfo = render.info
    local properties = render.properties
    local result = filter.result

    for idx, elem in ipairs(rinfo) do
        local esrt = elem.srt
        local srt = {}
        srt.s, srt.r, srt.t = ms(
            {type="srt", s=esrt.s, r=esrt.r, t=esrt.t}, 
            {type="srt", s=e.scale.v, r=e.rotation.v, t=e.position.v}, 
            "*~TTT")
        local elem_properties  = properties and properties[idx] or nil

        for _, binding in ipairs(elem.binding) do
            local material = assert(binding.material)
            local meshids = binding.meshids
            local mgroups = elem.mesh.handle.group
            
            for _, mid in ipairs(meshids) do
                local g = mgroups[mid]
                table.insert(result, {
                    eid = eid,
                    mgroup = g,
                    material = material,
                    properties = elem_properties,
                    srt = srt,
                })
            end
        end
    end
end

--- scene filter system----------------------------------
local primitive_filter_sys = ecs.system "primitive_filter_system"

primitive_filter_sys.singleton "primitive_filter"
primitive_filter_sys.singleton "math_stack"

primitive_filter_sys.depend "hierarchy_update_system"

function primitive_filter_sys:update()
    local ms = self.math_stack
    local filter = self.primitive_filter
    filter.result = {}    
    for _, eid in world:each("render") do        
        push_primitive_in_filter(ms, eid, filter)
    end
end

----for select filter system-------------------------------
local select_filter_sys = ecs.system "select_filter_system"

select_filter_sys.singleton "math_stack"
select_filter_sys.singleton "select_filter"

primitive_filter_sys.depend "hierarchy_update_system"

function select_filter_sys:update()
    local ms = self.math_stack
    local filter = self.select_filter
    filter.result = {}
    for _, eid in world:each("can_select") do        
        push_primitive_in_filter(ms, eid, filter)
    end
end