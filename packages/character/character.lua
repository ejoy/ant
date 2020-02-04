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

local char_sys = ecs.system "character_system"
char_sys.require_system     "ant.bullet|collider_system"
char_sys.require_interface "ant.bullet|collider"

local icollider = world:interface "ant.bullet|collider"

local character_motion = world:sub {"character_motion"}
local character_spawn = world:sub {"component_register", "character"}

local char_height_dir = ms:vector(0, -1, 0, 0)

function char_sys:data_changed()
    for _, eid in world:each "character" do
        local e = world[eid]

        local char = e.character
        local rc = e.raycast

        local collider = e.collider.handle
        local c_aabb_min, c_aabb_max = icollider(e)

        if c_aabb_min and c_aabb_max then
            
            rc.rays["height"] = {
                
            }
        end

        


    end
end

function char_sys:character_height()
    for _, eid in world:each "character" do
        local e = world[eid]
        local char = e.character
        local rc = e.raycast


    end
end