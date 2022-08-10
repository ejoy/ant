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
end

function m:entity_ready()
    w:clear "INIT"
end

function m:update_world()
    w:visitor_update()
    w:update()
    world._frame = world._frame+ 1
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

function m:entity_remove()
    for name, func in pairs(MethodRemove) do
        for v in w:select("REMOVED "..name..":in") do
            func(v[name])
        end
    end
end
