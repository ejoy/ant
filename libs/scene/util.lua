local ecs = require "ecs"
local task = require "editor.task"
local asset = require "asset"

--local elog = require "editor.log"
--local db = require "debugger"

asset.insert_searchdir(1, "D:/Engine/ant/assets")

local util = {}
util.__index = util

local world = nil

function util.start_new_world(input_queue, fbw, fbh, module_descripiton_file)
	local modules = asset.load(module_descripiton_file)
	world = ecs.new_world {
		modules = modules,
		update_bydepend = true,
		args = { mq = input_queue, fb_size={w=fbw, h=fbh} },
    }
    
	task.loop(world.update,	
	function (co, status)
	--	local trace = db.traceback(co)
	--	elog.print(status)
	--	elog.print("\n")
	--	elog.print(trace)
	--	elog.active_error()
    end)
    
    return world
end

return util