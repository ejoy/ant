local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local m = ecs.system "entity_system"

local evOnMessage = world:sub {"EntityMessage"}

local function update_group_tag(groupid, data)
    for tag, t in pairs(world._group_tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

function m:entity_init()
    for v in w:select "on_init:in" do
        v:on_init()
    end
    w:clear "on_init"
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

local function create_prefab()
    local queue = world._create_prefab_queue
    if #queue == 0 then
        return
    end
    world._create_prefab_queue = {}
    for i = 1, #queue do
        local q = queue[i]
        world:_prefab_instance(q.instance, q.args)
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
        local data = initargs.data or {}
        local template = initargs.template
        data.INIT = true
        update_group_tag(groupid, data)
        if template then
            if initargs.parent then
                data.LAST_CREATE = true
            end
            w:template_instance(eid, template, data)
            if initargs.parent then
                for e in w:select "LAST_CREATE scene:update" do
                    e.scene.parent = initargs.parent
                end
                w:clear "LAST_CREATE"
            end
        else
            w:import(eid, data)
        end
        w:group_add(groupid, eid)
        ::continue::
    end

    world:pipeline_entity_init()
    w:clear "INIT"
end
function m:entity_create()
    create_prefab()
    create_entity()
end

function m:update_world()
    local destruct = world._destruct
    if #destruct > 0 then
        world._destruct = {}
        for _, f in ipairs(destruct) do
            f(world)
        end
    end
    w:update()
    math3d.reset()
end

local function emptyfunc(f)
    local info = debug.getinfo(f, "SL")
    if info.what ~= "C" then
        local lines = info.activelines
        return next(lines, next(lines)) == nil
    end
end

local MethodRemove = {}

function m:init()
    for name, func in pairs(world._class.component) do
        local f = func.remove
        if f and not emptyfunc(f) then
            MethodRemove[name] = f
        end
    end
end

function m:entity_destory()
    if w:check "REMOVED" then
        world:pipeline_entity_remove()
        for name, func in pairs(MethodRemove) do
            for v in w:select("REMOVED "..name..":in") do
                func(v[name])
            end
        end
    end
end
