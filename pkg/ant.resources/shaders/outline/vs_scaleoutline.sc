#include "common/inputs.sh"

$input 	a_position INPUT_NORMAL INPUT_TANGENT INPUT_INDICES INPUT_WEIGHT

#include <bgfx_shader.sh>

#include "common/transform.sh"

uniform vec4 u_outlinescale;
#define u_outline_width u_outlinescale.x

float calc_pixel_width(float clipw)
{
#ifdef FIX_WIDTH
	return 0.01;
#else
	//u_viewRect.z = viewport width
	//u_proj[0][0] = 2.0*near / (right - left)
	// 1.0/(u_viewRect.z * u_proj[0][0]) ==> 1.0/vp_width*(2.0*near/(right-left))
	//	==> (right-left) / (vp_width*2.0*near) ==> ((right-left)/vp_width) * 1.0/(2.0*near)
	// A = (right-left)/vp_width), B = 1.0/(2.0*near)
	// ratio = A*B, where A mean: projection plane width with how many viewport width
	float pixelWidthRatio	= 1.0/(u_viewRect.z * u_proj[0][0]);
	return clipw * pixelWidthRatio;
#endif

}

vec2 calc_offset(vec2 dir, float aspect, float w)
{
	vec2 normal = normalize(vec2(-dir.y, dir.x));
	normal.x /= aspect;
	normal *= 0.5 * w;

    return normal;
}

void main()
{
#	if PACK_TANGENT_TO_QUAT
	mediump vec3 normal = quat_to_normal(a_tangent);
#	else //!PACK_TANGENT_TO_QUAT
	mediump vec3 normal = a_normal;
#	endif//PACK_TANGENT_TO_QUAT

#ifdef VIEW_SPACE
    mediump mat4 wm = get_world_matrix();
    mat4 modelView = mul(u_view, wm);
    vec4 pos = mul(modelView, vec4(a_position, 1.0));
    // normal should be transformed corredctly by transpose of inverse modelview matrix when anti-uniform scaled
    normal	= normalize(mul(modelView, mediump vec4(normal, 0.0)).xyz);
    float w = u_viewRect.z;
    float h = u_viewRect.w;
    normal.x *= h / w;
    pos = pos + vec4(normal, 0) * u_outline_width;
    gl_Position = mul(u_proj, pos); 
#else // SCREEN_SPACE    
    mediump mat4 wm = get_world_matrix();
    mat4 modelView = mul(u_view, wm);
    vec4 pos = mul(u_modelViewProj, vec4(a_position, 1.0));
    vec3 view_normal = mul(modelView, vec4(normal, 0.0)).xyz;
    vec3 ndc_normal = mul(pos.w, normalize(mul(u_proj, vec4(view_normal, 0.0)).xyz));
    float aspect = u_viewRect.w / u_viewRect.z;
    ndc_normal.x *= aspect;
    pos.xy += 0.01 * u_outline_width * ndc_normal.xy;
    gl_Position = pos; 
#endif //VIEW_SPACE
}