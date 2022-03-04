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

-- function skybox_sys:entity_ready()
-- 	for e in w:select "skybox_changed ibl:in render_object:in" do
-- 		local se_ibl = e.ibl
-- 		local ro = e.render_object
-- 		local s = ro.fx.setting
		
-- 		local tex = imaterial.get_property(e, "s_skybox").value
-- 		local texhandle = tex.texture.handle
-- 		-- if s.CUBEMAP_SKY == nil then
-- 		-- 	local icm = ecs.import.interface "ant.sky|icubemap_face"
-- 		-- 	texhandle = icm.convert_panorama2cubemap(tex.texture)
-- 		-- 	imaterial.set_property(e, "s_skybox", {stage=tex.stage, texture={handle=texhandle}})
-- 		-- end

-- 		iibl.filter_all{
-- 			source 		= {handle = texhandle, cubemap=true},
-- 			irradiance 	= se_ibl.irradiance,
-- 			prefilter 	= se_ibl.prefilter,
-- 			LUT			= se_ibl.LUT,
-- 			intensity	= se_ibl.intensity,
-- 		}
-- 		world:pub{"ibl_updated", e}
-- 	end
-- end

function skybox_sys:data_changed()
	for e in w:select "skybox_changed skybox:in render_object:in" do
		local sb = e.skybox
		local ro = e.render_object
		local p = assert(ro.properties.u_skybox_param.value)
		p.v = math3d.set_index(p, 1, sb.intensity)
	end
end
