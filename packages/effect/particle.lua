local ecs = ...
local world = ecs.world

local math3d        = require "math3d"
local effect        = require "effect"

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr

local irender       = world:interface "ant.render|irender"
local imaterial     = world:interface "ant.asset|imaterial"

local quadlayout = declmgr.get(declmgr.correct_layout "p3|t2|t21|c40niu")

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

function particle_sys:ui_update()
    local dt = itimer.delta()
    effect.update(dt * 0.001)
end