local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms, mu = mathpkg.stack, mathpkg.util

ecs.component "character"
    .movespeed "real" (1.0)

local character_policy = ecs.policy "character"
character_policy.require_component "character"
character_policy.require_component "collider.character"

character_policy.require_component "raycast"
character_policy.require_component "animation"
character_policy.require_component "skeleton"

character_policy.require_policy "ant.aniamtion|animaiton"
character_policy.require_policy "ant.bullet|raycast"

ecs.component "character_height_raycast"
    .dir "vector4" (0, -2, 0, 0)
local char_height_policy = ecs.policy "character_height_raycast"
char_height_policy.require_component "character_height_raycast"
char_height_policy.require_component "character"
char_height_policy.require_component "raycast"
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
function char_height_sys:data_changed()
    for _, eid in world:each "character_height_raycast" do
        local e = world[eid]
        local rc = e.raycast

        local ray = generate_height_test_ray(e)
        if ray then
            rc.rays["height"] = ray
        end
    end
end

function char_height_sys:character_height()
    for _, eid in world:each "character" do
        local e = world[eid]
        local char = e.character
        local rc = e.raycast

    end
end

ecs.component "foot_ik_ray"
    .target_names "string[]"
    .dir "vector4" (0, -2, 0, 0)

local foot_ik_policy = ecs.policy "foot_ik_raycast"
foot_ik_policy.require_component "character"
foot_ik_policy.require_component "foot_ik_ray"
foot_ik_policy.require_component "skeleton"
foot_ik_policy.require_component "animation"
foot_ik_policy.require_component "raycast"

foot_ik_policy.require_system "character_foot_ik_system"

local char_foot_ik_sys = ecs.system "character_foot_ik_system"

function char_foot_ik_sys:data_changed()
    for _, eid in world:each "foot_ik_raycast" do
        local e = world[eid]
        local rc = e.raycast

        local ske = e.skeleton
        local foot_rc = e.foot_ik_raycast

        for _, tn in ipairs(foot_rc.target_names) do
            assert(ske:joint_idx(tn), "not exist target name in skeleton:" .. tn)
            
            
        end

    end
end