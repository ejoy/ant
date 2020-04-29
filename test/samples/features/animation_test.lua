local ecs = ...
local world = ecs.world
local utilitypkg = import_package "ant.utility"
local fs_rt = utilitypkg.fs_rt

local fs = require "filesystem"
local anitest_sys = ecs.system "animation_test_system"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local math3d = require "math3d"

local entitydir = fs.path "/pkg/ant.test.features/assets/entities"

local function ozzmesh_animation_test()
    return world:create_entity(fs_rt.read_file(entitydir / "ozz_animation_sample.txt"))
end

local function gltf_animation_test()
    world:create_entity(fs_rt.read_file(entitydir / "gltf_animation_sample.txt"))
end

local function print_ske(ske)
    local trees = {}
    for i=1, #ske do
        local jname = ske:joint_name(i)
        if ske:isroot(i) then
            trees[i] = ""
            print(jname)
        else
            local s = "  "
            local p = ske:parent(i)
            assert(trees[p])
            s = s .. trees[p]
            trees[i] = s
            print(s .. jname)
        end
    end
end

function anitest_sys:init()
    ozzmesh_animation_test()
    gltf_animation_test()
end