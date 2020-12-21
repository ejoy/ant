local ecs = ...
local world = ecs.world

local math3d        = require "math3d"
local effect        = require "effect"

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr
local viewidmgr     = renderpkg.viewidmgr

local irender       = world:interface "ant.render|irender"
local ieffect_material_mgr = world:interface "ant.effect|ieffect_material_mgr"

local quadlayout = declmgr.get(declmgr.correct_layout "p3|t2|t21|c40niu")

local cpe_trans = ecs.transform "create_particle_emitters"
function cpe_trans.process_entity(e)
    e.particle_emitters = {}
end

local emitter_trans = ecs.transform "emitter_transform"
function emitter_trans.process_entity(e)
    local function fetch_material(rc)
        local fx, state, properties = rc.fx, rc.state, rc.properties
        local np = {
            uniforms = {},
            textures = {},
        }

        for k, p in pairs(properties) do
            local value = p.value
            if p.type == "s" then
                np.textures[k] = {
                    stage = value.stage,
                    uniformid = p.handle,
                    texid = value.texture.handle,
                }
            else
                np.uniforms[k] = {
                    uniformid = p.handle,
                    value = math3d.value_ptr(value.value),
                }
            end
        end
        return {
            fx = fx,
            state = state,
            properties = np,
        }
    end
    e._emitter = {
        handle          = effect.create_emitter(e.emitter),
        material_idx    = ieffect_material_mgr.register(e.material, fetch_material(e._rendercache)),
    }
end

local particle_sys = ecs.system "particle_system"

function particle_sys:init()
    effect.init {
        viewid      = viewidmgr.get "main_view",
        qb          = {
            ib      = (irender.quad_ib() &0xffff),
            layout  = quadlayout.handle,
        },
    }
end

local itimer = world:interface "ant.timer|timer"

local function update_emitter(e, dt)
    local wm = e._rendercache.worldmat
    local emitter = e._emitter
    local eh = emitter.handle
    eh:update(dt)
    while (0 ~= eh:spawn(math3d.value_ptr(wm), e._emitter.material_idx)) do end
end

function particle_sys:ui_update()
    local dt = itimer.delta() * 0.001
    for _, eid in world:each "emitter" do
        local e = world[eid]
        update_emitter(e, dt)
    end

    effect.update_particles(dt)
end