vec3 a_position  : POSITION;
vec4 a_normal    : NORMAL;

vec2 a_texcoord0 : TEXCOORD0;
vec2 a_texcoord1 : TEXCOORD1;

vec2 v_texcoord0 : TEXCOORD0  = vec2(0.0, 0.0);
vec2 v_texcoord1 : TEXCOORD1  = vec2(0.0, 0.0);
vec4 v_positionWS: TEXCOORD2  = vec4(0.0, 0.0, 0.0, 0.0);
vec4 v_normal    : NORMAL     = vec4(0.0, 0.0, 1.0, 0.0);
