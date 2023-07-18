#include "common/default_inputs_define.sh"

$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3

/*
 * Copyright 2011-2018 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include <bgfx_shader.sh>
#include "common/curve_world.sh"
#include "common/transform.sh"
#include "common/default_inputs_structure.sh"

void main()
{
	VSInput vs_input = (VSInput)0;
	#include "common/default_vs_inputs_getter.sh"

	mat4 wm = get_world_matrix(vs_input);
    transform_pos(wm, a_position, gl_Position);
}
