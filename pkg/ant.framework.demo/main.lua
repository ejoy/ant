local framework = {}

function framework.start(args)
	import_package "ant.window".start {
		window_size = args.window_size,
		vsync = args.vsync,
		profile = args.profile == true,
		log = args.log,
		cmd = args,
		feature = {
			"ant.framework.demo",
			"ant.rmlui",
			"ant.render",
--			"ant.animation",	-- todo:
			"ant.shadow_bounding|scene_bounding",
			"ant.pipeline",
			"ant.sky|sky",
			"ant.debug_text",
		},
	}
end

return framework