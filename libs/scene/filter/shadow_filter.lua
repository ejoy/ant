local ecs = ...
local world = ecs.world



local shadow_primitive_filter_sys = ecs.system "shadow_primitive_filter_system"

shadow_primitive_filter_sys.depend "primitive_filter_system"

shadow_primitive_filter_sys.depend "generate_shadow_system"  -- remove debug for crash & flicker 
shadow_primitive_filter_sys.dependby "final_filter_system"

-- get shadow uniforms 
local function get_shadow_properties()
	local properties = {} 

	for _,l_eid in world:each("shadow_maker") do 
		local  sm_ent   = world[l_eid]
		local  uniforms = sm_ent.shadow_rt.uniforms 
		-- print(" get shadow uniforms in filter",#uniforms )
		-- uniforms.shadowMap
		properties["u_params1"] = { name = "u_params1",type="v4",value = {  uniforms.shadowMapBias,
																			uniforms.shadowMapOffset, 0.5, 1 } } 
		properties["u_params2"] = { name = "u_params2",type="v4",
									value = {   uniforms.depthValuePow,
												uniforms.showSmCoverage,
												uniforms.shadowMapTexelSize, 0 } }
		properties["u_smSamplingParams"] = { name = "u_smSamplingParams",
									type  ="v4",
									value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } }

		-- 
		if sm_ent.shadow_rt.ready then 
			-- shadow matrices 
			properties["u_shadowMapMtx0"] = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 }
			properties["u_shadowMapMtx1"] = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 }
			properties["u_shadowMapMtx2"] = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 }
			properties["u_shadowMapMtx3"] = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 }
			-- shadow textures  ?	

			-- set_texture 函数比较严格，当 texturehandle 非法时引发崩溃
			-- properties["s_normal"] = {name="normal", type="texture", stage=1, value = 0}
			properties["s_shadowMap0"] = {  name = "s_shadowMap0", type = "texture", stage = 4, value = uniforms.s_shadowMap0 }
			properties["s_shadowMap1"] = {  name = "s_shadowMap1", type = "texture", stage = 5, value = uniforms.s_shadowMap1 }
			properties["s_shadowMap2"] = {  name = "s_shadowMap2", type = "texture", stage = 6, value = uniforms.s_shadowMap2 }
			properties["s_shadowMap3"] = {  name = "s_shadowMap3", type = "texture", stage = 7, value = uniforms.s_shadowMap3 }
		end 
		
	end 

	return properties 
end 

--luacheck: ignore self
function shadow_primitive_filter_sys:update()	
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local filter = e.primitive_filter
		--if filter.enable_shadow then
			local shadow_properties  =  get_shadow_properties() 
			for _, r in ipairs(filter.result) do
				local properties = r.properties
				for k, v in pairs(shadow_properties) do
					properties[k] = v
				end
			end
		--end
	end
end