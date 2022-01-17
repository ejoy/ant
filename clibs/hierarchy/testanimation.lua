local hierarchy = require "hierarchy"
local math3d        = require "math3d"
local math3d_adapter= require "math3d.adapter"
local animation = require "hierarchy".animation
local skeleton = require "hierarchy".skeleton

local new_vector_float3 = animation.new_vector_float3
local new_vector_quaternion = animation.new_vector_quaternion

local t = {
    {animation.vector_float3_mt(),     "v",   "format", {"insert", "at"},  2}, 
    {animation.vector_quaternion_mt(), "q",   "format", {"insert", "at"},  2},
    {skeleton.node_metatable(), "vqv", "format", {"add_child"},     3},
    {skeleton.node_metatable(), "vqv", "getter", {"transform"},     nil}, 
    {skeleton.node_metatable(), "vqv", "format", {"set_transform"}, 1}, 
    {animation.pose_result_mt(), "m",  "getter", {"joint"}, 3},
}

for _, v in ipairs(t) do
    local mt = v[1]
    local math3d_type_str = v[2]
    local adapter_method_name = v[3] 
    local methods = v[4]
    local begin_idx = v[5]
    for _, method in ipairs(methods) do
        print(method, math3d_type_str, begin_idx)
        mt[method] = math3d_adapter[adapter_method_name](mt[method], math3d_type_str, begin_idx)
    end
end

local raw_animation = animation.new_raw_animation()
local translations = new_vector_float3()
for i = 1, 10 do
    translations:insert(math3d.vector{0, 1, 0})
end

local rotations = new_vector_quaternion()
for i = 1, 10 do
    rotations:insert(math3d.quaternion {axis=math3d.vector{0, 1, 0}, r=math.pi * 0.5})
end

local duration = 6.0
local skl = skeleton.build({
    {name = "root_1", s = {1.0, 1.0, 1.0}, r = {0.0, 0.0, 0.0, 1.0}, t = {0.0, 0.0, 0.0}},
    {name = "root_2", s = {1.0, 1.0, 1.0}, r = {0.0, 0.0, 0.0, 1.0}, t = {0.0, 0.0, 0.0}},
})

raw_animation:push_key(skl, {translations, translations}, {rotations, rotations}, duration)
local ani = raw_animation:build()

local poseresult = animation.new_pose_result(#skl)
poseresult:setup(skl)
poseresult:do_sample(animation.new_sampling_context(1), ani, 0.1, 0)
poseresult:fetch_result()

for i = 1, poseresult:count() do
    local m = math3d.tovalue(poseresult:joint(i))
    print(table.concat(m, ","))
end

