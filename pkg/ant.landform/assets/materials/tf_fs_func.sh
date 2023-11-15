void CUSTOM_FS(Varyings varyings, out FSOutput fsoutput)
{
	float corner_alpha = texture2D(s_basecolor, varyings.texcoord0);
	fsoutput.color = vec4(u_basecolor_factor.xyz, corner_alpha * u_basecolor_factor.a);
}