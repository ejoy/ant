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

    e._emitter = {
        handle      = effect.create_emitter(e.emitter)
    }
end

local particle_sys = ecs.system "particle_system"

function particle_sys:post_init()
    local viewid = world:singleton_entity "main_queue".render_target.viewid
    effect.init {
        viewid      = viewid,
        progid      = (particle_material.fx.prog & 0xffff),
        qb          = {
            ib = (irender.quad_ib() &0xffff),
            layout = quadlayout.handle,
        },
        textures    = textures,
    }
end

local itimer = world:interface "ant.timer|timer"

-- local function calc_spawn_num(spawn, dt)
--     local function delta_spawn(spawn)
--         local t = spawn.spawn_loop % spawn.rate
--         local step = t / spawn.rate
--         return step * spawn.count
--     end
--     local already_spawned = delta_spawn(spawn)
--     spawn.spawn_loop = spawn.spawn_loop + dt
--     local totalnum = delta_spawn(spawn)

--     return totalnum - already_spawned
-- end

local function update_emitter(e, dt)
    local srt = e._rendercache.srt
    local eh = e._emitter.handle
    eh:update(dt)
    while (0 ~= eh:spawn(srt.p)) do end
end

function particle_sys:ui_update()
    local dt = itimer.delta() * 0.001
    for _, eid in world:each "emitter" do
        local e = world[eid]
        update_emitter(e, dt)
    end

    effect.update_particles(dt)
end