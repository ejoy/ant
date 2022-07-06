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

local evParentChanged = world:sub {"parent_changed"}

local function needRebuild(id, parentid)
    local e = world._entity_visitor[id]
    local parent = world._entity_visitor[parentid]
    if w:readid(e) < w:readid(parent) then
        return true
    end
end

local function rebuild(id)
    local e = world._entity_visitor[id]
    w:clone(e, {group = w:group_id(e)})
    e.CLONED = true
    w:sync("CLONED?out", e)
end

local function setParent(id, parentid)
    local e = world:entity(id)
    if not e then
        return
    end
    if parentid == nil then
        e.scene_needchange = true
        e.scene.parent = 0
        return
    end
    local parent = world:entity(parentid)
    if not parent then
        world:remove_entity(id)
        return
    end
    e.scene_needchange = true
    e.scene.parent = parentid
    if needRebuild(id, parentid) then
        local r = {id, [id]=true}
        for v in w:select "scene:in id:in" do
            if r[v.scene.parent] then
                r[v.id] = true
                r[#r+1] = v.id
            end
        end
        for id in ipairs(r) do
            rebuild(id)
        end
        w:remove_update "CLONED"
    end
end

function m:entity_create()
    local _ = world
    for v in w:select "create_entity:in" do
        local initargs = v.create_entity
        initargs.INIT = true
        update_group_tag(initargs)
        w:new(initargs)
    end
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
    w:clear "create_entity"
    w:clear "create_entity_template"
    w:group_update()

    for _, id, parentid in evParentChanged:unpack() do
        setParent(id, parentid)
    end
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
