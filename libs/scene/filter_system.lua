local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"

local mu = require "math.util"

local scene_filter_sys = ecs.system "scene_filter_system"

scene_filter_sys.singleton "render_filter"
scene_filter_sys.singleton "math_stack"

function scene_filter_sys:init()

end

function scene_filter_sys:update()
    --{@    for render filter
    local ms = self.math_stack
    local render_filter = self.render_filter
    local marks = {}
    for _, eid in world:each("hierarchy") do
        local e = assert(world[eid])
        local rootsrt = mu.srt_from_entity(ms, e)

        local function extract_hierarchy_info(h_entity, filter)            
            local hierarchy_build_result = hierarchy_module.build(h_entity.hierarchy.root)
            local mapper = h_entity.hierarchy.name_mapper
            for _, v in ipairs(hierarchy_build_result) do
                local name = v.name                
                local c_eid = mapper[name]
                local c_entity = world[c_eid]
                if c_entity then                    
                    local rotation = ms({type="q", table.unpack(v.r)}, "eT")
                    rotation[1], rotation[2] = rotation[2], rotation[1]

                    local localsrt = mu.srt(ms, v.s, rotation, v.t);                    
                    local s, r, t = ms(localsrt, rootsrt, "*~PPP");

                    ms(c_entity.scale.v, s, "=")
                    ms(c_entity.rotation.v, r, "=")
                    ms(c_entity.position.v, t, "=")                  

                else
                    error(string.format("not found entity by hierarchy name mapper, name is : %s", name))
                end
            end
        end

        extract_hierarchy_info(e, render_filter)
    end    
    --@}
end

