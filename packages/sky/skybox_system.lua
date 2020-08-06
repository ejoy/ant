local ecs = ...
local world = ecs.world

local geopkg = import_package "ant.geometry"
local geo = geopkg.geometry

local math3d = require "math3d"

local sb_trans = ecs.transform "skybox_transform"
function sb_trans.process_prefab(e)
    local vb, ib = geo.box(1, true, false)
    e.mesh = world.component "mesh" {
		vb = {
			start = 0,
			num = 8,
			{
				declname = "p3",
				memory = {"fff", vb},
			},
		},
		ib = {
			start = 0,
			num = #ib,
			memory = {"w", ib},
		}
    }
end

local skybox_sys = ecs.system "skybox_system"
function skybox_sys:camera_usage()
    local cameraeid = world:singleton_entity "main_queue".camera_eid
    local ce = world[cameraeid]
    local camerapos = math3d.index(ce._rendercache.worldmat, 4)
    for _, eid in world:each "skybox" do
        local e = world[eid]
        local rc = e._rendercache
        rc.worldmat = math3d.set_index(rc.worldmat, 4, camerapos)
    end
end