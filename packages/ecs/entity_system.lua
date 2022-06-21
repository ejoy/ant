local ecs = ...
local world = ecs.world
local w = world.w
local serialize = import_package "ant.serialize"

local m = ecs.system "entity_system"

function m:entity_create()
    for v in w:select "create_entity:in" do
        local initargs = v.create_entity
        initargs.INIT = true
        w:new(initargs)
    end
    for v in w:select "create_entity_template:in" do
        local initargs = v.create_entity_template
        initargs.data.INIT = true
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
