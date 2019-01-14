
	
	vec4 posOffset = vec4(a_position + a_normal.xyz * u_shadowMapOffset, 1.0);
	vec4 wpos = vec4(mul(u_model[0], posOffset).xyz, 1.0);    
	v_texcoord4 = mul(u_shadowMapMtx0, wpos);
	v_texcoord5 = mul(u_shadowMapMtx1, wpos);
	v_texcoord6 = mul(u_shadowMapMtx2, wpos);
	v_texcoord7 = mul(u_shadowMapMtx3, wpos);

 


