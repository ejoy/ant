local ecs 	= ...
local world = ecs.world
local w 	= world.w

local iibl 		= ecs.import.interface "ant.render|iibl"
local imesh		= ecs.import.interface "ant.asset|imesh"

local geopkg 	= import_package "ant.geometry"
local geo 		= geopkg.geometry

local math3d	= require "math3d"

local skybox_sys = ecs.system "skybox_system"

function skybox_sys:component_init()
	for e in w:select "INIT skybox:in simplemesh:out skybox_changed?out" do
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
		local ro = e.render_object
		local t = ro.properties.s_skybox
		local s = ro.fx.setting
		local h = t.value.texture.handle
		iibl.filter_all{
			source 		= {handle = h, cubemap=true},
			irradiance 	= se_ibl.irradiance,
			prefilter 	= se_ibl.prefilter,
			LUT			= se_ibl.LUT,
			intensity	= se_ibl.intensity,
		}
		world:pub{"ibl_updated", e}
	end
	w:clear "skybox_changed"
end

function skybox_sys:data_changed()
	for e in w:select "skybox:in render_object:in" do
		local sb = e.skybox
		local ro = e.render_object
		local p = assert(ro.properties.u_skybox_param.value)
		p.v = math3d.set_index(p, 1, sb.intensity)
	end
end
