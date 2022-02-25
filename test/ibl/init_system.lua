local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local samplerutil=renderpkg.sampler
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local icamera   = ecs.import.interface "ant.camera|icamera"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"

local imaterial = ecs.import.interface "ant.asset|imaterial"

local is = ecs.system "init_system"

local cube_face_entities

local iblmb = world:sub {"ibl_updated"}
local viewid = viewidmgr.generate "cubeface_viewid"
local cube_rq

w:register {name = "cube_test_queue"}
local face_size<const> = 256

function is:init()
    ecs.create_instance "/pkg/ant.test.ibl/assets/skybox.prefab"
    ecs.create_instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
end

function is:data_changed()
    -- for _, eid in iblmb:unpack() do
    --     local ibl = world[eid]._ibl
    --     imaterial.set_property(eid, "s_skybox", {stage=0, texture={handle=ibl.irradiance.handle}})
    -- end
end

function is:render_submit()

end