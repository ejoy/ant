vec3 a_position  : POSITION;
vec4 a_normal    : NORMAL;
vec4 a_tangent   : TANGENT;
vec3 a_bitangent : BITANGENT;

vec2 a_texcoord0 : TEXCOORD0;

// TEXCOORD2, TEXCOORD3 left with lightmap data

// any way to packed this varying?
vec4 v_sm_coord0   : TEXCOORD4 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord1   : TEXCOORD5 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord2   : TEXCOORD6 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord3   : TEXCOORD7 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_packed_info : TEXCOORD3 = vec4(0.0, 0.0, 0.0, 0.0);
