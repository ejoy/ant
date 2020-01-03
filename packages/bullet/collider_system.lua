local ecs = ...

local world = ecs.world
local physic = world.args.Physics
local physicworld = physic.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local collider_mb = world:sub {"component_register", "collider_tag"}

local collider_sys = ecs.system "collider_system"

function collider_sys:data_changed()
    for msg in collider_mb:each() do
        local eid = msg[3]
        local e = world[eid]
        local c = e[e.collider_tag]
        physicworld:set_obj_user_idx(assert(c.collider.handle), eid)
        c.user_idx = eid
    end
end

function collider_sys:update_collider_transform()
    for _, eid in world:each "collider_tag" do
        local e = world[eid]
        local collidercomp = e[e.collider_tag]

        -- TODO: world transform will not correct when this entity attach on hierarchy tree
        -- we need seprarte update transform from primitive_filter_system
        local collider = collidercomp.collider
        local m = ms:add_translate(e.transform.world, collider.center)
        physicworld:set_obj_transform(collider.handle, m)
    end
end

local char_sys = ecs.system "character_system"
char_sys.require_system "collider_system"

function char_sys:update_collider()
    for _, char_eid in world:each "character" do
        local char = world[char_eid]
        local collidercomp = char[char.collider_tag]
        local colliderobj = collidercomp.collider.handle
        local aabbmin, aabbmax = physicworld:aabb(colliderobj)
        local center = ms({0.5}, aabbmax, aabbmin, "+*T")
        local at = ms({center[1], aabbmin[2], center[3], 1.0}, "P")
        local hit, result = physicworld:raycast(ms(center, "P"), at)
        if hit then
            world:pub {"ray_cast_hitted", char_eid, result}
            ms(char.transform.t, result.hit_pt_in_WS, "=");
        end
    end
end