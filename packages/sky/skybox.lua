local ecs = ...
local world = ecs.world

local iibl = world:interface "ant.render.ibl|iibl"

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

local skybox_sys = ecs.system "skybox_system"
local sb_mb = world:sub {"component_register", "skybox"}
function skybox_sys.data_changed()
	for _, _, eid in sb_mb:unpack() do
		local se = world[eid]
		local se_ibl = se.ibl
		local t = se._rendercache.properties.s_skybox
		local h = t.value.texture.handle
		iibl.filter_all{
			source = {handle = h},
			irradiance = se_ibl.irradiance,
			prefilter = se_ibl.prefilter,
			LUT= se_ibl.LUT,
		}
		world:pub{"ibl_updated", eid}
	end
end