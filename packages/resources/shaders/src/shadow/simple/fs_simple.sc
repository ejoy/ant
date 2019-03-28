$input v_normal, v_viewdir, v_positionInWS
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

//SAMPLER2D(s_basecolor, 0);
SAMPLER2D(s_shadowmap, 4);

uniform mat4 u_lightingViewProj;
uniform vec4 u_lightPos;

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 viewdir = normalize(v_viewdir);

	vec4 posInLS = mul(u_lightingViewProj, v_positionInWS);
	vec2 sm_uv = ((posInLS.xy / posInLS.w) + 1.0) * 0.5;	// [-1, 1] ==> [0, 1]

	float depeh = texture2D(s_shadowmap, sm_uv).r;

	float factor = min(1.0, step(depth, length(u_lightPos - v_positionInWS)) + 0.02);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness)* factor; 
	gl_FragColor.w = 1.0;
}