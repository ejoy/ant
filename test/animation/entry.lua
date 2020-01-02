local runtime = import_package "ant.imguibase".runtime
runtime.start {
	policy = {
		"ant.animation|animation",
		"ant.animation|state_chain",
		"ant.animation|ozzmesh",
		"ant.animation|ozz_skinning",
		"ant.serialize|serialize",
		"ant.bullet|collider.capsule",
		"ant.render|render",
		"ant.render|name",
		"ant.render|directional_light",
		"ant.render|ambient_light",
	},
	system = {
		"ant.test.animation|init_loader",
	},
	pipeline = {
		"start",
		"timer",
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
		"end_frame",
		"final",
	}
}
