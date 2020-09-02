local ecs = ...
local world = ecs.world


local attrib_accessors = {}
local function get_attrib_accessor(name)
    local accessor = attrib_accessors[name]
    if accessor == nil then
        accessor = require("attributes." .. name)
        attrib_accessors[name] = accessor
    end
    return accessor
end

local cpe_trans = ecs.transform "create_particle_emitters"
function cpe_trans.process_entity(e)
    e.particle_emitters = {}
end

local emitter_trans = ecs.transform "emitter_transform"
function emitter_trans.process_entity(e)
    e._emitter = {
        current_time = 0
    }
end

local aps = ecs.action "attach_particle_system"
function aps.init(prefab, idx, value)
    local ps = world[prefab[value]]

    local eid = prefab[idx]
    local particle_emitters = ps.particle_emitters
    particle_emitters[#particle_emitters+1] = eid
end
local particle_sys = ecs.system "particle_system"

local ps_init_mb = world:sub{"component_register", "particle_system"}
local ps_reset_mb = world:sub{"component_changed", "particle_system"}

local function init_ps(ps)
    -- 'init' of emitter should called by order
    for _, emittereid in ipairs(ps.particle_emitters) do
        local e = world[emittereid]
        for _, attrib in ipairs(e.emitter.attributes) do
            local accessor = get_attrib_accessor(attrib.name)
            if accessor.init then
                accessor.init(world, emittereid, attrib)
            end
        end
    end
end

local itimer = world:interface "ant.timer|timer"

local function emitter_step(ee, dt)
    local _emitter = ee._emitter
    
    _emitter.delta_time = dt
    _emitter.current_time = _emitter.current_time + dt
end

function particle_sys:data_changed()
    for _, _, eid in ps_init_mb:unpack() do
        init_ps(world[eid])
    end

    for _, _, eid in ps_reset_mb:unpack() do
        init_ps(world[eid])
    end

    local dt = itimer.delta()
    for _, eid in world:each "particle_system" do
        local ps = world[eid]
        for _, emittereid in ipairs(ps.particle_emitters) do
            local e = world[emittereid]
            emitter_step(e, dt)
            for _, attrib in ipairs(e.emitter.attributes) do
                local accessor = get_attrib_accessor(attrib.name)
                if accessor.update then
                    accessor.update(emittereid, attrib)
                end
            end
        end
    end
end

