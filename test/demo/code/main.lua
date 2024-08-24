local camera = require "camera"

local game = {}

ant.import_prefab "/asset/light.prefab"
local cube = ant.primitive("cube", { x = 0, y = 0, r = 0, z = 0.5 } )

local show_debug = false
function game.keyboard(key)
	if key == "F8" then
		show_debug = not show_debug
		ant.show_debug(show_debug)
	elseif key == "Escape" then
		ant.gui_send("reset")
		cube.material.color = 0xffffff
--	elseif key == "F" then
--		cube.x = 100
--		cube.y = 100
--	elseif key == "V" then
--		cube.material.visible = false
--	elseif key == "N" then
--		cube.x = 0
--		cube.y = 0
--		cube.material.visible = true
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
local plane = ant.primitive("plane", {x = 0, y = 0, s = 10 })

--ant.prefab("/asset/x.glb/mesh.prefab", { x = 0, y = 0, material = { color = 0xff0000 }})
ant.sprite2d_base(256)
local avatar = ant.sprite2d("/asset/avatar.atlas", { x = 0, y = 0 })

ant.gui_open "/ui/hud.html"

ant.gui_listen("click", function (mode)
	if cube then
		if mode == "red" then
			print("Set red")
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
	ant.print(plane, "Plane")
	if cube then
		local r = cube.r + 0.2
		cube.r = r
		cube.x = 3 * math.cos(math.rad(r))
		cube.y = 3 * math.sin(math.rad(r))
		ant.print(cube, ("Cube (%g,%g)"):format(cube.x, cube.y))
	end
	avatar.r = ant.camera_ctrl.yaw
end

return game