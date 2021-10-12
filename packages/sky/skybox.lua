local ecs = ...
local world = ecs.world
local w = world.w

local iibl = ecs.import.interface "ant.render.ibl|iibl"
local imesh= ecs.import.interface "ant.asset|imesh"

local geopkg = import_package "ant.geometry"
local geo = geopkg.geometry

local skybox_sys = ecs.system "skybox_system"

function skybox_sys:component_init()
	for e in w:select "INIT skybox simplemesh:out skybox_changed?out" do
		local vb, ib = geo.box(1, true, false)
		e.simplemesh = imesh.init_mesh({
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
		}, true)
		e.skybox_changed = true
	end
end

function skybox_sys:entity_ready()
	for e in w:select "skybox_changed ibl:in render_object:in" do
		local se_ibl = e.ibl
		local t = e.render_object.properties.s_skybox
		local h = t.value.texture.handle
		iibl.filter_all{
			source = {handle = h},
			irradiance = se_ibl.irradiance,
			prefilter = se_ibl.prefilter,
			LUT= se_ibl.LUT,
		}
		world:pub{"ibl_updated", e}
	end
	w:clear "skybox_changed"
end
