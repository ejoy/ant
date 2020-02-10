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

ecs.component "foot_ik_ray"
    .cast_dir "vector4" (0, -2, 0, 0)
    .ik_job_names "string[]"

local foot_ik_policy = ecs.policy "foot_ik_raycast"
foot_ik_policy.require_component "character"
foot_ik_policy.require_component "foot_ik_ray"
foot_ik_policy.require_component "ik"

foot_ik_policy.require_system "character_foot_ik_system"
foot_ik_policy.require_system "ik_system"
foot_ik_policy.require_transform "match_ik_job_transform"

local foot_t = ecs.transform "match_ik_job_transform"
foot_t.input "foot_ik_ray"
foot_t.output "ik"

function foot_t.process(e)
    local r = e.foot_ik_ray
    local ik = e.ik

    local function which_job(name)
        for _, j in ipairs(ik.jobs) do
            if j.name == name then
                return j
            end
        end
    end

    local ray_joint_indices = {}
    for _, jobname in ipairs(r.ik_job_names) do
        local ikdata = which_job(jobname)
        if ikdata == nil then
            error(string.format("foot_ik_ray.ik_job_name:%s, not found in ik component", r.ik_job_name))
        end

        local joints = ikdata.joints
        if #joints ~= 3 then
            error(string.format("joints number must be 3, %d provided", #joints))
        end

        local ske = e.skeleton
        local joint_indices = {}
        for _, jn in ipairs(joints) do
            local jointidx = ske:joint_index(jn)
            if jointidx == nil then
                error(string.format("invalid joint name:%s", jn))
            end

            joint_indices[#joint_indices+1] = jointidx
        end
        for i=3, 2, -1 do
            local jidx = joint_indices[i]
            local pidx = ske:parent(jidx)

            local next_jidx = joint_indices[i-1]
            while pidx ~= next_jidx and pidx ~= 0 do
                pidx = ske:parent(pidx)
            end

            if pidx == 0 then
                error(string.format("ik joints can not use as foot ik, which joints must as parent clain:%s %s %s", joints[1], joints[2], joints[3]))
            end
        end
        ray_joint_indices[#ray_joint_indices+1] = joint_indices
    end

    if #ray_joint_indices ~= 0 then
        r.ray_joint_indices = ray_joint_indices
    end
end

local char_foot_ik_sys = ecs.system "character_foot_ik_system"

local function ankles_raycast_ray(ankle_pos_ws, dir)
    return {
        ankle_pos_ws,
        ms(ankle_pos_ws, dir, "+P")
    }
end

local function ankles_target(ray)

end

local function calc_pelvis_offset(target)
    return {

    }
end

local function fill_ik_data(ikcomp, target)

end

function char_foot_ik_sys:ik_target()
    for _, eid in world:each "foot_ik_raycast" do
        local e = world[eid]

        local ske = e.skeleton
        local foot_rc = e.foot_ik_raycast
        local ik = e.ik

        local invtrans = ms(ms:srtmat(e.transform), "iP")
        local cast_dir = foot_rc.cast_dir
        for _, leg in ipairs(foot_rc.ray_joint_indices) do
            local anklenidx = leg[3]
            local ankle_pos = ani_module.joint_pos(anklenidx)
            local ankle_pos_ws = ms(invtrans, ankle_pos, "*P")

            local target_ws = ankles_target(ankles_raycast_ray(ankle_pos_ws, cast_dir))
            calc_pelvis_offset(target_ws)
            fill_ik_data(ik, target_ws)
        end

    end
end