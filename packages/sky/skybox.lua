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

local skybox_ibl_trans = ecs.transform "skybox_ibl_transform"
function skybox_ibl_trans.process_entity(e)
	local rc = e._rendercache
	local ibl = e._ibl
	local sb_p = rc.properties.s_skybox.value
	ibl.source.handle = assert(sb_p.texture.handle)
end

local skybox_sys = ecs.system "skybox_system"
local sb_mb = world:sub {"component_register", "skybox"}
function skybox_sys.post_init()
	for _, _, eid in sb_mb:unpack() do
		iibl.filter_all(eid)
		world:pub{"ibl_updated", eid}
	end
end