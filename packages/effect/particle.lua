local ecs = ...
local world = ecs.world

local math3d        = require "math3d"
local effect        = require "effect"

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr

local irender       = world:interface "ant.render|irender"
local imaterial     = world:interface "ant.asset|imaterial"

local quadlayout = declmgr.get(declmgr.correct_layout "p3|t2|c40niu")

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
local particle_material_path = "/pkg/ant.resources/materials/particle/particle.material"
local particle_material
local textures
function emitter_trans.process_entity(e)
    local viewid = world:singleton_entity "main_queue".render_target.viewid
    if particle_material == nil then
        particle_material = imaterial.load(particle_material_path)
        textures = {}
        local uniforms = particle_material.fx.uniforms
        local function find_uniform(name)
            for _, u in ipairs(uniforms) do
                if u.name == name then
                    return (u.handle & 0xffff)
                end
            end

            error("not found uniform: " .. name)
        end
        for k, v in pairs(particle_material.properties) do
            if v.stage then
                textures[#textures+1] = {
                    stage       = v.stage,
                    uniformid   = find_uniform(k),
                    texid       = (v.texture.handle & 0xffff),
                }
            end
        end
    end
    e._emitter = {}
    local prog = particle_material.fx.prog
    effect.create_emitter{
        viewid      = viewid,
        progid      = (prog & 0xffff),
        qb          = {
            ib = (irender.quad_ib() &0xffff),
            layout = quadlayout.handle,
        },
        textures    = textures,
        emitter     = e.emitter,
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

function particle_sys:init()
    effect.init()
end

local itimer = world:interface "ant.timer|timer"

local function emitter_step(ee, dt)
    local _emitter = ee._emitter
    _emitter.delta_time = dt
    _emitter.current_time = _emitter.current_time + dt
end

-- function particle_sys:data_changed()

-- end

function particle_sys:ui_update()
    local dt = itimer.delta()
    effect.update(dt * 0.001)
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