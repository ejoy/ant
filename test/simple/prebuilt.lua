local identity = ...

package.path = "engine/?.lua"
require "bootstrap"

local prebuilt = import_package "ant.prebuilt"

prebuilt.load("material", "/pkg/ant.resources/materials/fullscreen.material")
prebuilt.load("material", "/pkg/ant.resources/materials/depth.material", {depth_type="inv_z"})
prebuilt.load("material", "/pkg/ant.resources/materials/depth.material", {depth_type="inv_z", skinning="GPU"})
prebuilt.load_fx {
    cs = "/pkg/ant.resources/shaders/compute/cs_cluster_aabb.sc",
    setting = {CLUSTER_BUILD_AABB=1}
}
prebuilt.load_fx {
    cs = "/pkg/ant.resources/shaders/compute/cs_lightcull.sc",
    setting = {CLUSTER_LIGHT_CULL=1}
}
prebuilt.load("prefab", "res/scenes.prefab")
prebuilt.load("prefab", "/pkg/ant.resources.binary/meshes/female/female.glb|mesh.prefab")

prebuilt.load("material", "/pkg/ant.resources/materials/postprocess/combine.material")
prebuilt.load("material", "/pkg/ant.resources/materials/postprocess/dof/simple_blur.material")
prebuilt.load("material", "/pkg/ant.resources/materials/postprocess/dof/simple_merge.material")

if identity then
    prebuilt.build(identity)
else
    if require "platform".OS == "Windows" then
        prebuilt.build "windows_direct3d11"
    end

    prebuilt.build "ios_metal"
    prebuilt.build "osx_metal"
end
