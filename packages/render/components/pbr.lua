-- local ecs = ...

-- local computil = require "components.util"
-- local fs = require "filesystem"
-- local assetmgr = import_package "ant.asset".mgr

-- -- ecs.component_alias("pbr_texture", "resource")
	
-- -- ecs.component "metal_rougness_style"
-- -- 	.basecolor_factor 	"real[4]"
-- -- 	["opt"].basecolor 	"pbr_texture"
-- -- 	.metal_factor 		"real[4]"
-- -- 	["opt"].metal		"pbr_texture"
-- -- 	.rougness_factor 	"real[4]"
-- -- 	["opt"].rougness 	"pbr_texture"

-- local pbr = ecs.component_alias("pbr", "resources") {depend = "material"}
-- 	-- .metal_rougness "metal_rougness_style"
-- 	-- ["opt"].normal_scale "real"
-- 	-- ["opt"].normal 		"pbr_texture"	
-- 	-- ["opt"].emissive_factor "real[4]"
-- 	-- ["opt"].emissive 	"pbr_texture"
-- 	-- ["opt"].occlusion_strength "real"
-- 	-- ["opt"].occlusion 	"pbr_texture"

-- local function deep_copy(t)
-- 	if type(t) == "table" then
-- 		local tmp = {}
-- 		for k, v in pairs(t) do
-- 			tmp[k] = deep_copy(v)
-- 		end
-- 		return tmp
-- 	end
-- 	return t
-- end

-- function pbr:postinit(e)
-- 	local m = e.material
-- 	assert(#m.content == 0)
-- 	local pbr = m.pbr

-- 	computil.add_material(m, fs.path(pbr.material_path))
-- 	local mc = assert(m.content[1])
	
-- 	local properties = mc.properties
	
-- 	for k, v in pairs(pbr) do
-- 		local pro = properties[k]
-- 		if k:match("s_.+") then
-- 			pro.handle = assetmgr.load(v)
-- 		else
-- 			pro.value = deep_copy(v)
-- 		end
-- 	end
-- end