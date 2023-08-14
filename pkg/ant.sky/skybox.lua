local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local setting   = import_package "ant.settings".setting
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local assetmgr	= import_package "ant.asset"

local geopkg 	= import_package "ant.geometry"
local geo 		= geopkg.geometry

local iibl      = ecs.require "ant.render|ibl.ibl"
local imesh		= ecs.require "ant.asset|mesh"
local imaterial	= ecs.require "ant.asset|material"

local skybox_sys = ecs.system "skybox_system"

function skybox_sys:component_init()
	for e in w:select "INIT skybox:in simplemesh:out owned_mesh_buffer?out skybox_changed?out" do
		local vb, ib = geo.box(1, true, false)
		local m = imesh.init_mesh{
			vb = {
				start = 0,
				num = 8,
				declname = "p3",
				memory = {"fff", vb},
				owned = true,
			},
			ib = {
				start = 0,
				num = #ib,
				memory = {"w", ib},
				owned = true,
			}
		}
		e.simplemesh = m
		e.owned_mesh_buffer = true
		e.skybox_changed = true
	end
end

local function res_tex_name(e)
    return imaterial.resource(e).properties.s_skybox.texture
end

function skybox_sys:entity_ready()
	for e in w:select "skybox_changed:update render_object filter_material:in skybox:in ibl:in" do
		local se_ibl = e.ibl
        local sb = e.skybox
		local tn = res_tex_name(e)
		local tex = assetmgr.resource(tn)
		local texid = tex.id
		if not assetmgr.invalid_texture(texid) then
			e.skybox_changed = false
			if not tex.texinfo.cubeMap then
				error(("Invalid cubemap texture file:%s, it need to convert to cubemap texture file(add 'equirect: true' in *.texture file to convert it into cubemap texture)"):format(tn))
			end
            iibl.filter_all{
                source 		= {value=texid, facesize=sb.facesize, tex_name = tn},
				--TODO: need remove, only use irradianceSH
                irradiance 	= se_ibl.irradiance,
                irradianceSH= se_ibl.irradianceSH,
                prefilter 	= se_ibl.prefilter,
                LUT			= se_ibl.LUT,
                intensity	= se_ibl.intensity,
            }
            world:pub{"ibl_updated", e}
        end
	end
end