local ecs 	= ...
local world = ecs.world
local w 	= world.w

local iibl 		= ecs.import.interface "ant.render|iibl"
local imesh		= ecs.import.interface "ant.asset|imesh"

local bgfx		= require "bgfx"

local geopkg 	= import_package "ant.geometry"
local geo 		= geopkg.geometry

local renderpkg	= import_package "ant.render"
local sampler	= renderpkg.sampler
local viewidmgr	= renderpkg.viewidmgr

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

local cubemap_flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
}

function skybox_sys:entity_ready()
	for e in w:select "skybox_changed ibl:in render_object:in" do
		local se_ibl = e.ibl
		local ro = e.render_object
		local t = ro.properties.s_skybox
		local s = ro.fx.setting
		local tex = t.value.texture
		local texhandle = tex.handle

		if s.CUBEMAP_SKY == nil then
			local ti = tex.texinfo
			local size = math.min(ti.width, ti.height)
			texhandle = bgfx.create_texturecube(size, true, 1, "RGBA32F", cubemap_flags)

			local viewid = viewidmgr.generate "cvt_panorama"
			for i=1, 6 do
				local attachments = {
					{
						handle = texhandle,
						resolve = true,
						layer = i-1,
						mip = 0,
						numlayer = 6,
					}
				}
				
				local fbhandle = bgfx.create_frame_buffer(attachments)
				bgfx.set_view_frame_buffer(viewid, fbhandle)
				bgfx.submit(viewid)
				bgfx.destroy(fbhandle)
			end
			
		end

		iibl.filter_all{
			source 		= {handle = texhandle, cubemap=true},
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
