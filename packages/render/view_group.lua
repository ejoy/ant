local ecs   = ...
local world = ecs.world
local w     = world.w

local ivg = ecs.interface "iviewgroup"
local def_group_id<const> = 0
local def_group
function ivg.default_group()
    return def_group
end

function ivg.enable(id)
    local g = id == def_group_id and def_group or ecs.group(id)
    g:enable "view_visible"
end

function ivg.disable(id)
    local g = id == def_group_id and def_group or ecs.group(id)
    g:disable "view_visible"
end

function ivg.flush()
    ecs.group_flush()
end

local vg_sys = ecs.system "viewgroup_system"
function vg_sys:init()
    def_group = ecs.group(def_group_id)
    def_group:enable "view_visible"
end

function vg_sys:start_frame()
    ivg.flush()
end