local utils = require "common.utils"
local lfs   = require "filesystem.local"

local m = {
}

local init_param = {

}

function m.set_path(path)
    init_param.ProjectPath = path
    local standard_path = string.gsub(path, "\\", "/")
    local engine_pos = string.find(standard_path, '/ant/')
    init_param.MountRoot = string.sub(standard_path, engine_pos + 5, -1)
    init_param.PackageName = string.gsub(init_param.MountRoot, '/', '.')--"ant." .. string.gsub(init_param.MountRoot, '/', '.')
    lfs.create_directory(lfs.path(init_param.ProjectPath .. "\\res"))
end

function m.gen_main()
    local main_code = [[
package.path = "engine/?.lua"
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
        import = {
            "@$PackageName",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "$PackageName|init_system",
        }
    }
}
]]
    
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\package.lua")), string.gsub(package_code, "%$(%w+)", init_param))
end

function m.gen_mount()
    local mount_content = [[
@pkg packages
@pkg-one $MountRoot
engine engine
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\.mount")), string.gsub(mount_content, "%$(%w+)", init_param))
end

function m.gen_init_system()
    local system_code = [[
local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"
function m:init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0)
    --world:instance "res/scenes.prefab"
end
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\init_system.lua")), system_code)
end

function m.gen_package_ecs()
    local ecs = [[
import "@ant.general"
import "@ant.render"
import "@ant.animation"
import "@ant.sky"
import "@ant.camera"
import "@ant.asset"

system "init_system"
    .implement "init_system.lua"
    .require_policy "ant.general|name"
    .require_policy "ant.render|render"
    .require_policy "ant.render|light"
    .require_policy "ant.render|shadow_cast_policy"
    .require_policy "ant.animation|animation"
    .require_policy "ant.animation|skinning"
    .require_policy "ant.sky|procedural_sky"
    .require_policy "ant.render|simplerender"
    .require_policy "ant.render|postprocess"
    .method "init"

pipeline "init"
    .stage "init"
    .stage "post_init"

pipeline "exit"
    .stage "exit"

pipeline "update"
    .stage "timer"
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
  render:
    clear_color: 0x000000ff
    clear_depth: 1
    clear_stencil: 0
    clear: CDS
  hdr:
    enable: true
    format: RGBA16F
  postprocess:
    bloom:
      enable: true
      format: RGBA16F
      sample_times: 4
  shadow:
    enable: true
    size: 1024
    type: inv_z
    bias: 0.003
    normal_offset: 0
    color: {1, 1, 1, 1}
    stabilize: true
    split_lamada: 1
    split_num: 4
]]
    utils.write_file(tostring(lfs.path(init_param.ProjectPath .. "\\settings")), settings)
end
return m