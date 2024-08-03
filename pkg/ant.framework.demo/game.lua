local ecs = ...
local world = ecs.world

local window  = import_package "ant.window"
local loader = ecs.require "loader"
local monitor = require "monitor"

local main_system = ecs.system "main_system"
local update

function main_system.init_world()
	local game = loader.load(window.get_cmd())
	loader.key_callback(game.keyboard)
	loader.mouse_callback(game.mouse)
	update = game.update or error "Need game.update()"
end 

function main_system.data_changed()
	update()
	monitor.flush(world)	
end

