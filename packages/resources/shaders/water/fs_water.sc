$input v_texcoord0 v_posWS v_normal v_tangent v_bitangent

#include <bgfx_shader.sh>

#include "water.sh"
#include "common/camera.sh"
#include "common/lighting.sh"
#include "common/common.sh"
#include "common/transform.sh"

// Surface settings:
SAMPLER2D(s_dudv,           0); // UV motion sampler for shifting the normalmap
SAMPLER2D(s_normalmapA,     1); // Normalmap sampler A
SAMPLER2D(s_normalmapB,     2); // Normalmap sampler B
SAMPLER2D(s_foam,           3); // Foam sampler
SAMPLER2DARRAY(s_caustic,   4); // Caustic sampler, (Texture array with 16 Textures for the animation)

SAMPLER2D(s_scene,          5);
SAMPLER2D(s_scene_depth,    6);


uniform vec4 u_water_surface = vec4(0.5, 0.075, 2.0, -0.75);
#define u_foam_level    u_water_surface.x   //Foam level -> distance from the object (0.0 - 0.5)
#define u_refraction    u_water_surface.y   //Refraction of the water
#define u_beers_law     u_water_surface.z   //Beers law value, regulates the blending size to the deep water level
#define u_depth_offset  u_water_surface.w   //Offset for the blending

uniform vec4 u_color_deep;			// Color for deep places in the water, medium to dark blue
uniform vec4 u_color_shallow;		// Color for lower places in the water, bright blue - green

uniform mat4 u_caustic_projector;	// Projector matrix, mostly the matric of the sun / directlight

uniform vec4 u_directional_light_dir;
#define u_directional_light_intensity u_directional_light_dir.w
uniform vec4 u_direciontal_light_color;

void main()
{
	// Calculation of the UV with the UV motion sampler
	vec2 uv_offset 			= u_uv_direction * u_current_time * 0.001;
	vec2 uv_sampler_uv 		= v_texcoord0.xy * u_uv_scale + uv_offset;
	vec2 uv_sampler_uv_offset = u_uv_shifting_strength * texture2D(s_dudv, uv_sampler_uv).rg * 2.0 - 1.0;
	vec2 uv 				= v_texcoord0.xy + uv_sampler_uv_offset;
	
	vec3 N = mix(	fetch_bc5_normal(s_normalmapA, uv - uv_offset*2.0).xyz,   // 75 % s_normalmapA
					fetch_bc5_normal(s_normalmapB, uv + uv_offset).xyz,       // 25 % s_normalmapB
					0.25);
    mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);
	N = normalize(instMul(N, tbn));

#ifdef VIEW_WATER_NORMAL
	gl_FragColor = vec4(N*7, 1.0);
	return;
#endif //VIEW_WATER_NORMAL

    float vertex_height = v_posWS.w;
	vec2 screen_uv = gl_FragCoord.xy * u_viewTexel.xy;
	vec2 ref_uv = screen_uv + (N.xy * u_refraction) / vertex_height;

	float depth_raw = texture2D(s_scene_depth, ref_uv).r * 2.0 - 1.0;
	float depth = linear_depth(depth_raw);

    float vertexZ_WS = v_posWS.z;

	float depth_blend = exp((depth+vertexZ_WS + u_depth_offset) * -u_beers_law);
	depth_blend = clamp(1.0-depth_blend, 0.0, 1.0);
	float depth_blend_pow = clamp(pow(depth_blend, 2.5), 0.0, 1.0);

	vec3 dye_color= mix(u_color_shallow.rgb, u_color_deep.rgb, depth_blend_pow);
#ifdef VIEW_WATER_COLOR
	gl_FragColor = vec4(dye_color * 7, 1.0);
	return ;
#endif //VIEW_WATER_COLOR

#ifdef WITHOUT_SCENE_COLOR
	vec3 color = dye_color;
#else //!WITHOUT_SCENE_COLOR
	// TODO:s_scene texture should have mipmap, it something like ibl 's_prefilter' map
    //      need to calculate pre frame?? or just directly use s_prefilter map??
	vec3 screen_color 	= texture2D(s_scene, ref_uv).rgb;//texture2DLod(s_scene, ref_uv, depth_blend_pow * 2.5).rgb;

#	ifdef VIEW_WATER_SCENE_COLOR
	gl_FragColor = vec4(screen_color, 1.0);
	return ;
#	endif //VIEW_WATER_SCENE_COLOR

	vec3 color = mix(screen_color*dye_color, dye_color*0.25, depth_blend_pow*0.5);
#endif //WITHOUT_SCENE_COLOR
	// Caustic screen projection
#ifdef WATER_CAUSTIC
	vec4 caustic_screenPos = vec4(ref_uv*2.0-1.0, depth_raw, 1.0);
    mat4 inv_mvp = mul(transpose(u_model[0]), u_invViewProj);
	vec4 caustic_localPos = mul(inv_mvp, caustic_screenPos);
	caustic_localPos = caustic_localPos/caustic_localPos.w;

	vec2 caustic_uv 	= caustic_localPos.xz / vec2_splat(1024.0) + 0.5;
	vec4 caustic_color	= texture2DArray(s_caustic, vec3(caustic_uv*300.0, mod(u_current_time*14.0, 16.0)));

	color *= 1.0 + pow(caustic_color.r, 1.50) * (1.0-depth_blend) * 6.0;
#endif //WATER_CAUSTIC
	
#ifdef WATER_FOAM
    if(depth + vertexZ_WS < u_foam_level && depth > vertex_height-0.1)
    {
        float foam_noise = clamp(pow(texture2D(s_foam, (uv*4.0) - uv_offset).r, 10.0)*40.0, 0.0, 0.2);
        float foam_mix = clamp(pow((1.0-(depth + vertexZ_WS) + foam_noise), 8.0) * foam_noise * 0.4, 0.0, 1.0);
        color = mix(color, vec3_splat(1.0), foam_mix);
    }
#endif //WATER_FOAM

#ifdef VIEW_WATER_WITHOUT_LIGHTING
	gl_FragColor = vec4(color, 1.0);
	return ;
#endif //VIEW_WATER_WITHOUT_LIGHTING

    //This is a simple pbr lighting here, only consider directional lighting pass from CPU side
    material_info mi;
    mi.roughness = 0.2;
    mi.alpha_roughness = mi.roughness * mi.roughness;
    mi.metallic = 0.1;
    
    calc_reflectance(vec3_splat(MIN_ROUGHNESS), color, mi);
    light_info l;
	l.pos = vec3(0.0, 0.0, 0.0);
	l.enable = 1.0;
	l.range = l.inner_cutoff = l.outter_cutoff = 0.0;
    l.type      = 0; //0 for directional
    l.color     = u_direciontal_light_color;
    l.dir       = u_directional_light_dir.xyz;
    l.intensity = u_directional_light_intensity;


    vec3 V = u_eyepos.xyz - v_posWS.xyz;
    gl_FragColor = vec4(get_light_radiance(l, v_posWS.xyz, N, V, dot(N, V), mi), 1.0);
	// Set all values:
	// ALBEDO = color;
	// METALLIC = 0.1;
	// ROUGHNESS = 0.2;
	// SPECULAR = 0.2 + depth_blend_pow * 0.4;
	// NORMALMAP = normalmap;
	// NORMALMAP_DEPTH = 1.25;
}
