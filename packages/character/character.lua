local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms, mu = mathpkg.stack, mathpkg.util

local ani_module = require "hierarchy.animation"

ecs.component "character"
    .movespeed "real" (1.0)

local character_policy = ecs.policy "character"
character_policy.require_component "character"
character_policy.require_component "collider.character"

ecs.component "character_height_raycast"
    .dir "vector4" (0, -2, 0, 0)
local char_height_policy = ecs.policy "character_height_raycast"
char_height_policy.require_component "character_height_raycast"
char_height_policy.require_component "character"

char_height_policy.require_system "character_height_system"

local char_height_sys = ecs.system "character_height_system"
char_height_sys.require_system     "ant.bullet|collider_system"
char_height_sys.require_interface  "ant.bullet|collider"

local icollider = world:interface "ant.bullet|collider"

local character_motion = world:sub {"character_motion"}
local character_spawn = world:sub {"component_register", "character"}

local function generate_height_test_ray(e)
    local height_raycast = e.character_height_raycast
    local c_aabb_min, c_aabb_max = icollider(e)

    if c_aabb_min and c_aabb_max then
        local center = ms({0.5}, c_aabb_min, c_aabb_max, "+*T")
        local startpt = ms({center[1], c_aabb_min[2], center[2]}, "P")
        local endpt = ms(startpt, height_raycast.dir, "+P")
        return {
            startpt, endpt,
        }
    end
end

function char_height_sys:ik_target()
    for _, eid in world:each "character_height_raycast" do
        local e = world[eid]

        local ray = generate_height_test_ray(e)
        if ray then
            icollider.raycast(ray[1], ray[2])
        end
    end
end

ecs.component"leg"
    .joints "string[]"

ecs.component "foot_ik_ray"
    .foot "leg[2]"
    .cast_dir "vector4" (0, -2, 0, 0)

local foot_ik_policy = ecs.policy "foot_ik_raycast"
foot_ik_policy.require_component "character"
foot_ik_policy.require_component "foot_ik_ray"
foot_ik_policy.require_component "ik"

foot_ik_policy.require_system "character_foot_ik_system"
foot_ik_policy.require_system "ik_system"

local char_foot_ik_sys = ecs.system "character_foot_ik_system"

local function ankles_raycast_ray()
    return {

    }
end

local function ankles_target(ray)

end

local function calc_pelvis_offset(target)
    return {

    }
end

local function fill_ik_data(ikcomp)

end

function char_foot_ik_sys:ik_target()
    for _, eid in world:each "foot_ik_raycast" do
        local e = world[eid]

        local ske = e.skeleton
        local foot_rc = e.foot_ik_raycast
        local ik = e.ik

        for _, leg in ipairs(foot_rc.foot) do
            local cast_dir = leg.cast_dir
            local anklename = leg[3]
            local jointidx = ske:joint_index(anklename)
            assert(jointidx ~= nil, "not exist target name in skeleton:" .. anklename)
            local ankle_pos = ani_module.joint_pos(jointidx)

            local target = ankles_target(ankles_raycast_ray(ankle_pos, cast_dir))
            calc_pelvis_offset(target)
            fill_ik_data(ik, target)
        end

    end
end