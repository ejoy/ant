/*
 * Copyright 2011-2018 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

 #include <bgfx_shader.sh>
uniform vec4 u_id;
void main()
{
	gl_FragColor = u_id; // This is dumb, should use u8 texture
}
