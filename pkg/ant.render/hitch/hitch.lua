local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local mc        = import_package "ant.math".constant
local ig        = ecs.require "ant.group|group"

local Q         = world:clibs "render.queue"

local h = ecs.component "hitch"
function h.init(hh)
    assert(hh.group ~= nil)
    hh.visible_idx  = 0xffffffff
    hh.cull_idx     = 0xffffffff
    return hh
end

local hitch_sys = ecs.system "hitch_system"

function hitch_sys:component_init()
    for e in w:select "INIT hitch:update" do
        local ho = e.hitch
        ho.visible_idx = Q.alloc()
        ho.cull_idx = Q.alloc()
    end
end

function hitch_sys:entity_remove()
    for e in w:select "REMOVED hitch:in" do
        local ho = e.hitch
        Q.dealloc(ho.visible_idx)
        Q.dealloc(ho.cull_idx)
    end
end

function hitch_sys:entity_init()
    for e in w:select "INIT hitch hitch_bounding?out view_visible?in hitch_visible?out" do
        e.hitch_bounding = true
        e.hitch_visible = e.view_visible
    end
end

function hitch_sys:entity_ready()
    if not w:check "hitch_bounding" then
        return
    end

    local groups = setmetatable({}, {__index=function(t, gid)
        local gg = {}
        t[gid] = gg
        return gg
    end})
    for e in w:select "hitch_bounding hitch:in eid:in" do
        local g = groups[e.hitch.group]
        g[#g+1] = e.eid
    end

    for gid, hitchs in pairs(groups) do
        ig.enable(gid, "hitch_tag", true)

        local h_aabb = math3d.aabb()
        for re in w:select "hitch_tag bounding:in" do
            if mc.NULL ~= re.bounding.aabb then
                h_aabb = math3d.aabb_merge(h_aabb, re.bounding.aabb)
            end
        end

        if math3d.aabb_isvalid(h_aabb) then
            for _, heid in ipairs(hitchs) do
                local e<close> = world:entity(heid, "bounding:update scene_needchange?out")
                math3d.unmark(e.bounding.aabb)
                e.scene_needchange = true
                e.bounding.aabb = math3d.mark(h_aabb)
            end
        end
    end

    w:clear "hitch_bounding"
end
