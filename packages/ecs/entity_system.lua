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
        update_group_tag(initargs.data)
        w:template_instance(initargs.template, serialize.unpack, initargs.data)
    end
    w:group_update()
    w:clear "create_entity"
    w:clear "create_entity_template"
end

function m:entity_ready()
    w:clear "INIT"
end

function m:update_world()
    w:update()
    world._frame = world._frame+ 1
end
