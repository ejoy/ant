local runtime = import_package "ant.imguibase".runtime
runtime.start {
	policy = {
		"ant.render|mesh",
		"ant.serialize|serialize",
		"ant.bullet|collider.capsule",
		"ant.render|render",
		"ant.render|name",
		"ant.render|shadow_cast",
		"ant.render|directional_light",
		"ant.render|ambient_light",
	},
	system = {
		"ant.modelviewer|model_review_system",
		"ant.modelviewer|init_gui",
		"ant.camera_controller|camera_controller_2"
	},
	pipeline = {
		"start",
		"timer",
		"data_changed",
		{"animation",{
			"animation_state",
			"sample_animation_pose",
			"skin_mesh",
		}},
		{"sky",{
			"update_sun",
			"update_sky",
		}},
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
		{"ui", {
			"ui_start",
			"ui",
			"ui_end",
		}},
		"end_frame",
		"final",
	}
}
