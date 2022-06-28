local ecs = ...
local world = ecs.world
local w = world.w
local serialize = import_package "ant.serialize"

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
        w:template_instance(initargs.template, serialize.unpack, initargs.data)
        if initargs.parent then
            for e in w:select "LAST_CREATE scene:update" do
                e.scene.parent = initargs.parent
            end
            w:clear "LAST_CREATE"
        end
    end
    w:group_update()
    w:clear "create_entity"
    w:clear "create_entity_template"
end

function m:entity_ready()
    w:clear "INIT"
end

local evParentChanged = world:sub {"parent_changed"}

local function rebuild(id)
    local e = world._entity_visitor[id]
    w:clone(e, {group = w:group_id(e)})
    w:remove(e)
end

local function getentityid(id)
    local e = world._entity_visitor[id]
    return w:readid(e)
end

function m:update_world()
	for _, id, parentid in evParentChanged:unpack() do
		local e = world:entity(id)
		if e then
            e.scene_changed = true
			e.scene.parent = parentid
            if getentityid(id) < getentityid(parentid) then
                rebuild(id)
            end
		end
	end
    w:group_update()
    w:update()
    world._frame = world._frame+ 1
end

function m:entity_remove()
    for e in w:select "REMOVED id:in" do
        world._entity[e.id] = nil
    end
end
