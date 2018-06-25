$input v_color0, v_normal, v_tex0, v_pos
#include "common.sh"

SAMPLER2D(s_basecolor, 0);
//SAMPLER2D(s_normal, 1);

uniform vec4 directional_lightdir[1];
// uniform vec4 directional_color[1];
// uniform vec4 directional_intensity[1];

uniform vec3 eyepos;

vec2 blinn(vec3 _lightDir, vec3 _normal, vec3 _viewDir)
{
	float ndotl = dot(_normal, _lightDir);
	vec3 reflected = _lightDir - 2.0*ndotl*_normal; // reflect(_lightDir, _normal);
	float rdotv = dot(reflected, _viewDir);
	return vec2(ndotl, rdotv);
}

float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(_bias + (1.0 - _bias) * pow(facing, _pow), 0.0);
}

vec4 lit(float _ndotl, float _rdotv, float _m)
{
	float diff = max(0.0, _ndotl);
	float spec = step(0.0, _ndotl) * max(0.0, _rdotv * _m);
	return vec4(1.0, diff, spec, 1.0);
}

void main()
{
	vec4 color = toLinear(texture2D(s_basecolor, v_tex0));

	vec3 normal = normalize(v_normal);

	vec3 viewdir = normalize(v_pos - eyepos);
	vec3 lightdir = vec3(1, 1, -1);
	vec2 bn = blinn(directional_lightdir[0], normal, viewdir);

	float ndotl = bn.x;
	float rdotv = bn.y;

	float fres = fresnel(ndotl, 0.2, 5);
	vec4 lc = lit(ndotl, rdotv, 1);
	float diffuse = lc.y;
	float specular = pow(lc.z, 128.0);

	gl_FragColor.xyz = color.xyz*lc.y + fres*specular;
	gl_FragColor.w = 1.0;
}