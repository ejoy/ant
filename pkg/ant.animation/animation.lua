local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr = import_package "ant.asset"
local ozz = require "ozz"
local skinning = ecs.require "skinning"

local m = ecs.system "animation_system"
local api = {}

local function create(filename)
    local data = assetmgr.resource(filename)
    local skeleton = data.skeleton
    local status = {}
    for name, handle in pairs(data.animations) do
        status[name] = {
            handle = handle,
            sampling = ozz.SamplingJobContext(handle:num_tracks()),
            ratio = nil,
        }
    end
    local obj = {
        skeleton = skeleton,
        meshskin = skinning.create(data.meshskin, skeleton),
        status = status,
        locals = nil,
        models = ozz.MatrixVector(skeleton:num_joints()),
    }
    return obj
end

function m:component_init()
    local animations = {}
    for e in w:select "INIT animation:update scene:in eid:in animation_changed?out" do
        if e.animation == true then
            local obj = assert(animations[e.scene.parent])
            e.animation = obj
            animations[e.eid] = obj
        else
            local obj = create(e.animation)
            e.animation = obj
            e.animation_changed = true
            animations[e.eid] = obj
        end
    end
end

local function sampling(ani)
    local skeleton = ani.skeleton
    for _, status in pairs(ani.status) do
        if status.ratio then
            --TODO: blend
            if not ani.locals then
                ani.locals = ozz.SoaTransformVector(skeleton:num_soa_joints())
            end
            ozz.SamplingJob(status.handle, status.sampling, ani.locals, status.ratio)
            ozz.LocalToModelJob(skeleton, ani.locals, ani.models)
            return
        end
    end
    ozz.LocalToModelJob(skeleton, nil, ani.models)
end

function m:animation_sample()
    for e in w:select "animation_changed animation:in" do
        local obj = e.animation
        sampling(obj)
        skinning.build(obj.models, obj.meshskin)
    end
    w:clear "animation_changed"
end

function api.play(e, name, ratio)
    local status = e.animation.status[name]
    if status.ratio ~= ratio then
        status.ratio = ratio
        w:extend(e, "animation_changed?out")
        e.animation_changed = true
    end
end

return api
