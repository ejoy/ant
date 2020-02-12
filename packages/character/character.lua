local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms, mu = mathpkg.stack, mathpkg.util

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

ecs.component "character"
    .movespeed "real" (1.0)

local character_policy = ecs.policy "character"
character_policy.require_component "character"
character_policy.require_component "collider"

ecs.component "character_height_raycast"
    .dir "vector" (0, -2, 0, 0)

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

ecs.component "ik_tracker"
    .leg            "string"
    ["opt"].sole    "string"

ecs.component "foot_ik_raycast"
    .cast_dir "vector" (0, -2, 0, 0)
    .foot_height "real" (0)
    .trackers  "ik_tracker[]"

local foot_ik_policy = ecs.policy "foot_ik_raycast"
foot_ik_policy.require_component "character"
foot_ik_policy.require_component "foot_ik_raycast"
foot_ik_policy.require_component "ik"

foot_ik_policy.require_policy "ant.animation|ik"

foot_ik_policy.require_system "character_foot_ik_system"
foot_ik_policy.require_transform "check_ik_data"

local foot_t = ecs.transform "check_ik_data"
foot_t.input "ik"
foot_t.output "foot_ik_raycast"

local function which_job(ik, name)
    for _, j in ipairs(ik.jobs) do
        if j.name == name then
            return j
        end
    end
end

function foot_t.process(e)
    local r = e.foot_ik_raycast
    local ik = e.ik

    local trackers = r.trackers
    for _, tracker in ipairs(trackers) do
        local leg_ikdata = which_job(ik, tracker.leg)
        if leg_ikdata == nil then
            error(string.format("foot_ik_raycast.ik_job_name:%s, not found in ik component", r.ik_job_name))
        end

        if leg_ikdata.type ~= "two_bone" then
            error(string.format("leg ik job must be two_bone:%s", leg_ikdata.type))
        end

        local joint_indices = leg_ikdata.joint_indices
        if #joint_indices ~= 3 then
            error(string.format("joints number must be 3 for two_bone ik type, %d provided", #joint_indices))
        end

        -----
        local sole_ikdata = which_job(ik, tracker.sole)
        if sole_ikdata == nil then
            error(string.format("invalid ik job name:%s", tracker.sole))
        end

        if sole_ikdata.type ~= "aim" then
            error(string.foramt("sole ik job must aim type:%s", sole_ikdata.type))
        end

        local sole_joint_indices = sole_ikdata.joint_indices
        if #sole_joint_indices ~= 1 then
            error(string.format("joints number must be 1 for aim ik type, %d provided", #sole_joint_indices))
        end

        if joint_indices[3] ~= sole_joint_indices[1] then
            error(string.format("we assume leg last joint is equal to sole joint"))
        end
    end
end

local char_foot_ik_sys = ecs.system "character_foot_ik_system"
char_foot_ik_sys.require_interface "ant.bullet|collider"
char_foot_ik_sys.require_policy "foot_ik_raycast"

local function ankles_raycast_ray(ankle_pos_ws, dir)
    return {
        ankle_pos_ws,
        ms(ankle_pos_ws, dir, "+P")
    }
end

local function ankles_target(ray, foot_height)
    local hit, result = icollider.ray_test(ray)
    if hit then
        local pt = result.hit_pt_in_WS
        local normal = result.hit_normal_in_WS

        return ms(pt, normal, {foot_height}, "*+P"), normal
    end
end

function char_foot_ik_sys:ik_target()
    for _, eid in world:each "foot_ik_raycast" do
        local e = world[eid]

        local foot_rc = e.foot_ik_raycast
        local ik = e.ik

        local pose_result = e.pose_result.result

        local trans = ms:srtmat(e.transform)

        local cast_dir = foot_rc.cast_dir
        local foot_height = foot_rc.foot_height

        local leg_info = {}
        local trackers = foot_rc.trackers
        local numlegs = #trackers
        for whichleg=1, numlegs do
            local leg_ikdata = which_job(ik, trackers[whichleg].leg)
            local anklenidx = leg_ikdata.joint_indices[3]
            local ankle_pos = ms:vector(pose_result:joint_trans(anklenidx, 4))
            local ankle_pos_ws = ms(trans, ankle_pos, "*P")

            local castray = ankles_raycast_ray(ankle_pos_ws, cast_dir)
            local target_ws, hitnormal_ws = ankles_target(castray, foot_height)
            if target_ws then
                leg_info[whichleg] = {
                    ankle_pos_ws, target_ws, hitnormal_ws
                }
            end
        end

        local function calc_pelvis_offset()
            local maxdot
            for whichleg=1, numlegs do
                local li = leg_info[whichleg]
                if li then
                    local ankle_pos_ws, target_ws = li[1], li[2]
                    local dot = ms(cast_dir, target_ws, ankle_pos_ws, "-.T")
                    if maxdot then
                        if dot[1] > maxdot[1] then
                            maxdot = dot
                        end
                    else
                        maxdot = dot
                    end
                end
            end
            
            if maxdot then
                maxdot[2] = nil
                return ms(maxdot, cast_dir, "*P")
            end
        end

        local pelvis_offset = calc_pelvis_offset()
        if pelvis_offset then
            local correct_trans = ms:add_translate(trans, pelvis_offset)
            local inv_correct_trans = ms(correct_trans, "iP")

            local function joint_y_vector(jointidx)
                return ms:vector(pose_result:joint_trans(jointidx, 2))
            end


            for whichleg=1, numlegs do
                local li = leg_info[whichleg]
                if li then
                    local tracker = trackers[whichleg]
                    local leg_ikdata = which_job(ik, tracker.leg)
                    local target_ws = li[2]

                    ms(leg_ikdata.target, inv_correct_trans, target_ws, "*=")

                    local knee = leg_ikdata.joint_indices[2]
                    leg_ikdata.pole_vector(joint_y_vector(knee))

                    if tracker.sole then
                        local sole_ikdata = which_job(ik, tracker.sole)
                        local hitnormal = li[3]
                        ms(sole_ikdata.target, inv_correct_trans, target_ws, hitnormal, "+*=")
                        sole_ikdata.pole_vector(joint_y_vector(sole_ikdata.joint_indices[1]))
                    end
                end
            end
        else
            --error(string.format("not valid leg found and colud not correct pelivs offset"))
        end
    end
end