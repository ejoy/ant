vec3 a_position : POSITION;
vec3 a_normal	: NORMAL;
vec3 a_tangent	: TANGENT;
vec3 a_bitangent: BITANGENT;
vec2 a_texcoord0: TEXCOORD0;
vec4 a_color0	: COLOR0;
vec4 a_weight	: WEIGHT;
ivec4 a_indices	: INDICES;

vec4 v_color0	: COLOR0;

vec2 v_texcoord0: TEXCOORD0;
vec3 v_lightdir : TEXCOORD1;
vec3 v_viewdir	: TEXCOORD2;

vec3 v_normal	: TEXCOORD3;
