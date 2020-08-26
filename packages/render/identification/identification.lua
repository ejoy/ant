local ecs = ...
local world = ecs.world

local math3d = require "math3d"

policy "identification"
    .require_system "ant.render|identification"
    .require_interface "ant.render|ifontmgr"
    .component "identification"
    .component "name"

local ifontmgr = world:interface "ifontmgr"

local ident_sys = ecs.system "identification"

local function calc_identification_pos(e)
    local mask<const> = {0, 1, 0, 0}
    local aabb = e._rendercache.aabb
    if aabb then
        local center, extent = math3d.aabb_center_extents(aabb)
        return math3d.muladd(mask, extent, center)
    end
end

function ident_sys:follow_transform_updated()
    for _, eid in world:each "identification" do
        local e = world[eid]
        local n = e.name
        local ident = e.identitfication
        local pos = calc_identification_pos(e)
        local fontsetting = ident.font_setting
        if fontsetting then
            ifontmgr.draw(pos, n, fontsetting.keepsize)
        end
    end
end