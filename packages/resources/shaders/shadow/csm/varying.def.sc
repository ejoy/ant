vec3 a_position    : POSITION;
vec4 a_normal      : NORMAL;
vec4 a_tangent     : TANGENT;
vec3 a_bitangent   : BITANGENT;
vec2 a_texcoord0   : TEXCOORD0;

vec2 v_texcoord0   : TEXCOORD0;
vec3 v_lightdirTS  : TEXCOORD1;
vec3 v_viewdirTS   : TEXCOORD2;
vec4 v_packed_info : TEXCOORD3;

vec4 v_shadowcoord : TEXCOORD4;
vec4 v_positionWS  : TEXCOORD4;