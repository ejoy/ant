local ecs 	= ...
local world = ecs.world
local w 	= world.w

local imesh		= ecs.import.interface "ant.asset|imesh"
local geopkg 	= import_package "ant.geometry"
local geo 		= geopkg.geometry

local math3d	= require "math3d"

local skybox_sys = ecs.system "skybox_system"

function skybox_sys:component_init()
	w:clear "skybox_changed"
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

function skybox_sys:entity_init()
	for e in w:select "skybox_changed skybox:in render_object:in" do
		local sb = e.skybox
		local ro = e.render_object
		local p = assert(ro.properties.u_skybox_param.value)
		p.v = math3d.set_index(p, 1, sb.intensity)
	end
end
