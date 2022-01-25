local hierarchy = require "hierarchy"
local math3d        = require "math3d"
local math3d_adapter= require "math3d.adapter"
local animation = hierarchy.animation
local skeleton = hierarchy.skeleton
local mc = {ONE = math3d.vector({1, 1, 1})}

--
local t = {
    {skeleton.node_metatable(),        "vqv", "format", {"add_child"},     3},
    {skeleton.node_metatable(),        "vqv", "getter", {"transform"},     nil},
    {skeleton.node_metatable(),        "vqv", "format", {"set_transform"}, 1},
    {animation.pose_result_mt(),       "m",   "getter", {"joint"}, 3},
    {animation.raw_animation_mt(),     "vqv", "format", {"push_prekey"},   4},
}

for _, v in ipairs(t) do
    local mt = v[1]
    local math3d_type_str = v[2]
    local adapter_method_name = v[3]
    local methods = v[4]
    local begin_idx = v[5]
    for _, method in ipairs(methods) do
        mt[method] = math3d_adapter[adapter_method_name](mt[method], math3d_type_str, begin_idx)
    end
end

--
local duration = 10.0
local skl = skeleton.build({
    {name = "root_1", s = {1.0, 1.0, 1.0}, r = {0.0, 0.0, 0.0, 1.0}, t = {0.0, 0.0, 0.0}},
    {name = "root_2", s = {1.0, 1.0, 1.0}, r = {0.0, 0.0, 0.0, 1.0}, t = {0.0, 0.0, 0.0}},
    {name = "root_3", s = {1.0, 1.0, 1.0}, r = {0.0, 0.0, 0.0, 1.0}, t = {0.0, 0.0, 0.0}},
})

local raw_animation = animation.new_raw_animation()

local function build_animation(raw_animation)
    local ani = raw_animation:build()

    --
    local poseresult = animation.new_pose_result(#skl)
    poseresult:setup(skl)
    poseresult:do_sample(animation.new_sampling_context(1), ani, 0.1, 0)
    poseresult:fetch_result()

    for i = 1, poseresult:count() do
        local m = math3d.tovalue(poseresult:joint(i))
        print(("joint %d:"):format(i), table.concat(m, ","))
    end
end

local function test()
    raw_animation:setup(skl, duration)

    local joint_name 
    joint_name = "root_1"
    for i = 0, 10, 1 do
        raw_animation:push_prekey(
            joint_name,
            i, -- time [0, duration]
            mc.ONE, -- scale
            math3d.quaternion({axis = math3d.vector {0, 1, 0}, r = math.pi * 0.5}), -- rotation
            math3d.vector({0, 1, 0}) -- translation
        )
    end

    joint_name = "root_2"
    for i = 0, 10, 2 do
        raw_animation:push_prekey(
            joint_name,
            i, -- time [0, duration]
            mc.ONE, -- scale
            math3d.quaternion({axis = math3d.vector {0, 1, 0}, r = math.pi * 0.5}), -- rotation
            math3d.vector({0, 1, 0}) -- translation
        )
    end

    build_animation(raw_animation)
end

test()
raw_animation:clear()
print("------------")

local function test_clear_prekey(raw_animation)
    raw_animation:setup(skl, duration)

    local joint_name 
    joint_name = "root_1"
    for i = 0, 10, 1 do
        raw_animation:push_prekey(
            joint_name,
            i, -- time [0, duration]
            mc.ONE, -- scale
            math3d.quaternion({axis = math3d.vector {0, 1, 0}, r = math.pi * 0.5}), -- rotation
            math3d.vector({0, 1, 0}) -- translation
        )
    end

    joint_name = "root_2"
    for i = 0, 10, 2 do
        raw_animation:push_prekey(
            joint_name,
            i, -- time [0, duration]
            mc.ONE, -- scale
            math3d.quaternion({axis = math3d.vector {0, 1, 0}, r = math.pi * 0.5}), -- rotation
            math3d.vector({0, 1, 0}) -- translation
        )
    end

    raw_animation:clear_prekey("root_2")

    build_animation(raw_animation)
end
test_clear_prekey(raw_animation)
