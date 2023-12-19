local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr = import_package "ant.asset"
local ozz = require "ozz"
local skinning = ecs.require "skinning"

local m = ecs.system "animation_system"

local function create(filename)
    local data = assetmgr.resource(filename)
    local skeleton = data.skeleton
    local status = {}
    for name, handle in pairs(data.animations) do
        status[name] = {
            handle = handle,
            sampling = ozz.SamplingJobContext(handle:num_tracks()),
            ratio = 0,
            weight = 0,
        }
    end
    local obj = {
        skeleton = skeleton,
        status = status,
        blending_layers = ozz.BlendingJobLayerVector(),
        blending_threshold = 0.1,
        locals_pool = {},
        models = ozz.MatrixVector(skeleton:num_joints()),
        skinning = skinning.create(data.meshskin, skeleton),
    }
    return obj
end

function m:component_init()
    local animations = {}
    for e in w:select "INIT scene:in eid:in animation?update skinning?update animation_changed?out" do
        if e.skinning ~= nil then
            local obj = assert(animations[e.scene.parent])
            e.skinning = obj.skinning
            animations[e.eid] = obj
        elseif e.animation ~= nil then
            local obj = create(e.animation)
            e.animation = obj
            e.animation_changed = true
            animations[e.eid] = obj
        end
    end
end

local function resize_locals(ani, n)
    local locals = ani.locals_pool
    if #locals < n then
        local size = ani.skeleton:num_soa_joints()
        for i = #locals + 1, n do
            locals[i] = ozz.SoaTransformVector(size)
        end
    end
end

local function sampling(ani)
    local skeleton = ani.skeleton
    local layer = {}
    for _, status in pairs(ani.status) do
        if status.weight > 0 then
            layer[#layer+1] = status
        end
    end
    if #layer == 0 then
        ozz.LocalToModelJob(skeleton, nil, ani.models)
        return
    elseif #layer == 1 then
        resize_locals(ani, 1)
        local status = layer[1]
        local locals = ani.locals_pool[1]
        ozz.SamplingJob(status.handle, status.sampling, locals, status.ratio)
        ozz.LocalToModelJob(skeleton, locals, ani.models)
        return
    end
    local layers = ani.blending_layers
    layers:resize(#layer)
    resize_locals(ani, #layer + 1)
    for i = 1, #layer do
        local status = layer[i]
        local locals = ani.locals_pool[i]
        ozz.SamplingJob(status.handle, status.sampling, locals, status.ratio)
        layers:set(i, locals, status.weight)
    end
    local locals = ani.locals_pool[#layer + 1]
    ozz.BlendingJob(layers, locals, skeleton, ani.blending_threshold)
    ozz.LocalToModelJob(skeleton, locals, ani.models)
end

function m:animation_sample()
    for e in w:select "animation_changed animation:in" do
        local obj = e.animation
        sampling(obj)
        skinning.build(obj.models, obj.skinning)
    end
end

function m:final()
    w:clear "animation_changed"
end

local api = {}

function api.set_status(e, name, ratio, weight)
    w:extend(e, "animation:in animation_changed?out")
    local status = e.animation.status[name]
    if status.ratio ~= ratio then
        status.ratio = ratio
        e.animation_changed = true
    end
    if status.weight ~= weight then
        status.weight = weight
        e.animation_changed = true
    end
end

function api.set_ratio(e, name, ratio)
    w:extend(e, "animation:in animation_changed?out")
    local status = e.animation.status[name]
    if status.ratio ~= ratio then
        status.ratio = ratio
        e.animation_changed = true
    end
end

function api.set_weight(e, name, weight)
    w:extend(e, "animation:in animation_changed?out")
    local status = e.animation.status[name]
    if status.weight ~= weight then
        status.weight = weight
        e.animation_changed = true
    end
end

function api.reset(e)
    w:extend(e, "animation:in animation_changed?out")
    for _, status in pairs(e.animation.status) do
        if status.weight ~= 0 then
            status.weight = 0
            e.animation_changed = true
        end
    end
end

function api.get_duration(e, name)
    w:extend(e, "animation:in")
    local status = e.animation.status[name]
    if status then
        return status.handle:duration()
    end
end

return api
