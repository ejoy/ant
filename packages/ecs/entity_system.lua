local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "entity_system"

local function update_group_tag(data)
    local groupid = data.group
    for tag, t in pairs(world._group.tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

function m:entity_create()
    for v in w:select "create_entity:in" do
        local initargs = v.create_entity
        initargs.INIT = true
        update_group_tag(initargs)
        w:new(initargs)
    end
    w:clear "create_entity"

    for v in w:select "create_entity_template:in" do
        local initargs = v.create_entity_template
        initargs.data.INIT = true
        if initargs.parent then
            initargs.data.LAST_CREATE = true
        end
        update_group_tag(initargs.data)
        w:template_instance(initargs.template, initargs.data)
        if initargs.parent then
            for e in w:select "LAST_CREATE scene:update" do
                e.scene.parent = initargs.parent
            end
            w:clear "LAST_CREATE"
        end
    end
    w:clear "create_entity_template"

    w:group_update()
end

function m:entity_ready()
    w:clear "INIT"
end

function m:update_world()
    w:update()
    world._frame = world._frame+ 1
end

local MethodRemove = {}

function m:init()
    for name, func in pairs(world._class.component) do
        MethodRemove[name] = func.remove
    end
end

function m:entity_remove()
    for v in w:select "REMOVED id:in" do
        local e = world._entity[v.id]
        for name, func in pairs(MethodRemove) do
            local c = e[name]
            if c then
                func(c)
            end
        end
        world._entity[v.id] = nil
    end
end
