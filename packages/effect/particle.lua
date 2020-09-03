local ecs = ...
local world = ecs.world

local math3d = require "math3d"

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
        current_time = 0,
        transforms = {}
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



------------------------------------------------------
local iemitter = ecs.interface "iemitter"

local iqc = world:interface "ant.render|iquadcache"

local function get_srt(emitter, quadidx)
    local t = emitter.transforms
    local srt = t[quadidx]
    if srt == nil then
        srt = {}
        t[quadidx] = srt
    end

    return srt
end

function iemitter.get_scale(eid, quadidx)
    local emitter = world[eid]._emitter
    local srt = emitter.transforms[quadidx]
    if srt then
        return srt.s
    end
end

function iemitter.get_rotation(eid, quadidx)
    local emitter = world[eid]._emitter
    local srt = emitter.transforms[quadidx]
    if srt then
        return srt.r
    end
end

function iemitter.get_translate(eid, quadidx)
    local emitter = world[eid]._emitter
    local srt = emitter.transforms[quadidx]
    if srt then
        return srt.t
    end
end

function iemitter.set_rotation(eid, quadidx, rotation)
    local e = world[eid]
    local emitter = e._emitter
    local srt = get_srt(emitter, quadidx)
    if srt.r == nil then
        srt.r = math3d.ref(math3d.quaternion(rotation))
    else
        srt.r.q = rotation
    end
end

function iemitter.set_scale(eid, quadidx, scale)
    local e = world[eid]
    local emitter = e._emitter
    local srt = get_srt(emitter, quadidx)
    local s = type(scale) == "number" and {scale, scale, scale} or scale
    if srt.s == nil then
        srt.s = math3d.ref(math3d.vector(s))
    else
        srt.s.v = s
    end
end

function iemitter.set_translate(eid, quadidx, translate)
    local srt = get_srt(world[eid]._emitter, quadidx)
    if srt.t == nil then
        srt.t = math3d.ref(math3d.vector(translate))
    else
        srt.t.v = translate
    end
end

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

-- function iemitter.update_quad_transform(emittereid)
--     local emitter = world[emittereid]._emitter
--     local quadsrt = emitter.srt
--     local quadnum = emitter.quad_num
--     local quadoffset = emitter.quad_offset

--     for ii=1, quadnum do
--         local srt = quadsrt[ii]
--         if srt then
--             local m = math3d.matrix(quadsrt[ii])
--             local quadidx = quadoffset + ii
--             local offset_vertex = (quadidx-1) * 4
--             for jj=1, 4 do
--                 local vertexidx = offset_vertex + jj

--                 local np = math3d.tovalue(math3d.transform(m, math3d.vector(iqc.vertex_pos(vertexidx)), 1))
--                 local nn = math3d.tovalue(math3d.transform(m, math3d.vector(iqc.vertex_normal(vertexidx)), 0))
    
--                 iqc.set_vertex_pos(vertexidx, np[1], np[2], np[3])
--                 iqc.set_vertex_normal(vertexidx, nn[1], nn[2], nn[3])
--             end
--         end
--     end
-- end