local ecs = ...

local world = ecs.world
local physic = ecs.args.Physic
local physicworld = physic.world
local physic_objid_mapper = physic.objid_mapper

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

local collider_sys = ecs.system "collider_system"

function collider_sys:update()

end

function collider_sys:data_changed()
    for eid in world:each_new "collider_tag" do
        local e = world[eid]
        local c = e[e.collider_tag]
        physicworld:set_obj_user_idx(assert(c.handle), eid)
        c.user_idx = eid
    end
end

local char_sys = ecs.system "character_system"
char_sys.dependby "primitive_filter_system"

function char_sys:update()
    for _, char_eid in world:each "collider_tag" do
        local char = world[char_eid]
        local collider = char[char.collider_tag]

        -- TODO: world transform will not correct when this entity attach on hierarchy tree
        -- we need seprarte update transform from primitive_filter_system
        local worldmat = char.transform.world
        local colliderobj = collider.handle
        local t = physicworld:get_obj_transform(colliderobj)
        physicworld:set_obj_transform(colliderobj, ms(worldmat, t, "*m"))

        local aabbmin, aabbmax = physicworld:get_obj_aabb(colliderobj)
        local center = ms({0.5}, aabbmax, aabbmin, "+*T")
        local at = {center[1], aabbmin[2] - 20, center[3]}

        local hit, result = physicworld:raycast(center, at)
        if hit then
            char.transform.t = result.hit_pt_in_WS;
        end
    end
end