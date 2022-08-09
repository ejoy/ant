local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "entity_system"

local function update_group_tag(groupid, data)
    for tag, t in pairs(world._group.tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

function m:entity_create()
    local queue = world._create_queue
    world._create_queue = {}

    for i = 1, #queue do
        local initargs = queue[i]
        local eid = initargs.eid
        local groupid = initargs.group
        local data = initargs.data
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
    end
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
