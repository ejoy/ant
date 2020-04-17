return {
	-- package name
	name = "ant.test.simple",
	world = {
		policy = {
--			"ant.scene|hierarchy",
--			"ant.render|mesh",
--			"ant.render|render",
--			"ant.render|light.directional",
--			"ant.render|light.ambient",
		},
		system = {
			-- see test/simple/game.lua
			"ant.test.simple|game",
		}
	}
}
