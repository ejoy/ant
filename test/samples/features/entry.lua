local runtime = import_package "ant.imguibase".runtime
runtime.start {
	policy = {
		"ant.animation|animation",
		"ant.animation|state_chain",
		"ant.animation|ozzmesh",
		"ant.animation|ozz_skinning",
		"ant.serialize|serialize",
		"ant.bullet|collider.capsule",
		"ant.bullet|collider.box",
		"ant.sky|procedural_sky",
		"ant.render|name",
		"ant.render|mesh",
		"ant.render|shadow_cast",
		"ant.render|render",
		"ant.render|bounding_draw",
		"ant.render|directional_light",
		"ant.render|ambient_light",
		--editor
		"ant.objcontroller|select",
	},
	system = {
		"ant.test.features|init_loader",
	},
	pipeline = {
		"start",
		"timer",
		{"animation",{
			"sample_animation_pose",
			"skin_mesh",
		}},
		{"sky",{
			"update_sun",
			"update_sky",
		},
		},
		"widget",
		{"render", {
			"shadow_camera",
			"filter_primitive",
			"make_shadow",
			"debug_shadow",
			"cull",
			"render_commit",
			{"postprocess", {
				"bloom",
				"tonemapping",
				"combine_postprocess",
			}}
		}},
		"camera_control",
		"end_frame",
		"final",
	}
}
