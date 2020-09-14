uniform vec4            u_line_info;
#define u_line_width    u_line_info.x
#define u_visible       u_line_info.y
#define u_alphatest     u_line_info.z

uniform vec4            u_color;

uniform vec4 u_tex_param;
#define u_repeat        u_tex_param.xy
#define u_use_tex       u_tex_param.z
#define u_use_alphatex  u_tex_param.w

uniform vec4 u_dash_info;
#define u_dash_array     u_dash_info.x
#define u_dash_offset    u_dash_info.y
#define u_dash_ratio     u_dash_info.z
#define u_use_dash       u_dash_info.w