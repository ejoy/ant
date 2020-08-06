local ecs = ...
local world = ecs.world

local geopkg = import_package "ant.geometry"
local geo = geopkg.geometry

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