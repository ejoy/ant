-- luacheck: globals log bullet
local log = log and log(...) or print
local ecs = require "ecs"

--local elog = require "editor.log"
--local db = require "debugger"

-- --windows dir
-- asset.insert_searchdir(1, "D:/Engine/ant/assets")
-- --mac dir
-- asset.insert_searchdir(2, "/Users/ejoy/Desktop/Engine/ant/assets")


local util = {}
util.__index = util

local world = nil

local bullet_module = require "bullet"
bullet = bullet_module.new()

local bullet_world = require "bullet.bulletworld"


function util.start_new_world(input_queue, fbw, fbh, modules, module_searchdirs)
	if input_queue == nil then
		log("input queue is not privided, no input event will be received!")
	end

	world = ecs.new_world {
		modules = modules,
		module_path = module_searchdirs or package.path,
		update_order = {"timesystem", "message_system"},
		update_bydepend = true,
		args = { 
			mq = input_queue, 
			fb_size={w=fbw, h=fbh},
			physic_world = bullet:new_world(),
			Physics = bullet_world.new(),
		},
    }
    return world
end

return util
