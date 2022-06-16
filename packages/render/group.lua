local ecs   = ...
local world = ecs.world
local w     = world.w

local igroup = ecs.interface "igroup"
local def_group_id<const> = 0
local def_group
w:group_enable("view_visible", def_group_id)   -- enable default group id

function igroup.default_group_id()
    return def_group_id
end

function igroup.enable(...)
    def_group:enable "view_visible"
end

function igroup.flush()
    ecs.group_flush()
end

local group_sys = ecs.system "group_system"
function group_sys:init()
    def_group = ecs.create_group(def_group_id)
end
function group_sys:start_frame()
    igroup.flush()
end