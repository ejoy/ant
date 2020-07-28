$input a_position
$output v_decalpos

uniform mat4 u_decal_viewproj;

void main()
{
	gl_Position = mul(u_decal_viewproj, vec4(a_position, 1.0));
	v_decalpos = gl_Position;
}