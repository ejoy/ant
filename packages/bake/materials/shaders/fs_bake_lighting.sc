$input v_normal
#include <bgfx_shader.sh>



void main()
{
    vec3 V = normalize(u_eyepos.xyz - v_posWS.xyz);
    vec3 N = v_normal;

    material_info mi = get_material_info(basecolor, uv);

    // LIGHTING
    vec3 color = vec3_splat(0.0);

    float NdotV = clamp_dot(N, V);

#ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    color  += mix(f_diffuse, f_diffuse * ao, u_occlusion_strength) + 
            = mix(f_specular, f_specular * ao, u_occlusion_strength);
#endif

#ifdef CLUSTER_SHADING
	uint cluster_idx = which_cluster(gl_FragCoord.xyz);

	light_grid g; load_light_grid(b_light_grids, cluster_idx, g);
	uint iend = g.offset + g.count;
	for (uint ii=g.offset; ii<iend; ++ii)
	{
		uint ilight = b_light_index_lists[ii];
#else //!CLUSTER_SHADING
	for (uint ilight=0; ilight<u_light_count[0]; ++ilight)
	{
#endif //CLUSTER_SHADING
        light_info l; load_light_info(b_lights, ilight, l);

        vec3 pt2l = l.dir;
        float attenuation = 1.0;
        if(!IS_DIRECTIONAL_LIGHT(l.type))
        {
            pt2l = l.pos - v_posWS.xyz;
            attenuation = get_range_attenuation(l.range, length(pt2l));
            if (IS_SPOT_LIGHT(l.type))
            {
                attenuation *= get_spot_attenuation(pt2l, l.dir, l.outter_cutoff, l.inner_cutoff);
            }
        }

        vec3 intensity = attenuation * l.intensity * l.color.rgb;

        vec3 L = normalize(pt2l);
        vec3 H = normalize(L+V);
        float NdotL = clamp_dot(N, L);
        float NdotH = clamp_dot(N, H);
        float LdotH = clamp_dot(L, H);
        float VdotH = clamp_dot(V, H);

        if (NdotL > 0.0 || NdotV > 0.0)
        {
            // Calculation of analytical light
            // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
            color += intensity * (
                    NdotL * BRDF_lambertian(mi.f0, mi.f90, mi.albedo, VdotH) +
                    NdotL * BRDF_specularGGX(mi.f0, mi.f90, mi.alpha_roughness, VdotH, NdotL, NdotV, NdotH));
        }
    }

    gl_FragColor =
        vec4(texture2D(s_lightmap, v_texcoord0).rgb, gl_FrontFacing ? 1.0 : 0.0);// + v_color0;
}