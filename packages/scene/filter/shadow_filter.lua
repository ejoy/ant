local ecs = ...
local world = ecs.world

local filterutil = require "filter.util"

local shadow_primitive_filter_sys = ecs.system "shadow_primitive_filter_system"

shadow_primitive_filter_sys.depend "primitive_filter_system"

shadow_primitive_filter_sys.depend "generate_shadow_system"  -- remove debug for crash & flicker 
shadow_primitive_filter_sys.dependby "final_filter_system"

-- get shadow uniforms 
local function get_shadow_properties(uniform_properties, texture_properties)
	for _,l_eid in world:each("shadow_maker") do 
		local  sm_ent   = world[l_eid]
		local  uniforms = sm_ent.shadow_rt.uniforms 
		-- print(" get shadow uniforms in filter",#uniforms )
		-- uniforms.shadowMap
		uniform_properties["u_params1"] = { 
			name = "u_params1", type="v4", 
			value = {  
				uniforms.shadowMapBias,
				uniforms.shadowMapOffset, 0.5, 1 
			} 
		}

		uniform_properties["u_params2"] = {
			name = "u_params2",type="v4",
			value = {
				uniforms.depthValuePow,
				uniforms.showSmCoverage,
				uniforms.shadowMapTexelSize, 0 
			}
		}

		uniform_properties["u_smSamplingParams"] = { 
			name = "u_smSamplingParams", type  ="v4",
			value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } 
		}

		if sm_ent.shadow_rt.ready then 
			uniform_properties["u_shadowMapMtx0"] = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 }
			uniform_properties["u_shadowMapMtx1"] = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 }
			uniform_properties["u_shadowMapMtx2"] = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 }
			uniform_properties["u_shadowMapMtx3"] = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 }
			
			for stage=4, 7 do
				local name = "s_shadowMap" .. (stage - 4)
				texture_properties[name] = {
					name = name, type = "texture", stage = stage, handle = assert(uniforms[name]),
				}
			end
		end 
		
	end 
end 

function shadow_primitive_filter_sys:update()		
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local filter = e.primitive_filter
		local shadowproperties = filter.render_properties.shadow		
		get_shadow_properties(shadowproperties.uniforms, shadowproperties.textures)
	end
end
