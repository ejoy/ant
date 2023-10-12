local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local m = ecs.system "entity_system"

local evOnMessage = world:sub {"EntityMessage"}
local evOnRemoveInstance = world:sub {"OnRemoveInstance"}

local MethodRemove = {}

local PipelineEntityInit
local PipelineEntityRemove

local function update_group_tag(groupid, data)
    for tag, t in pairs(world._group_tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

function m:entity_ready()
    for v in w:select "on_ready:in" do
        v:on_ready()
    end
    w:clear "on_ready"
end

function m:data_changed()
    for msg in evOnMessage:each() do
        local eid = msg[2]
        local v = w:fetch(eid, "on_message:in")
        if v then
            v:on_message(table.unpack(msg, 3))
            w:submit(v)
        end
    end
end

function m:prefab_remove()
    for _, instance in evOnRemoveInstance:unpack() do
        instance.REMOVED = true
        if instance.proxy then
            w:remove(instance.proxy)
        end
        for _, entity in ipairs(instance.tag["*"]) do
            w:remove(entity)
        end
    end
end

local function create_prefab()
    local queue = world._create_prefab_queue
    if #queue == 0 then
        return
    end
    world._create_prefab_queue = {}
    for i = 1, #queue do
        world:_prefab_instance(queue[i])
    end
end

local function create_entity()
    local queue = world._create_entity_queue
    if #queue == 0 then
        return
    end
    world._create_entity_queue = {}

    for i = 1, #queue do
        local initargs = queue[i]
        local eid = initargs.eid
        if not w:exist(eid) then
            log.warn(("entity `%d` has been removed."):format(eid))
            goto continue
        end
        local groupid = initargs.group
        local data = initargs.data
        local template = initargs.template
        data.INIT = true
        update_group_tag(groupid, data)
        if template then
            w:template_instance(eid, template, data)
        else
            w:import(eid, data)
        end
        w:group_add(groupid, eid)
        ::continue::
    end

    PipelineEntityInit()
    w:clear "INIT"
end
function m:entity_create()
    create_prefab()
    create_entity()
end

function m:update_ecs()
    local destruct = world._destruct
    if #destruct > 0 then
        world._destruct = {}
        for _, f in ipairs(destruct) do
            f(world)
        end
    end
    w:update()
end

function m:update_world()
    math3d.reset()
end

local function emptyfunc(f)
    local info = debug.getinfo(f, "SL")
    if info.what ~= "C" then
        local lines = info.activelines
        return next(lines, next(lines)) == nil
    end
end

function m:init()
    PipelineEntityInit = world:pipeline_func "_entity_init"
    PipelineEntityRemove = world:pipeline_func "_entity_remove"
    for name, func in pairs(world._components) do
        local f = func.remove
        if f and not emptyfunc(f) then
            MethodRemove[name] = f
        end
    end
end

function m:entity_destory()
    if w:check "REMOVED" then
        PipelineEntityRemove()
        for name, func in pairs(MethodRemove) do
            for v in w:select("REMOVED "..name..":in") do
                func(v[name])
            end
        end
    end
end
