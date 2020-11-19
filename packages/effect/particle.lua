local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local effect = require "effect"

local em_trans = ecs.transform "emitter_mesh_transform"
function em_trans.process_entity(e)
    if e.simplemesh == nil then
        e.simplemesh = {
            vb = {start=0,num=0},
            ib = {start=0, num=0}
        }
    end
end

local cpe_trans = ecs.transform "create_particle_emitters"
function cpe_trans.process_entity(e)
    e.particle_emitters = {}
end

local emitter_trans = ecs.transform "emitter_transform"

local function init_attributes(e)
    local attributes = {}
    for _, attrib in ipairs(e.emitter.attributes) do
        local function create_attribute(attrib)
            local name = attrib.name
            local inst = effect.create_attribute(name, attrib)
            if inst == nil then
                local f, err = loadfile("attributes/" .. name .. ".lua")
                if f == nil then
                    error(err)
                end

                inst = f{world, attrib}
            end

            return inst
        end

        local inst = create_attribute(attrib)
        if inst.init then
            inst:init(e)
        end
        attributes[#attributes+1] = inst
    end
end

function emitter_trans.process_entity(e)
    e._emitter = {
        current_time = 0,
        particles = effect.create_particles(e.emitter.spawn),
        attributes = init_attributes(e),
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

local itimer = world:interface "ant.timer|timer"

local function emitter_step(ee, dt)
    local _emitter = ee._emitter
    _emitter.delta_time = dt
    _emitter.current_time = _emitter.current_time + dt
end

function particle_sys:data_changed()
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



------------------------------------------------------
local iemitter = ecs.interface "iemitter"

local iqc = world:interface "ant.render|iquadcache"

function iemitter.iterquad(eid)
    local emitter = world[eid]._emitter
    local quadtransforms = emitter.transforms
    local quadnum = emitter.quad_num
    local quadoffset = emitter.quad_offset

    return function (t, idx)
        if idx > quadnum then
            return
        end
        local quadidx = quadoffset+idx
        local offset = (quadidx-1) *4
        
        return quadidx, offset, quadtransforms[idx]
    end, emitter, 1
end

function iemitter.scale_quad(eid, quadidx)
    local srt = world[eid]._emitter.transforms[quadidx]
    local vertexoffset = (quadidx-1)*4
    local s = srt.s
    if s then
        for jj=1, 4 do
            local vertexidx = vertexoffset+jj
            local np = math3d.tovalue(math3d.mul(s, math3d.vector(iqc.vertex_pos(vertexidx))))
            iqc.set_vertex_pos(vertexidx, np[1], np[2], np[3])
        end
    end
end

function iemitter.rotate_quad(eid, quadidx)
    local srt = world[eid]._emitter.transforms[quadidx]
    local vertexoffset = (quadidx-1)*4
    local r = srt.r
    if r then
        for jj=1, 4 do
            local vertexidx = vertexoffset+jj
            local np = math3d.tovalue(math3d.transform(r, math3d.vector(iqc.vertex_pos(vertexidx)), 1))
            local nn = math3d.tovalue(math3d.transform(r, math3d.vector(iqc.vertex_pos(vertexidx)), 0))

            iqc.set_vertex_pos(vertexidx, np[1], np[2], np[3])
            iqc.set_vertex_normal(vertexidx, nn[1], nn[2], nn[3])
        end
    end
end

function iemitter.translate_quad(eid, quadidx)
    local srt = world[eid]._emitter.transforms[quadidx]
    local vertexoffset = (quadidx-1)*4
    local t = srt.t
    if t then
        for jj=1, 4 do
            local vertexidx = vertexoffset+jj
            local np = math3d.tovalue(math3d.add(t, math3d.vector(iqc.vertex_pos(vertexidx)), 1))
            iqc.set_vertex_pos(vertexidx, np[1], np[2], np[3])
        end
    end
end