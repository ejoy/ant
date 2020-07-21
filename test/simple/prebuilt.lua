dofile "engine/bootstrap.lua"

local prebuilt = import_package "ant.prebuilt"

prebuilt.load("material", "/pkg/ant.resources/materials/fullscreen.material")
prebuilt.load("material", "/pkg/ant.resources/materials/shadow/csm_cast.material", {shadow_type="inv_z"})
prebuilt.load("material", "/pkg/ant.resources/materials/shadow/csm_cast.material", {shadow_type="inv_z", skinning="GPU"})
prebuilt.load("prefab", "res/scenes.prefab")

prebuilt.build "windows_direct3d11"
prebuilt.build "ios_metal"
