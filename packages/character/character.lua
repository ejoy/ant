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
char_height_sys.require_system     "ant.collision|collider_system"
char_height_sys.require_interface  "ant.collision|collider"

local icollider = world:interface "ant.collision|collider"

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

function foot_t.process(e)
    local r = e.foot_ik_raycast
    local ik = e.ik

    local trackers = r.trackers
    local jobs = ik.jobs
    for _, tracker in ipairs(trackers) do
        local leg_ikdata = jobs[tracker.leg]
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
        local sole_name = tracker.sole
        if sole_name then
            local sole_ikdata = jobs[tracker.sole]
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
end

local char_foot_ik_sys = ecs.system "character_foot_ik_system"
char_foot_ik_sys.require_interface "ant.collision|collider"
char_foot_ik_sys.require_interface "ant.animation|ik"
char_foot_ik_sys.require_policy "foot_ik_raycast"

local iik = world:interface "ant.animation|ik"

local function ankles_raycast_ray(ankle_pos_ws, dir)
    return {
        ankle_pos_ws,
        ms(ankle_pos_ws, dir, "+P")
    }
end

local function ankles_target(ray, foot_height)
    local pos, normal = icollider.raycast(ray)
    if pos then
        return ms(pos, normal, {foot_height}, "*+P"), normal
    end
end

local function calc_pelvis_offset()
    return nil
    -- local maxdot
    -- for whichleg=1, numlegs do
    --     local li = leg_info[whichleg]
    --     if li then
    --         local ankle_pos_ws, target_ws = li[1], li[2]
    --         local dot = ms(target_ws, ankle_pos_ws, "-", cast_dir, ".T")
    --         if maxdot then
    --             if dot[1] > maxdot[1] then
    --                 maxdot = dot
    --             end
    --         else
    --             maxdot = dot
    --         end
    --     end
    -- end
    
    -- if maxdot then
    --     maxdot[2] = nil
    --     return ms(maxdot, cast_dir, "*P")
    -- end
end

local function find_leg_raycast_target(pose_result, ik, foot_rc, trans)
    local leg_raycasts = {}
    local cast_dir = foot_rc.cast_dir
    local foot_height = foot_rc.foot_height
    local jobs = ik.jobs
    for _, tracker in ipairs(foot_rc.trackers) do
        local leg_ikdata = jobs[tracker.leg]
        local anklenidx = leg_ikdata.joint_indices[3]
        local ankle_pos = ms:vector(pose_result:joint_trans(anklenidx, 4))
        local ankle_pos_ws = ms(trans, ankle_pos, "*P")

        local castray = ankles_raycast_ray(ankle_pos_ws, cast_dir)
        local target_ws, hitnormal_ws = ankles_target(castray, foot_height)
        if target_ws then
            leg_raycasts[#leg_raycasts+1] = {
                tracker, ankle_pos_ws, target_ws, hitnormal_ws
            }
        end
    end

    return leg_raycasts
end

local function do_foot_ik(pose_result, ik, inv_trans, leg_raycasts)
    local function joint_y_vector(jointidx)
        return ms:vector(pose_result:joint_trans(jointidx, 2))
    end
    local jobs = ik.jobs
    for _, leg in ipairs(leg_raycasts) do
        local tracker = leg[1]
        local leg_ikdata = jobs[tracker.leg]
        local sole_ikdata = tracker.sole and jobs[tracker.sole] or nil

        local target_ws = leg[3]
        ms(leg_ikdata.target, inv_trans, target_ws, "*=")

        local knee = leg_ikdata.joint_indices[2]
        leg_ikdata.pole_vector(joint_y_vector(knee))

        iik.do_ik(leg_ikdata)

        if sole_ikdata then
            local hitnormal = leg[4]
            ms(sole_ikdata.target, inv_trans, target_ws, hitnormal, "+*=")
            sole_ikdata.pole_vector(joint_y_vector(sole_ikdata.joint_indices[1]))
            iik.do_ik(sole_ikdata)
        end
    end
end

function char_foot_ik_sys:do_ik()
    for _, eid in world:each "foot_ik_raycast" do
        local e = world[eid]
        local foot_rc = e.foot_ik_raycast
        
        local ik = e.ik
        local pose_result = e.pose_result.result
        local trans = ms:srtmat(e.transform)

        local leg_raycasts = find_leg_raycast_target(pose_result, ik, foot_rc, trans)

        if next(leg_raycasts) then
            iik.setup(e)
            local pelvis_offset = calc_pelvis_offset()
            local correct_trans = pelvis_offset and ms:add_translate(trans, pelvis_offset) or trans
            local inv_correct_trans = ms(correct_trans, "iP")

            do_foot_ik(pose_result, ik, inv_correct_trans, leg_raycasts)
        end
    end

end