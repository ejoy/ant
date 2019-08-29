vec3 a_position  : POSITION;
vec4 a_normal    : NORMAL;
vec4 a_tangent   : TANGENT;
vec2 a_texcoord0 : TEXCOORD0;

vec4 v_sm_coord0   : TEXCOORD4 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord1   : TEXCOORD5 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord2   : TEXCOORD6 = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_sm_coord3   : TEXCOORD7 = vec4(0.0, 0.0, 0.0, 0.0);
vec3 v_posVS       : TEXCOORD8 = vec3(0.0, 0.0, 0.0);
vec3 v_normalVS    : NORMAL    = vec3(0.0, 0.0, 1.0);
