local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local update_sys = ecs.system "entity_update_system"
local init_sys = ecs.system "entity_init_system"

local evOnRemoveInstance = world:sub {"OnRemoveInstance"}

local PipelineEntityRemove

function update_sys:entity_ready()
    for v in w:select "on_ready:in" do
        v:on_ready()
    end
    w:clear "on_ready"
end

function update_sys:pipeline()
    PipelineEntityRemove = world:pipeline_func "_entity_remove"
end

function update_sys:frame_remove_entity()
    --step1. Remove prefab
    for _, instance in evOnRemoveInstance:unpack() do
        instance.REMOVED = true
        for _, entity in ipairs(instance.tag["*"]) do
            w:remove(entity)
        end
    end

    --step2. Destroy entity
    if w:check "REMOVED" then
        PipelineEntityRemove()
        for name, func in pairs(world._component_remove) do
            for v in w:select("REMOVED "..name..":in") do
                func(v[name])
            end
        end
    end
    local destruct = world._destruct
    if #destruct > 0 then
        world._destruct = {}
        for _, f in ipairs(destruct) do
            f(world)
        end
    end

    --step3. Remove entity
    w:update()
    math3d.reset()
end

function update_sys:frame_system_changed()
    if world._system_changed_func then
        world._system_changed_func()
    end
end

function init_sys:frame_create_entity()
    world:_flush_instance_queue()
    world:_flush_entity_queue()
end

function update_sys:exit_stat()
    world._templates = {}
    collectgarbage "collect"
    local material = ecs.require "ant.material|material"
    if material.clear_all_uniforms then
        material.clear_all_uniforms()
    end
    local destruct = world._destruct
    if #destruct > 0 then
        world._destruct = {}
        for _, f in ipairs(destruct) do
            f(world)
        end
    end
    for name, func in pairs(world._component_remove) do
        for v in w:select(name..":update") do
            func(v[name])
        end
    end
    math3d.reset()
    math3d.reset()
    print("math3d marked:", math3d.info "marked")
    print("math3d ref:", math3d.info "ref")
    for k, v in pairs(math3d.marked_list()) do
        print(k, v)
    end
end
