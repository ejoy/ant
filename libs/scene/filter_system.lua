local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"

local mu = require "math.util"

local scene_filter_sys = ecs.system "scene_filter_system"

scene_filter_sys.singleton "primitive_filter"
scene_filter_sys.singleton "math_stack"

function scene_filter_sys:init()

end

local function push_primitive_in_filter(ms, e, filter)
    local render = e.render

    if render == nil or not render.visible then
        return 
    end

    local rinfo = render.info
    local uniform_setters = render.uniforms
    local result = filter.result

    for idx, elem in ipairs(rinfo) do
        local setters = uniform_setters and uniform_setters[idx] or nil

        local esrt = elem.srt
        local srt = {}
        srt.s, srt.r, srt.t = ms(
            {type="srt", s=esrt.s, r=esrt.r, t=esrt.t}, 
            {type="srt", s=e.scale.v, r=e.rotation.v, t=e.position.v}, 
            "*~TTT")
        for _, binding in ipairs(elem.binding) do
            local material = assert(binding.material)
            local meshids = binding.meshids
            local mgroups = elem.mesh.handle.group
            
            for _, mid in ipairs(meshids) do
                local g = mgroups[mid]
                table.insert(result, {
                    mgroup = g,
                    material = material,
                    uniforms = setters,
                    srt = srt,
                })
            end
        end
    end
end

local hierarchy_build_cache = {}

function scene_filter_sys:update()
    --{@    for render filter
    local ms = self.math_stack
    local filter = self.primitive_filter
    filter.result = {}
    local marks = {}
    for _, h_eid in world:each("hierarchy") do
        local h_entity = assert(world[h_eid])
        local rootsrt = mu.srt_from_entity(ms, h_entity)

        local function hierarchy_to_primitive(h_eid, h_entity, filter)
            local hierarchy_build_result = hierarchy_build_cache[h_eid]
            if hierarchy_build_result == nil then
                hierarchy_build_result = hierarchy_module.build(h_entity.hierarchy.root)
                hierarchy_build_cache[h_eid] = hierarchy_build_result
            end
            
            local mapper = h_entity.hierarchy.name_mapper
            for _, node in ipairs(hierarchy_build_result) do
                local name = node.name                
                local c_eid = mapper[name]
                marks[c_eid] = true
                local c_entity = world[c_eid]
                if c_entity then
                    local function update_child_srt(e, srt, node)
                        local rot = ms({type="q", table.unpack(node.r)}, "eT")
                        rot[1], rot[2] = rot[2], rot[1]
    
                        local localsrt = mu.srt(ms, node.s, rot, node.t);
                        local s, r, t = ms(localsrt, srt, "*~PPP");

                        ms(e.scale.v, s, "=", e.rotation.v, r, "=", e.position.v, t, "=")
                    end

                    update_child_srt(c_entity, rootsrt, node)
                    push_primitive_in_filter(ms, c_entity, filter)
                else
                    error(string.format("not found entity by hierarchy name mapper, name is : %s", name))
                end
            end
        end

        hierarchy_to_primitive(h_eid, h_entity, filter)
    end    

    for _, eid in world:each("render") do
        if not marks[eid] then
            local e = world[eid]
            push_primitive_in_filter(ms, e, filter)
        end
    end
    --@}
end

