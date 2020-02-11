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
    .foot_height "real" (0)
    .legs   "string[]"
    .soles  "string[]"

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

local function which_job(ik, name)
    for _, j in ipairs(ik.jobs) do
        if j.name == name then
            return j
        end
    end
end

function foot_t.process(e)
    local r = e.foot_ik_ray
    local ik = e.ik

    local ske = e.skeleton

    local leg_joint_indices = {}
    for _, jobname in ipairs(r.legs) do
        local ikdata = which_job(ik, jobname)
        if ikdata == nil then
            error(string.format("foot_ik_ray.ik_job_name:%s, not found in ik component", r.ik_job_name))
        end

        if ikdata.type ~= "two_bone" then
            error(string.format("leg ik job must be two_bone:%s", ikdata.type))
        end

        local joints = ikdata.joints
        if #joints ~= 3 then
            error(string.format("joints number must be 3 for two_bone ik type, %d provided", #joints))
        end

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
        leg_joint_indices[#leg_joint_indices+1] = joint_indices
    end

    if #leg_joint_indices == 0 then
        error(string.format("leg joint is empty"))
    end

    local sole_joint_indices = {}
    for _, jobname in ipairs(r.soles) do
        local ikdata = which_job(ik, jobname)
        if ikdata == nil then
            error(string.format("invalid ik job name:%s", jobname))
        end

        if ikdata.type ~= "aim" then
            error(string.foramt("sole ik job must aim type:%s", ikdata.type))
        end

        local joints = ikdata.joints
        if #joints ~= 1 then
            error(string.format("joints number must be 1 for aim ik type, %d provided", #joints))
        end

        sole_joint_indices[#sole_joint_indices+1] = ske:joint_index()
    end

    if #sole_joint_indices == 0 then
        error(string.format("sole joint indices is empty"))
    end

    if leg_joint_indices[3] ~= sole_joint_indices[1] then
        error(string.format("we assume leg last joint is equal to sole joint"))
    end

    r.leg_joint_indices = leg_joint_indices
    r.sole_joint_indices = sole_joint_indices
end

local char_foot_ik_sys = ecs.system "character_foot_ik_system"

local function ankles_raycast_ray(ankle_pos_ws, dir)
    return {
        ankle_pos_ws,
        ms(ankle_pos_ws, dir, "+P")
    }
end

local function ankles_target(ray, foot_height)
    local hit, result = icollider:raycast(ray)
    if hit then
        local pt = result.hit_pt_in_WS
        local normal = result.hit_normal_in_WS

        return ms(pt, normal, {foot_height}, "*+P")
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

        local leg_joint_indices = foot_rc.leg_joint_indices
        local numlegs = #leg_joint_indices

        local legs = foot_rc.legs
        local soles = foot_rc.soles

        local sole_joint_indices = foot_rc.leg_joint_indices
        assert(numlegs == #sole_joint_indices)

        local leg_info = {}
        for whichleg=1, numlegs do
            local leg = leg_joint_indices[whichleg]
            local anklenidx = leg[3]
            local ankle_pos = pose_result:joint(anklenidx)
            local ankle_pos_ws = ms(trans, ankle_pos, "*P")

            local castray = ankles_raycast_ray(ankle_pos_ws, cast_dir)
            local target_ws = ankles_target(castray, foot_height)
            if target_ws then
                local dotresult = ms(cast_dir, ankle_pos, target_ws, "-.T")
                leg_info[whichleg] = {
                    ankle_pos, target_ws, dotresult[1]
                }
            end
        end

        local maxdot
        for whichleg=1, numlegs do
            local li = leg_info[whichleg]
            if li then
                local dot = li[3]
                maxdot = maxdot and math.max(maxdot, dot) or dot
            end
        end

        local pelvis_offset = ms({maxdot}, cast_dir, "*P")
        local correct_trans = ms:add_translate(trans, pelvis_offset)
        local inv_correct_trans = ms(correct_trans, "iP")

        local function joint_y_vector(jointidx)
            local knee_trans = pose_result:joint_trans(jointidx)
            local _, y = ms(knee_trans, "~PP")
            return y
        end


        for whichleg=1, numlegs do
            local li = leg_info[whichleg]
            if li then
                local leg_ikdata = which_job(ik, legs[whichleg])
                local target_ws = li[2]

                local target_ms = ms(inv_correct_trans, target_ws, "*P")
                leg_ikdata.traget = target_ms
                local indices = leg_joint_indices[whichleg]
                local knee = indices[2]
                leg_ikdata.pole_vector  = joint_y_vector(knee)

                local solejob = which_job(ik, soles[whichleg])
                solejob.target = target_ms
                solejob.pole_vector = joint_y_vector(sole_joint_indices[whichleg][1])
            end
        end
    end
end