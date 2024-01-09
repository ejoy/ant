local utils = require "common.utils"
local lfs   = require "bee.filesystem"
local fs  = require "bee.filesystem"
local m = {
}

local init_param = {

}

function m.set_path(path)
    init_param.ProjectPath = path
    local standard_path = string.gsub(path, "\\", "/")
    local project_pos = string.find(standard_path, "/[^/]*$")
    --local current = fs.current_path()
    init_param.EnginePath = tostring(fs.relative(fs.current_path(), fs.path(standard_path)))
    init_param.EngineWinStylePath = string.gsub(init_param.EnginePath, "/", "\\")
    --init_param.MountRoot = string.sub(standard_path, project_pos + 1, -1)
    init_param.PackageName = string.sub(standard_path, project_pos + 1, -1)--string.gsub(init_param.MountRoot, '/', '.')--"ant." .. string.gsub(init_param.MountRoot, '/', '.')
    lfs.create_directory(lfs.path(init_param.ProjectPath .. "\\resource"))
end

function m.gen_main()
    local main_code = [[
package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start "$PackageName"
]]
    local test_code = [[
import_package "ant.window".start "$PackageName"
]]

    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\main.lua")), string.gsub(main_code, "%$(%w+)", init_param))
end

function m.gen_package()
    local package_code = [[
return {
    name = "$PackageName",
    ecs = {
        feature = {
            "$PackageName",
        }
    }
}
]]
    
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\package.lua")), string.gsub(package_code, "%$(%w+)", init_param))
end

function m.gen_mount()
    local mount_content = [[
@pkg pkg
@pkg-one ${project}
engine engine
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\.mount")), string.gsub(mount_content, "%$(%w+)", init_param))
end

function m.gen_init_system()
    local system_code = [[
local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = ecs.require "ant.render|render_system.renderqueue"

function m:init()
    print("my system init.")
end

function m:post_init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0)
    --world:create_instance "resource/scenes.prefab"
end
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\init_system.lua")), system_code)
end

function m.gen_package_ecs()
    local ecs = [[
system "init_system"
    .implement "init_system.lua"
    .method "init"
    .method "post_init"

pipeline "init"
    .stage "init"
    .stage "post_init"

pipeline "exit"
    .stage "exit"

pipeline "update"
    .stage "timer"
    .stage "start_frame"
    .stage "data_changed"
    .stage  "widget"
    .pipeline "sky"
    .pipeline "scene"
    .pipeline "camera"
    .pipeline "collider"
    .pipeline "animation"
    .pipeline "render"
    .pipeline "select"
    .pipeline "ui"
    .stage "end_frame"
    .stage "final"

pipeline "ui"
    .stage "ui_start"
    .stage "ui_update"
    .stage "ui_end"
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\package.ecs")), ecs)
end

function m.gen_settings()
    local settings = [[
_ios:
  graphic:
    api: metal
_osx:
  graphic:
    api: metal
_windows:
  graphic:
    api: d3d11
animation:
  skinning:
    type: CPU
    CPU:
      enable: true
      max_indices: 5
    GPU:
      enable: true
graphic:
  lighting:
    cluster_shading: 1
  render:
    clear_color: 0x000000ff
    clear_depth: 1
    clear_stencil: 0
    clear: CDS
  postprocess:
    bloom:
      enable: false
      inv_highlight: 0.1
      threshold: 2.3
  shadow:
    enable: true
    size: 1024
    type: inv_z
    bias: 0.003
    normal_offset: 0
    color: {0.05, 0.05, 0.05, 1}
    stabilize: true
    split_lamada: 1
    split_num: 4
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\settings")), settings)
end
function m.gen_bat()
    local bat = [[
$EngineWinStylePath\bin\lua.exe main.lua
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\run.bat")), string.gsub(bat, "%$(%w+)", init_param))
end

function m.gen_prebuild()
--     local content = [[
-- ---
-- path: /pkg/ant.resources/materials/depth.material
-- setting:
--     depth_type: inv_z
-- ---
-- path: /pkg/ant.resources/materials/depth.material
-- setting:
--     depth_type: inv_z
--     skinning: GPU
-- ---
-- type: fx
-- cs = /pkg/ant.resources/shaders/compute/cs_cluster_aabb.sc
-- setting:
--     CLUSTER_BUILD_AABB: 1
-- ---
-- type: fx
-- cs = /pkg/ant.resources/shaders/compute/cs_lightcull.sc
-- setting:
--     CLUSTER_LIGHT_CULL: 1
-- ---
-- path: /pkg/ant.resources/materials/postprocess
-- ]]
--     utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\prebuild")), content)
end
return m