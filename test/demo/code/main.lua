local camera = require "camera"

local game = {}

ant.import_prefab "/asset/light.prefab"
local cube = ant.primitive("cube", { x = 0, y = 0, r = 0, z = 0.5 } )

local show_profile = false
function game.keyboard(key)
	if key == "F8" then
		show_profile = not show_profile
		ant.show_profile(show_profile)
	elseif key == "Escape" then
		ant.gui_send("reset")
		cube.material.color = 0xffffff
	end
end

function game.mouse(btn, state, x, y)
	camera.mouse_ctrl(btn, state, x, y)
	if btn == "LEFT" and state == "UP" then
		print("Click", ant.camera_ctrl.screen_to_world(x, y))
	end
end

print_r(ant.setting)
ant.maxfps(ant.setting.fps)
ant.primitive("plane", {x = 0, y = 0, s = 10 })

--ant.prefab("/asset/x.glb", { x = 0, y = 0, material = { color = 0xff0000 }})

ant.gui_open "/ui/hud.html"

ant.gui_listen("click", function (mode)
	if cube then
		if mode == "red" then
			cube.material.color = 0xff0000
		elseif mode == "green" then
			cube.material.color = 0x00ff00
		elseif mode == "blue" then
			cube.material.color = 0x0000ff
		end
	end
end)

ant.gui_listen("remove", function ()
	ant.remove(cube)
	cube = nil
end)

function game.update()
	camera.key_ctrl()
	if cube then
		cube.r = cube.r + 1
	end
end

return game