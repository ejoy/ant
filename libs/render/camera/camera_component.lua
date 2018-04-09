local ecs = ...
local world = ecs.world

local mu = require "math.util"
ecs.component "main_camera" {}

local camera_init_sys = ecs.system "camera_init"
camera_init_sys.singleton "math_stack"

function camera_init_sys:init()
    local ms = self.math_stack
    -- create camera entity
    local camera_eid = world:new_entity("main_camera", "viewid", "rotation", "position", "frustum", "view_rect", "clear_component", "name")        
    local camera = world[camera_eid]
    camera.viewid.id = 0
    camera.name.n = "main_camera"

    ms(camera.position.v,    {5, 5, -5, 1},  "=")
    ms(camera.rotation.v,   {45, -45, 0, 0},   "=")

    local frustum = camera.frustum
    mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)
end